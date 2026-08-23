import 'dart:async';
import 'dart:convert';
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_android/webview_flutter_android.dart';

import 'cloudflare.dart';
import 'turnstile_solver.dart';

/// 常驻 WebView 桥接器。
///
/// 根因：Cloudflare 的 `cf_clearance` 与客户端 TLS 指纹绑定。Dart 的 HTTP 客户端
/// （BoringSSL，指纹不同）用该 cookie 重放请求时，往往被按请求重新挑战，导致
/// “在 WebView 里验证成功、关掉后 Dart 请求仍拿不到数据”。
///
/// 本桥接器持有【一个】贯穿 App 生命周期的 WebView：
/// 1. 首次遇到挑战时，它作为验证页加载目标 URL（managed 挑战对指纹一致的
///    客户端免交互自动通过）；
/// 2. 验证通过后它保持存活（隐藏但挂载），后续 API 请求通过它取数——优先
///    内部 `fetch`（快）；被站点 WAF 挑战时降级为「导航取数」（直接导航到
///    目标 URL 后读取渲染 DOM，导航请求不会被该站挑战）；
/// 3. “导入 cf_clearance”旁路把 cookie 注入该 WebView，直接进入就绪态。
///
/// 关键点：始终使用【同一个】WebViewController，避免重新挂载导致会话/cookie 丢失。
/// （实际上 cf_clearance 存于平台级共享 cookie 仓库，即使 WebView 实例重建也不会丢，
///  但共享同一实例能确保 fetch 走一致的 TLS 指纹。）
class CloudflareBridge extends ChangeNotifier {
  CloudflareBridge._();
  static final CloudflareBridge instance = CloudflareBridge._();

  WebViewController? _controller;
  bool _verifying = false;
  bool _ready = false;
  Uri? _pendingUri;

  final Map<String, String> _cookies = {};
  Completer<CloudflareSolveResult?>? _solveCompleter;
  final Map<String, Completer<String?>> _fetchCompleters = {};
  Timer? _pollTimer;
  Timer? _solveTimeoutTimer;
  bool _pollBusy = false;

  /// fetch 连续被 WAF 挑战的次数；达到 3 后本会话禁用 fetch 快路径，
  /// 直接走导航取数（避免每次请求都白付一次挑战往返）。
  int _fetchChallengeStreak = 0;
  bool _fetchDisabled = false;

  /// 轮询计数（用于周期性输出诊断日志）。
  int _pollCount = 0;

  /// 用户手动取消标记：终止 solve 的自动重试循环
  /// （超时兜底触发的取消不算，仍允许下一轮重试）。
  bool _userCancelled = false;

  /// 交互式 Turnstile 自动解得的 token 是否已回填（每轮验证只尝试一次，
  /// 避免重复调用打码平台花钱）。
  bool _turnstileEscalated = false;

  /// 打码平台解 Turnstile 进行中（重入保护）。
  bool _escalating = false;

  /// 进行中的 solve（含重试循环整体），并发请求共享其结果。
  Future<CloudflareSolveResult?>? _activeSolve;

  bool get verifying => _verifying;
  bool get ready => _ready;

  /// 最近一次桥接取数结果（供 UI 状态展示）：成功字节数或失败原因。
  int? lastFetchLen;
  String? lastError;

  /// 持久化的 WebViewController（懒创建，全 App 唯一）。
  WebViewController get controller {
    _controller ??= _build();
    return _controller!;
  }

  WebViewController _build() {
    // 关键：不设置自定义 UA，使用 WebView 真实默认 UA（移动 Chrome）。
    // 此前伪装桌面 Chrome/120 UA，与 WebView 实际的 TLS/Client-Hints 指纹不符，
    // Cloudflare 会把 managed 挑战升级为交互式 Turnstile——而 Turnstile 小组件
    // 在 IDN 域名下会因 postMessage origin 不匹配崩溃（验证永远过不去的根因）。
    // 真实浏览器实测：该站的 managed 挑战对指纹一致的客户端免交互自动通过。
    final c = WebViewController(
      // Cloudflare Turnstile 完成无感验证需要媒体设备/WebRTC 权限，
      // 否则报 "No available adapters" 导致挑战永远无法通过。全部授权。
      onPermissionRequest: (request) => request.grant(),
    )
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      // UA 伪装为真实 Chrome（去掉 Android WebView 的 "; wv)" 标记）：
      // Turnstile 对带 wv 标记的 UA 直接判为嵌入式 WebView，给最难挑战路径
      // （真机实测 3×90s 三轮 managed 挑战全败）。去掉 wv 后与真实 Chrome
      // 一致，配合第三方 Cookie 开启，通过率与移动浏览器相同。
      ..setUserAgent(
          'Mozilla/5.0 (Linux; Android 13) AppleWebKit/537.36 (KHTML, like '
          'Gecko) Chrome/124.0.0.0 Mobile Safari/537.36')
      // WebView 控制台日志转发到 [CF] 日志流：Turnstile 的异常
      // （如 SecurityError）会以 console error 形式出现，用于诊断验证失败原因。
      ..setOnConsoleMessage((m) => cfLog('[WebView] ${m.level}: ${m.message}'))
      ..addJavaScriptChannel(
        'cfFetch',
        onMessageReceived: (m) => _onFetchMessage(m.message),
      );
    _hardenAndroid(c);
    return c;
  }

