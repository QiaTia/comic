import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:shared_preferences/shared_preferences.dart';

import 'cloudflare.dart';

/// 打码平台自动解 Cloudflare Turnstile 的抽象层。
///
/// ## 为什么需要它（根因）
/// 目标站是 IDN/punycode 域名。Cloudflare 的交互式 Turnstile 跑在
/// `challenges.cloudflare.com` 的第三方 iframe 里，在 Android WebView 中
/// 因 `postMessage` 的 origin 与该 IDN 域名不匹配而抛 `SecurityError`
/// （"No available adapters"），渲染进程崩溃，`cf_clearance` 永远写不进去。
/// 因此纯 WebView 自动过验证只能赌「managed 挑战免交互自动通过」；一旦站点
/// 升级为 interactive Turnstile，自动路径必死，只剩「手动导入 cf_clearance」。
///
/// 本层把「解验证码」这一最难的环节外包给专业打码平台
/// （2Captcha / Anti-Captcha 的 AntiTurnstileTask）：平台用真实浏览器跑完
/// Turnstile，返回一个一次性 token；App 侧在常驻 WebView 内把该 token 回填到
/// 挑战表单并提交，由 Cloudflare 校验通过后签发 `cf_clearance`——
/// 从而【免手动导入、全自动】过验证。
///
/// ## 约束
/// - 需要打码平台 API Key（付费）。无 Key 时 [CaptchaSolverFactory.solver]
///   返回 null，调用方自动降级回 managed 流程 / 手动导入旁路。
/// - token 与请求时的 IP/UA/TLS 指纹绑定，必须在【同一个】WebView 会话内
///   回填（本设计正是常驻 WebView 桥接器做这件事）。
/// - IDN 域名下 Turnstile widget 可能已崩溃，此时无法走 `window.turnstile`
///   回调，只能 best-effort 回填隐藏字段 + 提交表单（详见 cloudflare_bridge.dart
///   的 [_CloudflareBridgeState._injectTurnstileToken]）。
class TurnstileSolver {
  TurnstileSolver._();
}

/// 打码平台解出的一次性 Turnstile token。
class CaptchaSolution {
  final String token;
  const CaptchaSolution(this.token);
}

/// 打码平台统一接口。
///
/// 实现者负责把 [solveTurnstile] 的入参映射成平台特有的 HTTP 协议，
/// 并轮询直到返回 [CaptchaSolution] 或超时/失败。
abstract class CaptchaSolver {
  /// 平台显示名（用于日志）。
  String get name;

  /// 解出 [pageUrl] 对应站点在 [siteKey] 下的 Turnstile token。
  ///
  /// 返回 null 表示当前不可解（无 Key / 网络失败 / 平台报错 / 超时）。
  /// [action] 为 Turnstile 的 `action`（通常 `managed`/`login` 等），
  /// [data] 为挑战页内联脚本里的 `cData`/`data` 参数（部分站点需要）。
  Future<CaptchaSolution?> solveTurnstile({
    required String siteKey,
    required String pageUrl,
    String? action,
    String? data,
    String? pageData,
  });
}

/// 2Captcha / Anti-Captcha 的 AntiTurnstileTask 实现。
///
/// 两者协议几乎一致（仅 baseUrl 与 createTask/generateTaskResult 路径不同），
/// 因此用 [baseUrl] 参数化复用同一套逻辑。
///
/// 协议要点（2Captcha，anti-captcha 同构）：
/// 1. POST {baseUrl}/createTask
///    { "clientKey": "...", "task": { "type":"TurnstileTaskProxyless",
///      "websiteKey":"...", "websiteURL":"...", "pageAction":"...",
///      "data":"...", "pageData":"..." } }
///    → { "errorId":0, "taskId":"..." }
/// 2. POST {baseUrl}/getTaskResult
///    { "clientKey":"...", "taskId":"..." }
///    → 轮询直到 { "status":"ready", "solution":{ "token":"..." } }
class _HttpTurnstileSolver implements CaptchaSolver {
  _HttpTurnstileSolver(this._apiKey, this._baseUrl, this._resultPath);

  final String _apiKey;
  final String _baseUrl;
  /// getTaskResult 的路径（2captcha: getTaskResult；anti-captcha: getTaskResult）。
  final String _resultPath;

  @override
  String get name => _baseUrl.contains('2captcha') ? '2Captcha' : 'Anti-Captcha';

  static const _maxPolls = 30; // 30 × 5s = 150s，覆盖 Cloudflare 自定义超时

