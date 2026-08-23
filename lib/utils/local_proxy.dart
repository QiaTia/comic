import 'dart:async';
import 'dart:io';

import 'cloudflare.dart' show cfLog;
import 'doh.dart';

/// 本地 HTTP CONNECT 代理：修复 App 进程 DNS 被 ROM 内置 HTTPDNS 劫持的问题。
///
/// 用法：HTTP 客户端 `findProxy` 指向 `127.0.0.1:<port>`。代理收到
/// `CONNECT host:443` 后：系统 DNS 解析（快，多数域名正常）→ 失败则 DoH
/// 解析（绕过劫持）→ TCP 直连真实 IP:443 → 双向透传字节流。
///
/// TLS 由原始客户端在隧道内完成，SNI/证书/TLS 指纹均不受影响。
/// 代理内部（DoH 查询、上游连接）使用独立的 Socket/HttpClient，不经自身
/// 转发，天然无回环。
class CfLocalProxy {
  CfLocalProxy._();

  static HttpServer? _server;

  /// 当前监听端口；未启动时为 null（调用方应回退 DIRECT）。
  static int? get port => _server?.port;
  static bool get running => _server != null;

  /// 启动代理（幂等）。返回监听端口；失败返回 null。
  static Future<int?> start() async {
    if (_server != null) return _server!.port;
    try {
      _server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      _server!.listen(_onRequest,
          onError: (Object e) => cfLog('本地代理监听错误: $e'));
      cfLog('本地代理已启动 127.0.0.1:${_server!.port}');
      return _server!.port;
    } catch (e) {
      cfLog('本地代理启动失败: $e');
      _server = null;
      return null;
    }
  }

  static Future<void> _onRequest(HttpRequest req) async {
    if (req.method != 'CONNECT') {
      // 只做 CONNECT 隧道（站内请求全为 https）
      req.response.statusCode = HttpStatus.badRequest;
      await req.response.close();
      return;
    }
    await _tunnel(req);
  }

  /// CONNECT 隧道：解析上游 IP → 直连 → 双向透传。
  static Future<void> _tunnel(HttpRequest req) async {
    Socket? upstream;
    Socket? client;
    try {
      // CONNECT 请求的 uri 是 authority 形式 "host:port"
      final authority = req.uri.toString();
      final idx = authority.lastIndexOf(':');
      final host = idx > 0 ? authority.substring(0, idx) : authority;
      final port =
          idx > 0 ? int.tryParse(authority.substring(idx + 1)) ?? 443 : 443;

      final addr = await _resolveUpstream(host);
      upstream = await Socket.connect(addr, port,
          timeout: const Duration(seconds: 12));

      // 回 200 并取回底层 socket 做双向转发。
      // detachSocket 会先写出已设置的状态行（HTTP/1.1 200 OK），
      // 客户端（Dart HttpClient / WebView）对 CONNECT 只校验 2xx。
      req.response.statusCode = HttpStatus.ok;
      client = await req.response.detachSocket();

      _pipe(client, upstream);
      cfLog('隧道建立 $authority -> ${addr.address}:$port');
    } catch (e) {
      cfLog('隧道建立失败 (${req.uri}): $e');
      try {
        if (client == null) {
          req.response.statusCode = HttpStatus.badGateway;
          await req.response.close();
        } else {
          client.destroy();
        }
      } catch (_) {}
      upstream?.destroy();
    }
  }

  /// 上游地址：系统 DNS 优先，失败回退 DoH（punycode/IDN 域名在部分 ROM 上
  /// 被 HTTPDNS 劫持，shell 正常但 App 内 lookup 失败）。
  static Future<InternetAddress> _resolveUpstream(String host) async {
    try {
      final addrs = await InternetAddress.lookup(host)
          .timeout(const Duration(seconds: 3));
      if (addrs.isNotEmpty) return addrs.first;
    } catch (_) {}
    final ips = await DohResolver.lookup(host);
    if (ips != null && ips.isNotEmpty) return InternetAddress(ips.first);
    throw SocketException('DNS 解析失败（系统 + DoH）: $host');
  }

  /// 双向转发：一侧 EOF 时关闭对端写方向（close 会 flush 并半关闭，
  /// 对端将收到 EOF），异常时销毁对端。
  static void _pipe(Socket a, Socket b) {
    a.listen(
      b.add,
      onDone: () => b.close(),
      onError: (Object _) => b.destroy(),
      cancelOnError: true,
    );
    b.listen(
      a.add,
      onDone: () => a.close(),
      onError: (Object _) => a.destroy(),
      cancelOnError: true,
    );
  }
}