  /// Android 专属强化：把 WebView 行为对齐真实 Chrome。
  ///
  /// Turnstile 小组件跑在 challenges.cloudflare.com 的【第三方 iframe】里。
  /// Android WebView 默认禁用第三方 Cookie（webview_flutter_android 源码明确
  /// `Defaults to false`），导致 Turnstile 的 cookie/storage 通信适配器全部失效，
  /// 只剩 postMessage——而 postMessage 在 IDN 域名下又因 origin 不匹配抛
  /// SecurityError → "No available adapters"，挑战永远无法完成。
  /// 桌面 Chrome 默认允许第三方 Cookie，这正是「桌面能自动过、WebView 过不去」
  /// 的关键环境差异。开启后 Turnstile 恢复多条备用适配器，managed 挑战可免交互通过。
  void _hardenAndroid(WebViewController c) {
    if (kIsWeb || !Platform.isAndroid) return;
    try {
      final platform = c.platform;
      if (platform is AndroidWebViewController) {
        AndroidWebViewCookieManager(
          const PlatformWebViewCookieManagerCreationParams(),
        ).setAcceptThirdPartyCookies(platform, true);
        cfLog('已启用第三方 Cookie（Turnstile 第三方 iframe 通信必需）');
      }
    } catch (e) {
      cfLog('Android WebView 强化失败: $e');
    }
  }

  void _onFetchMessage(String raw) {
    try {
      final map = json.decode(raw) as Map<String, dynamic>;
      final id = map['id'] as String?;
      final html = map['html'] as String?;
      final completer = id != null ? _fetchCompleters.remove(id) : null;
      completer?.complete(html);
    } catch (_) {
      // 非 JSON：忽略
    }
  }

  /// 唤起验证（复用持久 WebView，避免重新挂载导致会话/cookie 丢失）。
  ///
  /// - 已就绪（_ready）：直接返回已保存 cookie，无需再次弹验证；
  /// - 本地已保存 cf_clearance（上次验证/导入）：先【静默复活】——在隐藏
  ///   WebView 里注入 cookie 并取数验证，成功则不弹验证页（跨重启持久化）；
  /// - 正在验证中：等待同一次验证结果（并发请求共享）；
  /// - 否则：展示验证页、加载目标 URL、轮询直到挑战消失，90s 兜底超时。
  Future<CloudflareSolveResult?> solve(Uri uri) async {
    if (_ready) {
      await _readCookies(uri);
      return CloudflareSolveResult(
        cookies: Map<String, String>.from(_cookies),
        html: null,
      );
    }
    // 正在验证中：等待同一次验证结果（并发请求共享）。
    // 由 _activeSolve 统一覆盖（含重试循环间隙）。
    // （旧逻辑 _verifying && _solveCompleter 在两轮间隙会返回已完成的
    //  completer —— 结果 null，并发请求会误判验证失败。）

    // 静默复活：优先尝试用本地已保存的 cf_clearance 直接就绪，
    // 避免每次启动都弹验证页（需求：clearance 跨 App 重启仍有效）。
    final saved = CloudflareCookieJar.instance.cookiesFor(uri.host);
    if (saved.containsKey('cf_clearance')) {
      await _applyUserAgent(uri.host);
      final revived = await _tryRevive(uri, saved);
      if (revived != null) return revived;
      // 复活失败（cookie 过期）：恢复默认 UA 再走手动验证。
      // 导入旁路残留的桌面 UA 与 WebView 真实指纹不符，会让挑战
      // 升级为交互式 Turnstile（IDN 域名下必崩）。
      await controller.setUserAgent(null);
      cfLog('本地 cf_clearance 失效，已恢复默认 UA 走自动验证');
    }

    _pendingUri = uri;
    // 并发保护：重试循环的两轮间隙 _verifying=false，其他请求此时调
    // solve 会开第二个循环、状态互相干扰——共享同一个进行中的 solve。
    final active = _activeSolve;
    if (active != null) return active;
    final completer = Completer<CloudflareSolveResult?>();
    _activeSolve = completer.future;
    try {
      final res = await _solveWithRetry(uri, completer);
      if (!completer.isCompleted) completer.complete(res);
      return res;
    } finally {
      _activeSolve = null;
    }
  }

