import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:get/get_connect/connect.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'doh.dart';

/// Cloudflare 相关调试日志：仅 debug 模式输出，release 构建不刷日志。
void cfLog(String message) {
  if (kDebugMode) print('[CF] $message');
}

/// 全站统一使用的浏览器 UA（桌面 Chrome 120）。
/// HTTP 请求层与 WebView 验证使用同一 UA：clearance cookie 与 UA 绑定，
/// 重放时必须一致。真机实测：Dart HTTP + Chrome/142 UA 会被 Cloudflare 直接
/// 重置连接（status=null）；Chrome/120 稳定返回 403 挑战页，可走验证流程。
/// 切勿随意升级此版本号。
/// 默认 UA：与 CloudflareBridge WebView 的 UA 完全一致（Android Chrome、
/// 无 wv 标记）。cf_clearance 与签发时的 UA 绑定，Dart 重放必须用同一 UA。
const kBrowserUserAgent =
    'Mozilla/5.0 (Linux; Android 13) AppleWebKit/537.36 (KHTML, like Gecko) '
    'Chrome/124.0.0.0 Mobile Safari/537.36';

/// UA 预设：部分设备 WebView 原生 UA 无法通过 Cloudflare 验证，
/// 允许用户在设置页选择预设 UA 覆写（对 WebView 与 Dart 请求同时生效）。
/// key 为设置页展示的标识，value null 表示「默认」（设备原生 UA，
/// 验证时自动剥 wv 标记）。
const Map<String, String?> kUaPresets = {
  'default': null,
  'pc': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 '
      '(KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36',
  'androidTablet': 'Mozilla/5.0 (Linux; Android 13; SM-X910) '
      'AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 '
      'Safari/537.36',
  'androidPhone': kBrowserUserAgent,
  'ipad': 'Mozilla/5.0 (iPad; CPU OS 17_5 like Mac OS X) '
      'AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.5 Mobile/15E148 '
      'Safari/604.1',
  'ios': 'Mozilla/5.0 (iPhone; CPU iPhone OS 17_5 like Mac OS X) '
      'AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.5 Mobile/15E148 '
      'Safari/604.1',
  'macos': 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) '
      'AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.4 Safari/605.1.15',
};

/// 目标站点的当前域名：见 [TargetHostResolver.host]（运行时从
/// [kBuiltinHostCandidates] 或发布页解析，域名轮换频繁）。
/// 注意：这些是 IDN/punycode 域名。Cloudflare 交互式 Turnstile 在 Android
/// WebView 中会因该类域名抛 SecurityError（postMessage origin 不匹配），
/// 因此验证依赖 managed 挑战【免交互自动通过】，并提供
/// 「从真实浏览器导入 cf_clearance」的旁路。

/// 内置候选域名（发布页 2026-08-22 实测存活，按优先级排序）。
/// 该站域名轮换频繁（旧域名直接停止 DNS 解析，如曾经的 ej1 域名），
/// 全部失效时会运行时拉取 [kDomainListUrl] 刷新。
const List<String> kBuiltinHostCandidates = [
  'xn--5wh-mxgmxgcom-yp8ve33bkpevz1kpxq.mxgmxgcom.com',
  'xn--t28-mxgmxgcom-yp8ve33bkpevz1kpxq.mxgmxgcom.com',
  'xn--adq-mxgmxgcom-yp8ve33bkpevz1kpxq.mxgmxgcom.com',
  'xn--8uw-mxgmxgcom-yp8ve33bkpevz1kpxq.mxgmh.com',
  'xn--t4b-mxgmxgcom-yp8ve33bkpevz1kpxq.mxgmh.com',
  'xn--o79-mxgmxgcom-yp8ve33bkpevz1kpxq.manxiange.com',
  'xn--fyi-mxgmxgcom-yp8ve33bkpevz1kpxq.manxiange.com',
  'xn--z8y-mxgmxgcom-yp8ve33bkpevz1kpxq.manxiange.com',
  'xn--lzo-mxgmxgcom-yp8ve33bkpevz1kpxq.manxiange.com',
  'xn--4vg-mxgmxgcom-yp8ve33bkpevz1kpxq.manxiange.com',
];