  @override
  Future<CaptchaSolution?> solveTurnstile({
    required String siteKey,
    required String pageUrl,
    String? action,
    String? data,
    String? pageData,
  }) async {
    if (_apiKey.isEmpty) return null;

    final task = <String, dynamic>{
      'type': 'TurnstileTaskProxyless',
      'websiteKey': siteKey,
      'websiteURL': pageUrl,
    };
    if (action != null && action.isNotEmpty) task['pageAction'] = action;
    if (data != null && data.isNotEmpty) task['data'] = data;
    if (pageData != null && pageData.isNotEmpty) task['pageData'] = pageData;

    final create = await _postJson('$_baseUrl/createTask', {
      'clientKey': _apiKey,
      'task': task,
    });
    if (create == null) return null;

    final taskId = create['taskId'] as String?;
    if (taskId == null || taskId.isEmpty) {
      cfLog('[$name] createTask 未返回 taskId: $create');
      return null;
    }
    cfLog('[$name] 已创建解 Turnstile 任务 taskId=$taskId');

    for (var i = 0; i < _maxPolls; i++) {
      await Future.delayed(const Duration(seconds: 5));
      final res = await _postJson('$_baseUrl/$_resultPath', {
        'clientKey': _apiKey,
        'taskId': taskId,
      });
      if (res == null) continue;

      // 错误响应（errorId != 0 或显式 errorCode）
      final errId = res['errorId'];
      if (errId != null && errId is int && errId != 0) {
        cfLog('[$name] 任务报错: $res');
        return null;
      }
      final status = res['status'] as String?;
      if (status == 'ready') {
        final sol = res['solution'] as Map<String, dynamic>?;
        final token = sol?['token'] as String?;
        if (token != null && token.isNotEmpty) {
          cfLog('[$name] 已解出 Turnstile token (len=${token.length})');
          return CaptchaSolution(token);
        }
        cfLog('[$name] status=ready 但缺少 token: $res');
        return null;
      }
      // status == processing / empty：继续轮询
    }
    cfLog('[$name] 解 Turnstile 轮询超时（${_maxPolls * 5}s）');
    return null;
  }

  /// 简单的 JSON POST（带超时），失败返回 null。
  Future<Map<String, dynamic>?> _postJson(
      String url, Map<String, dynamic> body) async {
    HttpClient? client;
    try {
      client = HttpClient()..connectionTimeout = const Duration(seconds: 15);
      final req = await client.postUrl(Uri.parse(url));
      req.headers.set('Content-Type', 'application/json');
      req.headers.set('Accept', 'application/json');
      req.write(json.encode(body));
      final resp = await req.close().timeout(const Duration(seconds: 25));
      final text = await resp.transform(utf8.decoder).join();
      client.close();
      if (resp.statusCode != 200) {
        cfLog('[$name] HTTP ${resp.statusCode}: $text');
        return null;
      }
      return json.decode(text) as Map<String, dynamic>;
    } catch (e) {
      cfLog('[$name] 请求异常: $e');
      return null;
    } finally {
      client?.close(force: true);
    }
  }
}

/// 打码平台配置（持久化到 SharedPreferences）。
///
/// 三个字段：是否启用、服务商、API Key。无 API Key 视为未配置。
class CaptchaSettings {
  CaptchaSettings._();
  static final CaptchaSettings instance = CaptchaSettings._();

  static const _kEnabled = '__cf_captcha_enabled';
  static const _kProvider = '__cf_captcha_provider';
  static const _kApiKey = '__cf_captcha_apikey';

  bool _enabled = false;
  String _provider = '2captcha';
  String _apiKey = '';

  /// 初始化（main 中调用一次）。
  Future<void> init() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _enabled = prefs.getBool(_kEnabled) ?? false;
      _provider = prefs.getString(_kProvider) ?? '2captcha';
      _apiKey = prefs.getString(_kApiKey) ?? '';
    } catch (_) {}
  }

  bool get enabled => _enabled;
  String get provider => _provider;
  String get apiKey => _apiKey;

  Future<void> set({
    bool? enabled,
    String? provider,
    String? apiKey,
  }) async {
    _enabled = enabled ?? _enabled;
    _provider = provider ?? _provider;
    _apiKey = apiKey ?? _apiKey;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_kEnabled, _enabled);
      await prefs.setString(_kProvider, _provider);
      await prefs.setString(_kApiKey, _apiKey);
    } catch (_) {}
  }
}

/// 根据当前配置构造打码平台 solver；未启用或无 Key 时返回 null。
class CaptchaSolverFactory {
  CaptchaSolverFactory._();

  /// 返回当前已配置的 solver，或在未配置时返回 null（调用方据此降级）。
  static CaptchaSolver? get solver {
    final s = CaptchaSettings.instance;
    if (!s.enabled || s.apiKey.trim().isEmpty) return null;
    final key = s.apiKey.trim();
    switch (s.provider) {
      case 'anticaptcha':
        return _HttpTurnstileSolver(
            key, 'https://api.anti-captcha.com', 'getTaskResult');
      case '2captcha':
      default:
        return _HttpTurnstileSolver(
            key, 'https://api.2captcha.com', 'getTaskResult');
    }
  }
}