  /// 重试循环主体（由 [solve] 串行化调用）。
  /// IDN 域名下 Turnstile 行为不稳定：实测有的轮次 45s 自动通过，
  /// 有的轮次 widget hung 后 postMessage 死循环永不通过。单轮 90s
  /// 兜底失败后自动重试（重新 loadRequest 重置挑战状态），最多 3 轮；
  /// 每轮开始先收割上轮残留——取消/超时后挑战页常在后台继续执行完成。
  Future<CloudflareSolveResult?> _solveWithRetry(
      Uri uri, Completer<CloudflareSolveResult?> completer) async {
    _userCancelled = false;
    _verifying = true;
    notifyListeners();
    for (var round = 1; round <= 3; round++) {
      if (_userCancelled) {
        cfLog('用户已取消，终止验证重试');
        break;
      }
      final res = await _solveOnce(uri, round);
      if (res != null) {
        _verifying = false;
        notifyListeners();
        return res;
      }
      if (round < 3) {
        cfLog('第 $round 轮验证未通过，2s 后重试');
        await Future.delayed(const Duration(seconds: 2));
      }
    }
    _verifying = false;
    notifyListeners();
    cfLog('3 轮验证均未通过');
    return null;
  }

  /// 单轮验证：可选收割上轮残留 → loadRequest → 轮询 → 90s 兜底。
  Future<CloudflareSolveResult?> _solveOnce(Uri uri, int round) async {
    // 每轮重置：本轮重新尝试打码平台解 Turnstile（上一轮若失败/未配置，
    // 下一轮仍给一次机会；若已成功回填则本轮不会再到这里）。
    _turnstileEscalated = false;
    // 收割上轮残留：上轮取消后挑战页可能已在后台完成（真机实测：
    // 40s 兜底取消 5s 后站点 JS/字体/视频出现在 WebView 里）。
    if (round > 1) {
      try {
        final res = await controller
            .runJavaScriptReturningResult(kCloudflareChallengeCheckJs)
            .timeout(const Duration(seconds: 3));
        if (!_asBool(res)) {
          final html = await _readDomHtml();
          if (html != null &&
              html.length >= 200 &&
              !CloudflareDetector.isHtmlChallengeString(html)) {
            await _readCookies(uri);
            _ready = true;
            _fetchChallengeStreak = 0;
            _fetchDisabled = false;
            CloudflareCookieJar.instance.store(uri, _cookies);
            final wvUa = await _readWebViewUserAgent();
            if (wvUa != null && wvUa.isNotEmpty) {
              CloudflareCookieJar.instance.setUserAgent(uri.host, wvUa);
            }
            notifyListeners();
            cfLog('收割上轮挑战成果成功，验证通过');
            return CloudflareSolveResult(
              cookies: Map<String, String>.from(_cookies),
              html: html,
            );
          }
        }
      } catch (_) {}
      cfLog('上轮无可收割成果，重新加载验证页');
    }

    try {
      await controller.loadRequest(uri);
    } catch (_) {
      // 加载失败不影响轮询（页面可能已在加载中）
    }
    _solveCompleter = Completer<CloudflareSolveResult?>();
    _startPoll();
    // 90s 兜底：IDN/punycode 域名下 Turnstile 要先做 STUN/adapter 探测、
    // 全部超时后才降级执行，真机实测挑战页停留 ~35-45s 后才自动通过，
    // 40s 兜底会在通过前几秒掐掉流程。超时说明本轮环境异常，自动取消
    // 防死循环，冷却后可重试（项目硬约束：兜底必须 ≥90s）。
    _solveTimeoutTimer = Timer(const Duration(seconds: 90), () {
      cfLog('验证 90s 未完成，本轮取消（防死循环，外层将重试）');
      // 超时取消不置 _userCancelled：solve 外层的重试循环应继续下一轮。
      // UI（_verifying）也由外层统一管理，保持验证页常亮直到重试结束。
      if (_solveCompleter != null && !_solveCompleter!.isCompleted) {
        _solveCompleter!.complete(null);
      }
      _pollTimer?.cancel();
    });
    final res = await _solveCompleter!.future;
    _solveTimeoutTimer?.cancel();
    return res;
  }