/// 站点官方发布页的实时域名列表（纯 JS、无 Cloudflare 防护，可直接 HTTP 拉取）。
/// 内容形如 `var domains = ["5wh备用域名-mxgmxg点com.mxgmxgcom.com", ...]`（unicode，需 punycode）。
const kDomainListUrl = 'https://jsd.load-faster.com/mxg.js';

/// RFC 3492 Punycode：把单个域名标签编码为 `xn--` ASCII 形式。
/// 纯 ASCII 标签原样返回。
String punycodeEncodeLabel(String label) {
  final runes = label.runes.toList();
  if (runes.every((r) => r < 128)) return label;

  const base = 36, tmin = 1, tmax = 26, skew = 38, damp = 700;
  const initialBias = 72, initialN = 128;

  int adapt(int delta, int numpoints, bool firstTime) {
    delta = firstTime ? delta ~/ damp : delta ~/ 2;
    delta += delta ~/ numpoints;
    var k = 0;
    while (delta > ((base - tmin) * tmax) ~/ 2) {
      delta ~/= base - tmin;
      k += base;
    }
    return k + (((base - tmin + 1) * delta) ~/ (delta + skew));
  }

  String digit(int d) => String.fromCharCode(d + (d < 26 ? 97 : 22));

  final output = StringBuffer();
  final basicCount = runes.where((r) => r < 128).length;
  output.write(String.fromCharCodes(runes.where((r) => r < 128)));
  // 分隔符：仅当存在 ASCII 基本字符时，在基本部分与编码部分之间加 '-'
  if (basicCount > 0) output.write('-');
  var h = basicCount;
  final total = runes.length;
  var n = initialN, delta = 0, bias = initialBias;

  while (h < total) {
    var m = 0x10ffff;
    for (final c in runes) {
      if (c >= n && c < m) m = c;
    }
    delta += (m - n) * (h + 1);
    n = m;
    for (final c in runes) {
      if (c < n) {
        delta++;
      } else if (c == n) {
        var q = delta;
        for (var k = base;; k += base) {
          final t = (k <= bias)
              ? tmin
              : (k >= bias + tmax) ? tmax : k - bias;
          if (q < t) break;
          output.write(digit(t + ((q - t) % (base - t))));
          q = (q - t) ~/ (base - t);
        }
        output.write(digit(q));
        bias = adapt(delta, h + 1, h == basicCount);
        delta = 0;
        h++;
      }
    }
    delta++;
    n++;
  }
  return 'xn--$output';
}

/// 把 unicode 域名整体转换为 punycode 形式（逐标签编码）。
String punycodeEncodeHost(String host) => host
    .split('.')
    .map((label) => punycodeEncodeLabel(label.trim()))
    .join('.');

/// 目标站点域名解析器。
///
/// 该站域名轮换频繁：旧域名会直接停止 DNS 解析（App 内表现为
/// `Failed host lookup`，所有请求/验证全部失败）。发布页 [kDomainListUrl]
/// 无 Cloudflare 防护，可随时拉到最新域名列表（unicode 形式，经
/// [punycodeEncodeHost] 转换后做 DNS 校验）。
class TargetHostResolver {
  TargetHostResolver._();

  static const _prefsKey = '__cf_target_host';

  static String _host = kBuiltinHostCandidates.first;

  /// 当前生效的目标域名。
  static String get host => _host;

