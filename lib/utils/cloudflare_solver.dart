import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:get/get.dart';

import 'cloudflare.dart';
import 'cloudflare_bridge.dart';
import '../view/cloudflare/cloudflare_windows_view.dart';

/// Cloudflare 验证调度器。
///
/// 在 HTTP 请求层检测到挑战页后调用 [solve]，
/// 会按需唤起对应平台的 WebView 让用户手动完成验证，
/// 验证成功（出现 cf_clearance cookie）后返回完整的 cookie 映射。
///
/// 返回 `null` 表示用户取消；抛出 [CloudflareVerificationFailedException]
/// 表示短时间内重复失败（防止 WebView 验证在设备上永远过不去时造成的死循环）。
class CloudflareSolver {
  CloudflareSolver._();

  static bool _solving = false;

  /// 当前正在进行的验证任务。并发请求会共享其结果，避免重复弹 WebView。
  /// 注意：共享结果中的 html 只对应“首个触发验证”的那个请求 URL，
  /// 因此并发请求只复用 cookie（cf_clearance），各自再用自身 URL 走 cookie 重试。
  static Completer<CloudflareSolveResult?>? _currentSolve;

  /// 同一 host 短时间内反复失败时的冷却（毫秒），避免无限循环弹验证。
  static const int _cooldownMs = 10000;
  static final Map<String, int> _recentFail = {};

  /// 本会话内已确认“验证过不去”的 host。命中后直接失败，不再弹 WebView，
  /// 避免 Cloudflare 在该环境下永远无法完成时反复弹窗形成死循环。
  static final Set<String> _failedHosts = {};

  /// 清除失败记录（例如在设置页“清除验证缓存”时调用，允许用户再次尝试）。
  static void clearFailedHosts() {
    _failedHosts.clear();
    _recentFail.clear();
  }

  /// 显式标记某 host 验证失败（请求层在“WebView 已完成但取回内容仍是挑战页、
  /// 且 cookie 重试仍失败”时调用），避免对每个请求重复弹出 WebView 形成循环。
  static void markFailed(String host) => _failedHosts.add(host);

  static Future<CloudflareSolveResult?> solve(Uri uri) async {
    final host = uri.host;

    // 已确认本会话内该 host 验证过不去：直接失败，不再弹 WebView
    if (_failedHosts.contains(host)) {
      throw CloudflareVerificationFailedException();
    }

    // 短时间内的冷却，避免 UI 重试造成机器枪式弹窗
    final now = DateTime.now().millisecondsSinceEpoch;
    final lastFail = _recentFail[host];
    if (lastFail != null && now - lastFail < _cooldownMs) {
      throw CloudflareVerificationFailedException();
    }

    // 已有验证在进行：等待它完成，只复用其 cookie（不含 html，避免用到别的 URL 的页面）
    if (_solving && _currentSolve != null) {
      final res = await _currentSolve!.future;
      if (res == null) return null;
      return CloudflareSolveResult(cookies: res.cookies, html: null);
    }

    _solving = true;
    _currentSolve = Completer<CloudflareSolveResult?>();
    try {
      CloudflareSolveResult? result;
      if (!kIsWeb && Platform.isWindows) {
        result = await Get.to<CloudflareSolveResult?>(
            () => CloudflareWindowsView(uri: uri));
      } else {
        // 移动端：使用常驻 WebView 桥接器完成验证并保留会话，
        // 这样后续所有请求都通过该 WebView 取数（共享 TLS 指纹 + cf_clearance）。
        result = await CloudflareBridge.instance.solve(uri);
      }
      if (result == null) {
        // 用户取消或验证未产出结果：记入冷却 + 失败 host，防止死循环
        _recentFail[host] = DateTime.now().millisecondsSinceEpoch;
        _failedHosts.add(host);
      } else {
        _recentFail.remove(host);
        _failedHosts.remove(host);
      }
      _currentSolve!.complete(result);
      return result;
    } catch (e) {
      _currentSolve!.complete(null);
      rethrow;
    } finally {
      _solving = false;
      _currentSolve = null;
    }
  }
}