  /// 用本地保存的 cookie 静默复活桥接会话（不弹验证 UI）。
  /// 成功（取回真实内容）时返回带 html 的结果（可直接作为触发请求的数据）；
  /// 失败（cookie 过期/无效）返回 null，交由调用方走手动验证流程。
  Future<CloudflareSolveResult?> _tryRevive(
      Uri uri, Map<String, String> cookies) async {
    try {
      cfLog('尝试用本地 cf_clearance 静默复活桥接 (${uri.host})');
      await _writeCookies(uri.host, cookies);
      // 用导航方式验证（fetch 会被该站 WAF 挑战）：
      // clearance 有效 → 直接加载出真实页面；无效 → 挑战页
      // （等待期内 managed 挑战若自动通过，同样视为复活成功）。
      final html = await _navigateAndRead(uri,
          timeout: const Duration(seconds: 20));
      if (html != null &&
          html.isNotEmpty &&
          !CloudflareDetector.isHtmlChallengeString(html)) {
        _cookies
          ..clear()
          ..addAll(cookies);
        await _readCookies(uri);
        _ready = true;
        _fetchDisabled = false;
        lastError = null;
        // 复活成功也同步 UA：保证 Dart 重放用的 UA 与本 WebView 一致
        final wvUa = await _readWebViewUserAgent();
        if (wvUa != null && wvUa.isNotEmpty) {
          CloudflareCookieJar.instance.setUserAgent(uri.host, wvUa);
        }
        notifyListeners();
        cfLog('静默复活成功，桥接就绪');
        return CloudflareSolveResult(
          cookies: Map<String, String>.from(_cookies),
          html: html,
        );
      }
      cfLog('本地 cf_clearance 已失效，转手动验证');
    } catch (e) {
      cfLog('静默复活异常: $e');
    }
    return null;
  }

  void _startPoll() {
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(
      const Duration(milliseconds: 800),
      (_) => _poll(),
    );
  }

  Future<void> _poll() async {
    // 防止上一轮取数未结束时下一轮 tick 重入
    if (_pollBusy || !_verifying || _solveCompleter == null) return;
    _pollBusy = true;
    _pollCount++;
    try {
      // 诊断（约每 5s 一次）：暴露 readyState/title/body 长度与 JS 求值失败，
      // 用于定位「页面已渲染真实内容但轮询永不确认」的卡点。
      if (_pollCount % 6 == 1) {
        try {
          final diag = await controller
              .runJavaScriptReturningResult(
                  '(document.readyState||"?")+" | "+(document.title||"?")'
                  '+" | "+(((document.body&&document.body.innerText)||"").length)')
              .timeout(const Duration(seconds: 3));
          cfLog('轮询诊断: $diag');
        } catch (e) {
          cfLog('轮询诊断失败(JS求值超时/异常): $e');
        }
      }
      // 必须加超时：页面导航/渲染进程繁忙时 runJavaScriptReturningResult
      // 可能永远不返回，_pollBusy 将永久卡 true、轮询静默死亡
      // （真机实测：第二轮验证 WebView 已加载真实内容，轮询却再无输出）。
      final res = await controller
          .runJavaScriptReturningResult(kCloudflareChallengeCheckJs)
          .timeout(const Duration(seconds: 3));
      final isChallenge = _asBool(res);
      if (isChallenge) {
        // 交互式 Turnstile 自动降级：当 managed 流程卡住且检测到页面内存在
        // 交互式 Turnstile 时，调用打码平台解出 token 并回填，让 Cloudflare
        // 签发 cf_clearance（IDN 域名下纯 WebView 无法完成 Turnstile，这是
        // 唯一全自动路径，免去手动导入）。每轮只尝试一次，避免重复花钱。
        // 仅在轮询若干 tick 后（widget/iframe 有机会渲染）才探测，减少误判。
        if (!_turnstileEscalated && _pollCount >= 3) {
          final hasTurnstile = await _detectTurnstile();
          if (hasTurnstile) {
            _turnstileEscalated = true; // 立即置位，防止重入/重复调用
            _escalateTurnstile(_pendingUri!).then((ok) {
              cfLog('打码平台解 Turnstile ${ok ? '已回填 token' : '未配置或失败'}');
            });
          }
        }
        return;
      }

      // 挑战已消失：挑战通过后 WebView 已重定向回目标 URL，
      // 当前页面的渲染 DOM 就是要取的内容，直接读取确认。
      // 不用 fetch 确认——该站 WAF 会对非导航请求重新发起挑战
      // （真机实测：页面已通过验证，fetch 仍取回 Just a moment 挑战页）。
      cfLog('挑战页已消失，读取当前页面 DOM 确认...');
      final html = await _readDomHtml();
      if (html == null || html.length < 200) {
        cfLog('DOM 读取为空，继续等待');
        return;
      }
      if (CloudflareDetector.isHtmlChallengeString(html)) {
        final marker = CloudflareDetector.challengeMarkerIn(html);
        cfLog('DOM 仍是挑战页 (marker=$marker, len=${html.length})，继续等待');
        return;
      }

      await _readCookies(_pendingUri!);
      _ready = true;
      _pollTimer?.cancel();
      _solveTimeoutTimer?.cancel();
      // 验证成功即把 cookie + WebView UA 同步给 Dart 层（持久化）：
      // cf_clearance 与签发它的浏览器 UA 绑定，Dart 重放必须用同一 UA，
      // 否则 UA 不匹配会被 Cloudflare 直接拒绝（这正是之前「导入/验证后
      // Dart 请求仍被挑战」的原因之一——一直用桌面 UA 重放 Android UA
      // 签发的 clearance）。
      final host = _pendingUri!.host;
      CloudflareCookieJar.instance.store(_pendingUri!, _cookies);
      final wvUa = await _readWebViewUserAgent();
      if (wvUa != null && wvUa.isNotEmpty) {
        CloudflareCookieJar.instance.setUserAgent(host, wvUa);
        cfLog('已同步 WebView UA 到 Dart 层 ($host)');
      }
      final result = CloudflareSolveResult(
        cookies: Map<String, String>.from(_cookies),
        html: html,
      );
      if (!_solveCompleter!.isCompleted) _solveCompleter!.complete(result);
    } catch (_) {
      // 页面未就绪，等待下一轮
    } finally {
      _pollBusy = false;
    }
  }