  /// 启动时调用（main 中、runApp 之前）：确定本次会话使用的域名。
  /// 优先上次成功的域名，其次内置列表；全部失效则拉发布页刷新。
  static Future<void> init() async {
    String? saved;
    try {
      final prefs = await SharedPreferences.getInstance();
      saved = prefs.getString(_prefsKey);
    } catch (_) {}

    final candidates = <String>[
      if (saved != null && saved.isNotEmpty) saved,
      ...kBuiltinHostCandidates,
    ];
    final ok = await _pickFirstResolvable(candidates);
    if (ok != null) {
      _setHost(ok);
      return;
    }

    // 内置列表全灭：拉发布页最新列表。
    cfLog('内置候选域名全部失效，拉取发布页刷新域名列表');
    final fresh = await _fetchLatestHosts();
    final ok2 = await _pickFirstResolvable(fresh);
    if (ok2 != null) {
      _setHost(ok2);
    } else {
      cfLog('发布页域名也全部失效，保持默认域名（后续请求将报错）');
    }
  }

  static void _setHost(String h) {
    final changed = h != _host;
    _host = h;
    if (changed) cfLog('目标域名切换为: $h');
    try {
      SharedPreferences.getInstance().then((p) => p.setString(_prefsKey, h));
    } catch (_) {}
  }

  /// 并行对候选列表做 DNS 校验，按优先级返回第一个可解析的域名。
  static Future<String?> _pickFirstResolvable(List<String> hosts) async {
    if (hosts.isEmpty) return null;
    // _dnsOk 内部最多 3s（系统）+ 6s（DoH），外层兜底放宽到 15s。
    final results = await Future.wait(
      hosts.map((h) => _dnsOk(h).timeout(
            const Duration(seconds: 15),
            onTimeout: () => false,
          )),
    );
    for (var i = 0; i < hosts.length; i++) {
      if (results[i]) return hosts[i];
    }
    return null;
  }

  /// 域名可解析性检测：系统 DNS 优先（多数设备正常且快），失败回退 DoH。
  ///
  /// 部分厂商 ROM（realme/OPPO 等）的 HTTPDNS 会劫持 App 进程对 punycode
  /// 域名的解析（shell 正常、App 内 `Failed host lookup`），只用系统 DNS
  /// 会导致所有候选被误判失效。
  static Future<bool> _dnsOk(String host) async {
    try {
      final addrs = await InternetAddress.lookup(host)
          .timeout(const Duration(seconds: 3));
      if (addrs.isNotEmpty) return true;
    } catch (_) {}
    final ips = await DohResolver.lookup(host);
    return ips != null && ips.isNotEmpty;
  }

  /// 拉取发布页域名列表并转为 punycode。
  static Future<List<String>> _fetchLatestHosts() async {
    try {
      final client = HttpClient()..connectionTimeout = const Duration(seconds: 8);
      final req = await client.getUrl(Uri.parse(kDomainListUrl));
      final resp = await req.close().timeout(const Duration(seconds: 10));
      if (resp.statusCode != 200) return [];
      final body = await resp.transform(utf8.decoder).join();
      client.close();

      final m = RegExp(r'domains\s*=\s*\[(.*?)\]').firstMatch(body);
      if (m == null) return [];
      final hosts = RegExp(r'"([^"]+)"')
          .allMatches(m.group(1)!)
          .map((mm) => punycodeEncodeHost(mm.group(1)!))
          .where((h) => h.contains('.'))
          .toList();
      cfLog('发布页拉到 ${hosts.length} 个域名: $hosts');
      return hosts;
    } catch (e) {
      cfLog('拉取发布页域名列表失败: $e');
      return [];
    }
  }
}

