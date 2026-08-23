import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'cloudflare.dart' show cfLog;

/// DoH（DNS over HTTPS）解析器：绕过设备系统 DNS/HTTPDNS 劫持。
///
/// 背景：部分厂商 ROM（realme/OPPO 等）内置 HTTPDNS 会劫持 App 进程的域名
/// 解析，对 IDN/punycode 长域名直接失败（`Failed host lookup`），而 shell
/// 层 nslookup 正常。DoH 通过 HTTPS 向公共 DNS（阿里/腾讯）查询，IP 直连 +
/// TLS 加密，不受系统 HTTPDNS 影响。
///
/// 端点直接用服务器 IP，避免「解析 DoH 服务器域名」的先有鸡问题。
class DohResolver {
  DohResolver._();

  static const _cacheTtl = Duration(minutes: 5);
  static final Map<String, _CacheEntry> _cache = {};

  /// JSON API 端点 -> Accept 头。
  /// - 阿里公共 DNS：https://223.5.5.5/resolve（证书含 IP SAN）
  /// - 腾讯 DNSPod：https://120.53.53.53/dns-query（doh.pub，IP 形式）
  static const _endpoints = <String, String>{
    'https://223.5.5.5/resolve': 'application/dns-json',
    'https://120.53.53.53/dns-query': 'application/dns-json',
  };

  /// 解析 [host] 的 A 记录。多端点并发，任一成功即用；全部失败返回 null。
  static Future<List<String>?> lookup(String host,
      {Duration timeout = const Duration(seconds: 6)}) async {
    final cached = _cache[host];
    if (cached != null && DateTime.now().isBefore(cached.expiresAt)) {
      return cached.ips;
    }

    final completer = Completer<List<String>?>();
    var pending = _endpoints.length;
    for (final entry in _endpoints.entries) {
      unawaited(
        _query(entry.key, entry.value, host, timeout)
            .then((ips) {
          if (ips != null && ips.isNotEmpty && !completer.isCompleted) {
            completer.complete(ips);
          }
        }).catchError((Object e) {
          cfLog('DoH 端点查询失败 ($host): $e');
        }).whenComplete(() {
          pending--;
          if (pending == 0 && !completer.isCompleted) completer.complete(null);
        }),
      );
    }
    final result = await completer.future;
    if (result != null && result.isNotEmpty) {
      _cache[host] = _CacheEntry(result, DateTime.now().add(_cacheTtl));
      cfLog('DoH 解析 $host -> $result');
    }
    return result;
  }

  static Future<List<String>?> _query(
      String endpoint, String accept, String host, Duration timeout) async {
    final client = HttpClient()..connectionTimeout = timeout;
    try {
      final uri = Uri.parse(
          '$endpoint?name=${Uri.encodeQueryComponent(host)}&type=A');
      final req = await client.getUrl(uri).timeout(timeout);
      req.headers.set(HttpHeaders.acceptHeader, accept);
      final resp = await req.close().timeout(timeout);
      if (resp.statusCode != 200) return null;
      final body = await resp.transform(utf8.decoder).join().timeout(timeout);
      final data = json.decode(body) as Map<String, dynamic>;
      if (data['Status'] != 0) return null;
      final answer = (data['Answer'] as List?) ?? const [];
      final ips = answer
          .whereType<Map>()
          .where((e) => e['type'] == 1)
          .map((e) => e['data'])
          .whereType<String>()
          .where((ip) => InternetAddress.tryParse(ip) != null)
          .toList();
      return ips.isEmpty ? null : ips;
    } finally {
      client.close(force: true);
    }
  }

  /// 解析为 [InternetAddress]（供直连用）。系统 DNS 优先（多数设备正常且快），
  /// 失败回退 DoH。两者都失败抛 [SocketException]。
  static Future<List<InternetAddress>> lookupAddresses(String host,
      {Duration timeout = const Duration(seconds: 4)}) async {
    try {
      final addrs = await InternetAddress.lookup(host)
          .timeout(const Duration(seconds: 3));
      if (addrs.isNotEmpty) return addrs;
    } catch (_) {}
    final ips = await lookup(host, timeout: timeout);
    if (ips == null || ips.isEmpty) {
      throw SocketException('系统 DNS 与 DoH 均解析失败: $host');
    }
    return [InternetAddress(ips.first)];
  }
}

class _CacheEntry {
  final List<String> ips;
  final DateTime expiresAt;
  const _CacheEntry(this.ips, this.expiresAt);
}