  /// 通过已验证的 WebView 取任意 URL 的 HTML（共享 TLS 指纹 + cf_clearance）。
  ///
  /// 优先内部 fetch（快、返回原始 HTML）；被站点 WAF 挑战时降级为
  /// 「导航取数」——让 WebView 直接导航到目标 URL（导航请求不会被该站
  /// 挑战），加载完成后读取渲染 DOM。失败/超时/会话过期时返回 null。
  Future<String?> fetchHtml(String url) async {
    if (_controller == null || !_ready) return null;
    final uri = Uri.parse(url);
    String? html;
    if (!_fetchDisabled) {
      html = await _fetchViaJs(uri);
      if (html != null && html.isNotEmpty) {
        if (!CloudflareDetector.isHtmlChallengeString(html)) {
          _fetchChallengeStreak = 0;
          return html;
        }
        _fetchChallengeStreak++;
        cfLog('fetch 被挑战 (连续 $_fetchChallengeStreak 次)，降级导航取数: $url');
        if (_fetchChallengeStreak >= 3) {
          _fetchDisabled = true;
          cfLog('fetch 已连续 3 次被挑战，本会话后续请求直接走导航取数');
        }
      }
    }
    html = await _navigateAndRead(uri);
    if (html != null && html.isNotEmpty) {
      if (!CloudflareDetector.isHtmlChallengeString(html)) return html;
    }
    // 方案 H（过期自动轮换）：连导航取数都拿回挑战页，说明 cf_clearance
    // 已过期、桥接会话失效。降级为未就绪，让下一次请求重新走
    // 「静默复活 → 手动验证」流程，而不是永远停留在过期态。
    final marker = (html != null && html.isNotEmpty)
        ? CloudflareDetector.challengeMarkerIn(html)
        : null;
    _ready = false;
    lastError = 'cf_clearance 已过期，需重新验证或导入';
    notifyListeners();
    cfLog('导航取数失败 (marker=$marker)，标记会话过期');
    return null;
  }

  /// 读取 WebView 真实 UA（Android Chrome UA，非桌面伪装 UA）。
  /// clearance 与签发时的 UA 绑定，Dart 层重放必须用同一个。
  Future<String?> _readWebViewUserAgent() async {
    try {
      final res = await controller
          .runJavaScriptReturningResult('navigator.userAgent')
          .timeout(const Duration(seconds: 3));
      var s = res.toString();
      if (s.length >= 2 && s.startsWith('"') && s.endsWith('"')) {
        try {
          s = json.decode(s) as String;
        } catch (_) {}
      }
      return s;
    } catch (_) {
      return null;
    }
  }

  /// 读取当前页面渲染后的完整 DOM HTML。
  /// Android 的 runJavaScriptReturningResult 对字符串结果包 JSON 引号，需剥掉。
  Future<String?> _readDomHtml() async {
    try {
      final res = await controller
          .runJavaScriptReturningResult(
              'document.documentElement.outerHTML')
          .timeout(const Duration(seconds: 8));
      var s = res.toString();
      if (s.length >= 2 && s.startsWith('"') && s.endsWith('"')) {
        try {
          s = json.decode(s) as String;
        } catch (_) {}
      }
      return s;
    } catch (e) {
      cfLog('DOM 读取失败: $e');
      return null;
    }
  }