/// 注入到 WebView 的 JS：判断当前页是否仍是 Cloudflare 挑战页。
/// 通过【可见文本】（标题/正文）判断，而非读 HttpOnly cookie 或 HTML 源码。
///
/// 注意：不能依赖读取 `document.cookie` 中的 `cf_clearance` 来判断是否通过，
/// 因为 Cloudflare 通常把它设为 HttpOnly，JS 读不到。改为检测「挑战 UI 是否消失」。
/// 同样不要用 'challenge-platform'/'ray-id' 等弱特征——Cloudflare 会给【正常页面】
/// 也注入 /cdn-cgi/challenge-platform/ 脚本，弱特征会造成误判。
const String kCloudflareChallengeCheckJs = r'''
(function(){
  var m=['just a moment','checking your browser','attention required','verify you are human','verify that you are human','enable javascript and cookies to continue','正在进行安全验证','防护恶意自动程序'];
  var t=(document.title||'').toLowerCase();
  var b=((document.body&&document.body.innerText)||'').toLowerCase();
  var h=(location.href||'').toLowerCase();
  if(h.indexOf('cdn-cgi/challenge-platform')>=0){return '1';}
  // DOM 还没开始解析（导航中）视为“未就绪”。
  // 注意不要要求 readyState==='complete'：部分站点子资源（视频流/挂起的
  // 图片请求）会让 load 事件永远不触发，readyState 永远停在 interactive，
  // 轮询将永不确认（真机实测：真实内容早已渲染，40s 兜底取消）。
  if(document.readyState==='loading'){return '1';}
  // 导航间隙的空文档（challenge 自身的重定向循环）：title 与 body 均为空
  // 同样视为“未就绪”。
  if(!t && !b){return '1';}
  for(var i=0;i<m.length;i++){
    if(t.indexOf(m[i])>=0||b.indexOf(m[i])>=0){return '1';}
  }
  // 中文挑战页标题「请稍候…」仅对标题匹配：正文里的“请稍候”常是正常页面的
  // 加载文案，误判会让轮询永远不确认成功、40s 兜底超时。
  if(t.indexOf('请稍候')>=0){return '1';}
  return '0';
})()
''';

/// Cloudflare 挑战页识别。
class CloudflareDetector {
  /// 挑战页标题特征：managed/interactive 挑战页的 `<title>` 固定为这些文案。
  static const _titleMarkers = ['just a moment', '请稍候', 'attention required'];

  /// 挑战页【正文强特征】：任一命中即可判定。
  ///
  /// 警告：不要加入 '_cf_chl_opt' / 'cf-chl-widget' / 'challenge-platform' /
  /// 'ray-id' 这类弱特征——Cloudflare Bot Management 会给【正常页面】的 HTML
  /// 也注入这些脚本标记。真机实测：验证已通过、WebView 已加载出真实站点
  /// 内容，fetch 取回的真实 HTML 却因 '_cf_chl_opt' 被误判为挑战页，
  /// 导致「轮询永不确认成功 → 40s 兜底取消」以及「导入 cf_clearance 后
  /// 桥接会话被误标过期」。
  static const _strongMarkers = [
    'checking your browser',
    'verify you are human',
    'verify that you are human',
    'enable javascript and cookies to continue',
    // 中文环境挑战页文案（真机 WebView 按系统语言返回中文挑战页）。
    '正在进行安全验证',
    '防护恶意自动程序',
  ];

  /// 根据响应判断是否为 Cloudflare 拦截/验证页。
  static bool isChallenge(Response response) {
    final status = response.statusCode ?? 0;
    final headers = response.headers ?? <String, String>{};
    final server = (headers['server'] ?? '').toLowerCase();
    final cfMitigated = (headers['cf-mitigated'] ?? '').toLowerCase();

    // 1) 响应头明确标注为 challenge
    if (cfMitigated.contains('challenge')) return true;

    // 2) 正文强特征（最可靠）
    final body = response.body;
    if (body is String && isHtmlChallengeString(body)) return true;

    // 3) Cloudflare + 拦截状态码（可能是不带正文的挑战响应）
    if (server.contains('cloudflare') && (status == 403 || status == 503)) {
      return true;
    }

    return false;
  }

  /// 直接对一段 HTML 字符串判断是否 Cloudflare 挑战页
  /// （供 WebView 取回的 HTML 校验用；只用强特征，防止真实页面被误判）。
  static bool isHtmlChallengeString(String html) =>
      challengeMarkerIn(html) != null;

