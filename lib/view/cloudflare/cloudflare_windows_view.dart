import 'dart:async';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:webview_windows/webview_windows.dart';

import '../../utils/cloudflare.dart';

/// Windows 桌面端的 Cloudflare 验证页（基于 webview_windows / Edge WebView2）。
class CloudflareWindowsView extends StatefulWidget {
  final Uri uri;
  const CloudflareWindowsView({super.key, required this.uri});

  @override
  State<CloudflareWindowsView> createState() => _CloudflareWindowsViewState();
}

class _CloudflareWindowsViewState extends State<CloudflareWindowsView> {
  final _controller = WebviewController();
  bool _initialized = false;
  bool _done = false;
  bool _sawChallenge = false;
  bool _loading = true;
  Timer? _timer;
  String? _error;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    try {
      await _controller.initialize();
      await _controller.setBackgroundColor(Colors.transparent);

      _controller.loadingState.listen((state) {
        _loading = state == LoadingState.loading;
        if (state == LoadingState.navigationCompleted) _check();
      });
      _controller.title.listen((_) => _check());

      await _controller.loadUrl(widget.uri.toString());

      _timer = Timer.periodic(
        const Duration(milliseconds: 800),
        (_) => _check(),
      );
      if (mounted) setState(() => _initialized = true);
    } catch (e) {
      if (mounted) {
        setState(() => _error = e.toString());
      }
    }
  }

  /// 通过「挑战 UI 是否消失」判断验证是否成功。
  /// 不能用 document.cookie 里的 cf_clearance（HttpOnly，JS 读不到）。
  Future<void> _check() async {
    if (_done || !mounted) return;
    try {
      final res = await _controller.executeScript(kCloudflareChallengeCheckJs);
      final isChallenge = _asBool(res);
      if (isChallenge) {
        _sawChallenge = true;
        return;
      }
      // 挑战页已消失，且确实见过挑战页，且页面加载完成 → 验证成功
      if (_sawChallenge && !_loading) {
        await _finish();
      }
    } catch (_) {
      // 页面未就绪时忽略，等待下一次轮询
    }
  }

  static bool _asBool(dynamic v) {
    if (v == null) return false;
    final s = v.toString();
    return s == '1' || s == 'true' || s == 'True';
  }

  /// 验证成功：读 cookie（尽力）+ 用 WebView 内部 fetch 取回真实 HTML 后回传。
  Future<void> _finish() async {
    _done = true;
    _timer?.cancel();

    final cookies = <String, String>{};
    try {
      final c = await _controller.executeScript('document.cookie');
      cookies.addAll(_parseCookieString(c is String ? c : c.toString()));
    } catch (_) {}

    String? html;
    try {
      final fetched = await _controller.executeScript(
        "fetch(location.href,{credentials:'include',redirect:'follow'})"
        ".then(function(r){return r.text();})",
      );
      html = fetched is String ? fetched : fetched?.toString();
    } catch (_) {}

    if (!mounted) return;
    Get.back(result: CloudflareSolveResult(cookies: cookies, html: html));
  }

  static Map<String, String> _parseCookieString(String cookieStr) {
    final map = <String, String>{};
    for (final pair in cookieStr.split(';')) {
      final kv = pair.trim().split('=');
      if (kv.length >= 2) map[kv[0]] = kv.sublist(1).join('=');
    }
    return map;
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Cloudflare 安全验证'),
        actions: [
          IconButton(
            icon: const Icon(Icons.close),
            tooltip: '取消',
            onPressed: () {
              _timer?.cancel();
              Get.back(result: null);
            },
          ),
        ],
      ),
      body: !_initialized
          ? Center(
              child: _error != null
                  ? Padding(
                      padding: const EdgeInsets.all(16),
                      child: Text(
                        'WebView2 初始化失败: $_error\n请确认已安装 Microsoft Edge WebView2 Runtime。',
                        textAlign: TextAlign.center,
                      ),
                    )
                  : const CircularProgressIndicator(),
            )
          : Webview(_controller),
    );
  }
}