  /// 导航取数：让 WebView 直接导航到 [uri]（导航请求不会被该站 WAF 挑战），
  /// 轮询等待页面加载完成且非挑战页后读取渲染 DOM。
  /// 若导航触发的新挑战自动通过，本方法同样能等到真实内容。
  Future<String?> _navigateAndRead(Uri uri,
      {Duration timeout = const Duration(seconds: 30)}) async {
    try {
      await controller.loadRequest(uri);
    } catch (_) {
      // 加载失败继续轮询等待
    }
    final deadline = DateTime.now().add(timeout);
    while (DateTime.now().isBefore(deadline)) {
      await Future.delayed(const Duration(milliseconds: 700));
      try {
        final res = await controller
            .runJavaScriptReturningResult(kCloudflareChallengeCheckJs)
            .timeout(const Duration(seconds: 3));
        if (_asBool(res)) continue; // 仍在挑战页/加载中
        final html = await _readDomHtml();
        if (html != null && html.length >= 200) {
          return CloudflareDetector.isHtmlChallengeString(html) ? null : html;
        }
      } catch (_) {
        // 页面导航间隙，继续等
      }
    }
    return null;
  }

  Future<String?> _fetchViaJs(Uri uri,
      {Duration timeout = const Duration(seconds: 25)}) async {
    final id = DateTime.now().microsecondsSinceEpoch.toString();
    final completer = Completer<String?>();
    _fetchCompleters[id] = completer;
    final js = '(function(){'
        'var id="$id";'
        'var url=${json.encode(uri.toString())};'
        'try{'
        'fetch(url,{credentials:"include",redirect:"follow",cache:"no-store"})'
        '.then(function(r){return r.text();})'
        '.then(function(t){cfFetch.postMessage(JSON.stringify({id:id,html:t}));})'
        '.catch(function(e){cfFetch.postMessage(JSON.stringify({id:id,html:""}));});'
        '}catch(e){cfFetch.postMessage(JSON.stringify({id:id,html:""}));}'
        '})();';
    try {
      controller.runJavaScript(js);
      final html = await completer.future.timeout(timeout);
      lastFetchLen = html?.length;
      lastError = null;
      return html;
    } on TimeoutException {
      _fetchCompleters.remove(id);
      lastError = '桥接取数超时';
      return null;
    }
  }

  /// 检测当前挑战页是否含有交互式 Turnstile 组件。
  ///
  /// 命中特征：存在 `challenges.cloudflare.com` 的 iframe、turnstile 脚本、
  /// 或带 `data-sitekey` 的容器。命中即说明纯 WebView 无法自动完成（IDN
  /// 域名下该 widget 会崩溃），应触发打码平台解。
  Future<bool> _detectTurnstile() async {
    try {
      final res = await controller
          .runJavaScriptReturningResult('''
(function(){
  var html=(document.documentElement&&document.documentElement.outerHTML)||'';
  if(/challenges\\.cloudflare\\.com/.test(html)) return '1';
  if(document.querySelector('iframe[src*="challenges.cloudflare.com"]')) return '1';
  if(document.querySelector('script[src*="turnstile"]')) return '1';
  if(document.querySelector('[data-sitekey]')) return '1';
  return '0';
})()
''')
          .timeout(const Duration(seconds: 3));
      return _asBool(res);
    } catch (_) {
      return false;
    }
  }

  /// 从当前挑战页提取 Turnstile 所需参数：sitekey / action / data。
  /// 三者均可能出现在内联脚本或 widget 容器的属性里。
  Future<_TurnstileInfo?> _extractTurnstileInfo(Uri uri) async {
    try {
      final res = await controller
          .runJavaScriptReturningResult('''
(function(){
  function g(re){
    var m=re.exec((document.documentElement&&document.documentElement.outerHTML)||'');
    return m?m[1]:null;
  }
  var sitekey=null;
  var el=document.querySelector('[data-sitekey]');
  if(el) sitekey=el.getAttribute('data-sitekey');
  if(!sitekey) sitekey=g(/sitekey['"]?\\s*[:=]\\s*['"]([^'"]+)['"]/);
  if(!sitekey){
    var ifr=document.querySelector('iframe[src*="challenges.cloudflare.com"]');
    if(ifr) sitekey=g.call(null,new RegExp('sitekey=([^&]+)'));
  }
  var action=g(/action['"]?\\s*[:=]\\s*['"]([^'"]+)['"]/)||'managed';
  var data=g(/cData['"]?\\s*[:=]\\s*['"]([^'"]+)['"]/)||g(/["']data['"]?\\s*[:=]\\s*['"]([^'"]+)['"]/);
  return JSON.stringify({sitekey:sitekey,action:action,data:data});
})()
''')
          .timeout(const Duration(seconds: 4));
      var s = res.toString();
      if (s.length >= 2 && s.startsWith('"') && s.endsWith('"')) {
        try {
          s = json.decode(s) as String;
        } catch (_) {}
      }
      final map = json.decode(s) as Map<String, dynamic>;
      final sitekey = (map['sitekey'] as String?) ?? '';
      if (sitekey.isEmpty) return null;
      return _TurnstileInfo(
        sitekey: sitekey,
        action: map['action'] as String?,
        data: map['data'] as String?,
      );
    } catch (e) {
      cfLog('提取 Turnstile 参数失败: $e');
      return null;
    }
  }