  /// 返回命中的挑战特征（用于诊断日志）；非挑战页返回 null。
  ///
  /// 优先解析 `<title>`：managed/interactive 挑战页标题固定为
  /// "Just a moment..." / 「请稍候…」，而正常页面的标题不会是这些。
  static String? challengeMarkerIn(String html) {
    final lower = html.toLowerCase();
    final titleMatch = RegExp(r'<title[^>]*>(.*?)</title>').firstMatch(lower);
    if (titleMatch != null) {
      final t = (titleMatch.group(1) ?? '').trim();
      for (final m in _titleMarkers) {
        if (t.contains(m)) return 'title:$m';
      }
    }
    for (final marker in _strongMarkers) {
      if (lower.contains(marker)) return marker;
    }
    return null;
  }
}

/// 用户主动取消验证时抛出。
class CloudflareVerificationCancelledException implements Exception {
  @override
  String toString() => 'Cloudflare 验证已取消';
}

/// 验证完成但重新请求仍被拦截时抛出。
class CloudflareVerificationFailedException implements Exception {
  @override
  String toString() => 'Cloudflare 验证失败，请重试或清除验证缓存后重试';
}

/// WebView 验证结果。
/// - [cookies]：尽力从 `document.cookie` 读到的「可读」cookie（可能不含 HttpOnly 的 cf_clearance）。
/// - [html]：验证成功后用 WebView 内部 `fetch` 取回的真实页面 HTML。
///   该 fetch 会自动携带 WebView 自身的 cookie（包含 HttpOnly 的 cf_clearance），
///   因此即便 Dart 侧无法读取 cf_clearance，也能正确拿到数据。
class CloudflareSolveResult {
  final Map<String, String> cookies;
  final String? html;

  CloudflareSolveResult({required this.cookies, this.html});
}

/// 已通过验证的 Cookie 缓存（按 host 维度），支持持久化。
class CloudflareCookieJar {
  CloudflareCookieJar._();
  static final CloudflareCookieJar instance = CloudflareCookieJar._();

  final Map<String, Map<String, String>> _store = {};
  final Map<String, String> _uaStore = {};
  static const _prefsKey = '__cf_cookie_jar';
  static const _uaPrefsKey = '__cf_user_agents';
  static const _uaPresetPrefsKey = '__cf_ua_preset';

  /// 用户选择的 UA 预设（kUaPresets 的 key，'default' 表示用设备原生 UA）。
  String _uaPreset = 'default';