  /// 调用打码平台解出 token 并回填到挑战页，使 Cloudflare 签发 cf_clearance。
  ///
  /// 返回 true 表示已成功回填 token（等待轮询检测到 cf_clearance 即可）；
  /// false 表示未配置平台 / 未能提取 sitekey / 解失败 / 异常。
  Future<bool> _escalateTurnstile(Uri uri) async {
    if (_escalating) return false;
    _escalating = true;
    try {
      final solver = CaptchaSolverFactory.solver;
      if (solver == null) {
        cfLog('未配置打码平台，跳过自动解 Turnstile（可在设置页填入 API Key）');
        return false;
      }
      final info = await _extractTurnstileInfo(uri);
      if (info == null) {
        cfLog('未能从挑战页提取 Turnstile sitekey，无法自动解');
        return false;
      }
      cfLog('打码平台解 Turnstile：provider=${solver.name} sitekey=${info.sitekey}');
      final solution = await solver.solveTurnstile(
        siteKey: info.sitekey,
        pageUrl: uri.toString(),
        action: info.action,
        data: info.data,
      );
      if (solution == null) {
        cfLog('打码平台未返回 token');
        return false;
      }
      await _injectTurnstileToken(solution.token);
      cfLog('已回填 Turnstile token，等待 Cloudflare 签发 cf_clearance');
      return true;
    } catch (e) {
      cfLog('解 Turnstile 异常: $e');
      return false;
    } finally {
      _escalating = false;
    }
  }

  /// 把打码平台返回的 token 回填到挑战页并提交，触发 Cloudflare 校验。
  ///
  /// IDN 域名下 Turnstile widget 常已崩溃（window.turnstile 未定义），因此
  /// 采用 best-effort 多策略回填：
  /// 1) 直接给隐藏响应字段（cf-turnstile-response / g-recaptcha-response）赋值
  ///    并派发 input/change 事件；
  /// 2) 调用 data-callback 指向的全局回调（若存在）；
  /// 3) 若 window.turnstile 仍可用，尝试 execute；
  /// 4) 提交包含该字段的表单，让 Cloudflare 服务端校验并签发 cf_clearance。
  Future<void> _injectTurnstileToken(String token) async {
    final js = '''
(function(){
  var token=${json.encode(token)};
  function fire(value){
    var inputs=document.querySelectorAll('input[name="cf-turnstile-response"],input[name="g-recaptcha-response"]');
    inputs.forEach(function(i){
      i.value=value;
      i.dispatchEvent(new Event('input',{bubbles:true}));
      i.dispatchEvent(new Event('change',{bubbles:true}));
    });
    var cbName=null;
    var el=document.querySelector('[data-callback]');
    if(el) cbName=el.getAttribute('data-callback');
    if(cbName && window[cbName] && typeof window[cbName]==='function'){
      try{ window[cbName](value); }catch(e){}
    }
    if(window.turnstile && typeof window.turnstile.execute==='function'){
      try{ window.turnstile.execute(null,{callback:function(){}}); }catch(e){}
    }
    var form=document.querySelector('form');
    if(form){
      try{ form.dispatchEvent(new Event('submit',{bubbles:true,cancelable:true})); }catch(e){}
      try{ if(typeof form.requestSubmit==='function') form.requestSubmit(); }catch(e){}
    }
  }
  fire(token);
})();
''';
    try {
      await controller.runJavaScript(js);
    } catch (e) {
      cfLog('回填 Turnstile token 失败: $e');
    }
  }

  Future<void> _readCookies(Uri uri) async {
    try {
      final store =
          await WebViewCookieManager().getCookies(domain: uri);
      for (final c in store) {
        _cookies[c.name] = c.value;
      }
      cfLog('桥接读取 cookie: 含 cf_clearance=${_cookies.containsKey('cf_clearance')}');
    } catch (e) {
      cfLog('桥接 getCookies 失败: $e');
    }
  }