  /// 启动时调用，从本地恢复已保存的 clearance cookie。
  Future<void> init() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_prefsKey);
      if (raw != null) {
        final decoded = json.decode(raw) as Map<String, dynamic>;
        decoded.forEach((host, cookies) {
          _store[host] = Map<String, String>.from(cookies as Map);
        });
      }
      final uaRaw = prefs.getString(_uaPrefsKey);
      if (uaRaw != null) {
        final decoded = json.decode(uaRaw) as Map<String, dynamic>;
        decoded.forEach((host, ua) {
          _uaStore[host] = ua as String;
        });
      }
      final preset = prefs.getString(_uaPresetPrefsKey);
      if (preset != null && kUaPresets.containsKey(preset)) {
        _uaPreset = preset;
      }
    } catch (_) {
      // 读取失败不影响主流程
    }
  }

  /// 保存某次验证得到的 cookie（与已存在的合并）。
  void store(Uri uri, Map<String, String> cookies) {
    final host = uri.host;
    final bucket = _store.putIfAbsent(host, () => <String, String>{});
    bucket.addAll(cookies);
    _persist();
  }

  bool hasCookiesFor(Uri uri) =>
      _store[uri.host]?.isNotEmpty ?? false;

  /// 生成用于请求头 `Cookie` 字段的字符串，匹配 host 及其子域。
  String? cookieHeaderFor(Uri uri) {
    final matched = <String, String>{};
    _store.forEach((host, cookies) {
      if (_hostMatches(host, uri.host)) matched.addAll(cookies);
    });
    if (matched.isEmpty) return null;
    return matched.entries.map((e) => '${e.key}=${e.value}').join('; ');
  }

  bool _hostMatches(String storedHost, String targetHost) {
    return storedHost == targetHost ||
        targetHost.endsWith('.$storedHost') ||
        storedHost.endsWith('.$targetHost');
  }

  /// 清除所有已保存的验证 cookie。
  Future<void> clear() async {
    _store.clear();
    _uaStore.clear();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_prefsKey);
      await prefs.remove(_uaPrefsKey);
    } catch (_) {}
  }

  void _persist() {
    try {
      SharedPreferences.getInstance().then((prefs) {
        prefs.setString(_prefsKey, json.encode(_store));
      });
    } catch (_) {}
  }

  void _persistUas() {
    try {
      SharedPreferences.getInstance().then((prefs) {
        prefs.setString(_uaPrefsKey, json.encode(_uaStore));
      });
    } catch (_) {}
  }

  /// cf_clearance 与签发它的浏览器 UA 绑定。导入 cookie 时应同步保存该 UA，
  /// 供 WebView 桥接与 Dart 请求使用相同 UA 重放，避免 UA 不匹配被重新挑战。
  void setUserAgent(String host, String userAgent) {
    _uaStore[host] = userAgent;
    _persistUas();
  }

  /// 当前 UA 预设 key（kUaPresets 之一）。
  String get uaPreset => _uaPreset;

  /// 设置 UA 预设并持久化。'default' 表示回到设备原生 UA。
  Future<void> setUaPreset(String preset) async {
    if (!kUaPresets.containsKey(preset)) return;
    _uaPreset = preset;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_uaPresetPrefsKey, preset);
    } catch (_) {}
  }

  /// 预设对应的 UA 字符串；'default' 或未设预设返回 null（用设备原生 UA）。
  String? get uaPresetValue => kUaPresets[_uaPreset];

  /// 某 host 已同步的 UA（导入旁路保存的）；未导入过则返回 null（用默认 UA）。
  String? userAgentFor(String host) => _uaStore[host];

  /// 解析 cookie 头字符串（形如 `a=1; b=2` 或 `cf_clearance=xxxx`）为键值对。
  /// 也兼容用户只粘贴了 cf_clearance 的值本身（不含 `=`），此时视为 cf_clearance。
  static Map<String, String> parseRawCookie(String raw) {
    var normalized = raw.trim();
    if (normalized.isEmpty) return {};
    // 仅粘贴了值（无 `=`）时，当作 cf_clearance 值处理
    if (!normalized.contains('=')) {
      normalized = 'cf_clearance=$normalized';
    }
    final map = <String, String>{};
    for (final part in normalized.split(';')) {
      final kv = part.trim().split('=');
      if (kv.length >= 2 && kv[0].isNotEmpty) {
        map[kv[0]] = kv.sublist(1).join('=');
      }
    }
    return map;
  }

  /// 从真实浏览器复制的 cookie 字符串导入，绕过 WebView 无法完成 Turnstile 的问题。
  ///
  /// [host] 通常为 [TargetHostResolver.host]。导入后该 host 的后续请求会携带这些 cookie，
  /// 命中 cf_clearance 即可直接通过 Cloudflare，不再弹 WebView。
  ///
  /// 返回是否成功导入了 `cf_clearance`（没有它则绕过无效）。
  Future<bool> importFromRawCookie(String host, String raw) async {
    final cookies = parseRawCookie(raw);
    if (cookies.isEmpty) return false;
    final bucket = _store.putIfAbsent(host, () => <String, String>{});
    bucket.addAll(cookies);
    _persist();
    return cookies.containsKey('cf_clearance');
  }

  /// 当前已为 [host] 保存的 cookie（只读副本）。
  Map<String, String> cookiesFor(String host) =>
      Map<String, String>.from(_store[host] ?? {});

  /// 是否已保存可用的 cf_clearance（用于设置页展示状态）。
  bool hasClearanceFor(String host) =>
      (_store[host]?['cf_clearance']?.isNotEmpty ?? false);
}