  /// 让 WebView 落到目标域并写入 cookie，确保后续 fetch 同源、可携带 cookie。
  ///
  /// 通过 JS 写入：webview_flutter 4.x 的 WebViewCookie 不支持 secure/httpOnly
  /// 参数，而 cf_clearance 需要 secure 标志才能在 https 同源请求中携带，
  /// 因此用 document.cookie 写入（可指定完整标志）。
  Future<void> _writeCookies(String host, Map<String, String> cookies) async {
    await controller.loadRequest(Uri.parse('https://$host/'));
    final pairs =
        cookies.entries.map((e) => '${e.key}=${e.value}').join('; ');
    final js =
        'document.cookie = ${json.encode('$pairs; domain=$host; path=/; secure; SameSite=None')};';
    // 等页面文档就绪后再写
    await Future.delayed(const Duration(milliseconds: 400));
    await controller.runJavaScript(js);
  }

  /// 应用已保存（导入旁路同步）的 UA——cf_clearance 与签发它的浏览器 UA 绑定，
  /// 重放时 UA 不一致会被 Cloudflare 重新挑战。
  Future<void> _applyUserAgent(String host) async {
    final ua = CloudflareCookieJar.instance.userAgentFor(host);
    if (ua == null) return;
    try {
      await controller.setUserAgent(ua);
      cfLog('桥接已应用导入的 UA: $ua');
    } catch (e) {
      cfLog('应用 UA 失败: $e');
    }
  }

  /// 导入 cf_clearance 旁路：把 cookie 注入 WebView 并标记就绪，
  /// 使其无需走 Turnstile 即可直接桥接取数。
  ///
  /// [userAgent] 为导出该 cookie 的浏览器 UA（强烈建议提供）——
  /// cf_clearance 与 UA 绑定，桥接 fetch 需用同一 UA 才能通过校验。
  Future<void> injectImport(String host, Map<String, String> cookies,
      {String? userAgent}) async {
    _cookies.clear();
    _cookies.addAll(cookies);
    try {
      final ua = userAgent?.trim();
      if (ua != null && ua.isNotEmpty) {
        await controller.setUserAgent(ua);
        CloudflareCookieJar.instance.setUserAgent(host, ua);
        cfLog('桥接已同步 UA: $ua');
      }
      await _writeCookies(host, cookies);
      cfLog('桥接已注入 ${cookies.length} 个 cookie，含 cf_clearance=${cookies.containsKey('cf_clearance')}');
    } catch (e) {
      cfLog('注入 cookie 失败: $e');
    }
    _ready = true;
    notifyListeners();
  }

  /// 用户取消验证（或超时兜底触发）。
  /// 用户手动取消时置 [_userCancelled]，终止 solve 的自动重试循环。
  void cancel() {
    _userCancelled = true;
    if (_solveCompleter != null && !_solveCompleter!.isCompleted) {
      _solveCompleter!.complete(null);
    }
    _pollTimer?.cancel();
    _solveTimeoutTimer?.cancel();
    _verifying = false;
    notifyListeners();
  }

  /// 清除验证状态（设置页“清除验证缓存”时调用）。
  ///
  /// 必须同时：
  /// 1. complete 挂起中的验证 Completer —— 否则正在 await 的请求会永久挂起；
  /// 2. 清空 WebView 平台 cookie 仓库 —— 否则旧的 cf_clearance 仍残留，
  ///    下次验证/取数会继续带着过期 cookie，导致“清除无效”。
  Future<void> reset() async {
    if (_solveCompleter != null && !_solveCompleter!.isCompleted) {
      _solveCompleter!.complete(null);
    }
    _pollTimer?.cancel();
    _solveTimeoutTimer?.cancel();
    _verifying = false;
    _ready = false;
    _cookies.clear();
    lastError = null;
    lastFetchLen = null;
    _fetchChallengeStreak = 0;
    _fetchDisabled = false;
    try {
      await WebViewCookieManager().clearCookies();
      // 同时恢复默认 UA：导入旁路可能设置了桌面 UA，残留会让后续
      // 手动验证的挑战升级为交互式 Turnstile（IDN 域名下必崩）。
      await controller.setUserAgent(null);
    } catch (_) {
      // 个别平台不支持时忽略
    }
    notifyListeners();
  }

  static bool _asBool(dynamic v) {
    if (v == null) return false;
    var s = v.toString();
    // Android 的 evaluateJavascript 对 JS 字符串结果包一层 JSON 引号
    // （返回 "\"1\"" 而非 "1"）。不剥引号的话判断永远为 false，
    // 轮询会把挑战中页面误判为“挑战已消失”（真机踩坑）。
    if (s.length >= 2 && s.startsWith('"') && s.endsWith('"')) {
      s = s.substring(1, s.length - 1);
    }
    return s == '1' || s == 'true' || s == 'True';
  }
}

/// 从挑战页提取的 Turnstile 参数（供打码平台解算）。
class _TurnstileInfo {
  final String sitekey;
  final String? action;
  final String? data;
  const _TurnstileInfo({
    required this.sitekey,
    this.action,
    this.data,
  });
}
