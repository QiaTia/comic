import 'dart:convert';

import 'package:get/get.dart';
import 'package:get/get_connect/connect.dart';
import 'package:get/get_connect/http/src/request/request.dart';

import 'cloudflare.dart';
import 'cloudflare_solver.dart';
import 'cloudflare_bridge.dart';
import 'local_proxy.dart';

/// 当前主站根地址。目标域名运行时可切换（[TargetHostResolver]，
/// 该站域名轮换频繁），因此不能是编译期常量。
String serverApiUrl() => 'https://${TargetHostResolver.host}/';

/// 通用请求头：referer 指向当前主站 + 浏览器 UA。
Map<String, String> _commonHeaders() => {
      'referer': serverApiUrl(),
      'user-agent': kBrowserUserAgent,
    };

/// 当前应使用的 UA：优先用导入 cf_clearance 时同步的浏览器 UA
/// （clearance 与 UA 绑定，重放需一致），否则用默认 UA。
String currentUserAgent() => CloudflareCookieJar.instance
        .userAgentFor(TargetHostResolver.host) ??
    kBrowserUserAgent;

/// 图片请求头：附加该 host 已保存的 Cloudflare cookie
/// （主要是 HttpOnly 的 cf_clearance）。否则同域图片请求会被 Cloudflare 拦（403），
/// 导致列表/详情页图片全部空白。
/// 注：当前站点图片在独立 CDN（hotlinkprotect.com，无 Cloudflare），
/// cookie 只是兼容性兜底。
Map<String, String> imageHeadersFor(String url) {
  final headers = _commonHeaders();
  headers['user-agent'] = currentUserAgent();
  final uri = Uri.tryParse(url);
  if (uri != null) {
    final cookie = CloudflareCookieJar.instance.cookieHeaderFor(uri);
    if (cookie != null) headers['cookie'] = cookie;
  }
  return headers;
}

class RequestOptions {
  final Map<String, String> params;

  RequestOptions({required this.params});
}

class _HttpService extends GetConnect {
  @override
  _HttpService onInit() {
    // 本地 CONNECT 代理：修复 realme/OPPO 等 ROM 的 HTTPDNS 劫持导致 App 内
    // 域名解析失败（Failed host lookup）。代理内系统 DNS 优先、DoH 兜底。
    // 必须在【首次访问 httpClient】之前设置：getter 懒构造 GetHttpClient 时
    // 才会读取 findProxy，之后设置不生效。
    findProxy = (url) {
      final p = CfLocalProxy.port;
      if (p == null) return 'DIRECT';
      final h = url.host;
      if (h == 'localhost' || h == '127.0.0.1') return 'DIRECT';
      return 'PROXY 127.0.0.1:$p';
    };
    httpClient.baseUrl = serverApiUrl();
    // 防止某些网络环境下 Dart HTTP 请求无限挂起（TLS/连通性），便于定位“没数据”
    httpClient.timeout = const Duration(seconds: 20);
    // 请求拦截：注入通用头（UA 用导入旁路同步的，与 cf_clearance 签发浏览器一致）
    httpClient.addRequestModifier<void>((request) {
      _commonHeaders().forEach((key, value) {
        request.headers[key] = value;
      });
      request.headers['user-agent'] = currentUserAgent();
      return request;
    });

    // 响应拦截
    httpClient.addResponseModifier(_responseHandler);
    super.onInit();
    return this;
  }

  bool _isExternalUrl(String url) {
    return RegExp(r"^https?://").hasMatch(url);
  }

  String completionUri(String url) {
    if (false == _isExternalUrl(url)) url = serverApiUrl() + url;
    url = url.replaceFirst('http://', 'https://');
    // 规范化路径中的连续斜杠（serverApiUrl() 末尾 '/' + 路径开头 '/' 会拼出 '//list-…'）。
    // 双斜杠路径会让 Cloudflare 挑战页脚本把 pathname 解析成【协议相对 URL】
    // （文件名被当成主机名），触发 replaceState SecurityError，
    // 导致 WebView 内人机验证永远无法自动通过——这是真机排查确认过的实际根因。
    final uri = Uri.tryParse(url);
    if (uri != null && uri.path.contains('//')) {
      return uri
          .replace(path: uri.path.replaceAll(RegExp(r'/+'), '/'))
          .toString();
    }
    return url;
  }

  Uri _parseUrl(String url, RequestOptions? options) {
    Uri result = Uri.parse(completionUri(url));
    if (options != null) {
      result = result.replace(queryParameters: options.params);
    }
    return result;
  }

  /// 响应拦截：解析 body，并在遇到 Cloudflare 挑战页时不抛出（交给 _withCloudflare 处理）。
  Response<dynamic> _responseHandler(
      Request<Object?> request, Response response) {
    dynamic body;
    if ((response.headers!['content-type'] ?? '').contains('json')) {
      try {
        body = json.decode(response.body);
      } catch (e) {
        body = response.body;
      }
    } else {
      body = response.body;
    }

    if (response.statusCode == 200 || response.statusCode == 201) {
      return response.copyWith(body: body);
    }

    // Cloudflare 挑战页：保留响应，由请求层决定是否唤起 WebView 验证
    if (CloudflareDetector.isChallenge(response)) {
      return response.copyWith(body: body);
    }

    throw Exception(body);
  }

  /// 合并已保存的 Cloudflare cookie 到请求头。
  Map<String, String> _withCookies(
      Uri uri, Map<String, String>? headers) {
    final merged = <String, String>{...?headers};
    final cookie = CloudflareCookieJar.instance.cookieHeaderFor(uri);
    if (cookie != null) merged['cookie'] = cookie;
    return merged;
  }

  /// 请求统一入口：检测 Cloudflare 挑战 -> 唤起 WebView 验证 -> 注入 cookie 重试。
  Future<Response<T>> _withCloudflare<T>(
    String method,
    String url, {
    Map<String, String>? headers,
    String? contentType,
    Decoder<T>? decoder,
    Map<String, dynamic>? query,
    dynamic body,
    Progress? uploadProgress,
  }) async {
    final uri = Uri.parse(completionUri(url));
    final requestHeaders = _withCookies(uri, headers);
    // 目标域名可能已轮换，同步 baseUrl（GetConnect 相对路径拼接用）
    httpClient.baseUrl = serverApiUrl();
    cfLog('>>> _withCloudflare 入口 $method $uri (ua=${currentUserAgent().length}字符)');

    // 主路径：Dart 直连（本地代理 + DoH 兜底 DNS）。
    // 已验证过的情况下带 cf_clearance + WebView UA（验证成功时已同步到
    // CookieJar），多数保护级别下 clearance 只校验 cookie + IP + UA，
    // Dart 的 TLS 指纹不同不必然被拒——值得先试，成功则零 WebView 开销。
    Response<T> resp;
    try {
      if (method == 'GET') {
        resp = await super.get<T>(url,
            headers: requestHeaders,
            query: query,
            contentType: contentType,
            decoder: decoder);
      } else {
        resp = await super.post<T>(url, body,
            headers: requestHeaders,
            query: query,
            contentType: contentType,
            decoder: decoder,
            uploadProgress: uploadProgress);
      }
    } catch (e) {
      // Dart 请求在拿到响应前就抛异常（网络/TLS/DNS 等），响应拦截器不会运行，
      // 因此不会走 Cloudflare 检测。打印出来以便定位“页面没数据”的真正原因。
      cfLog('请求异常 ($method $uri): $e');
      rethrow;
    }
    cfLog('请求完成 ($method $uri) status=${resp.statusCode}, '
        'server=${resp.headers?['server']}, cf-mitigated=${resp.headers?['cf-mitigated']}');
    // status=null 表示 GetConnect 内部吞了异常（网络错误或响应拦截器 throw），
    // 真实错误信息在 statusText 里——必须打出来才能定位。
    if (resp.statusCode == null) {
      cfLog('请求被吞掉的真实错误: ${resp.statusText}');
    }

    if (!CloudflareDetector.isChallenge(resp)) return resp;
    cfLog('检测到挑战页，唤起 WebView 验证 (${uri.host})');

    // 唤起 WebView 让用户手动完成验证
    final result = await CloudflareSolver.solve(uri);
    if (result == null) {
      cfLog('solve 返回 null（冷却/取消）');
      throw CloudflareVerificationCancelledException();
    }
    // 保存可读/HttpOnly cookie（含 WebView 抓到的 cf_clearance），供后续 Dart 请求复用
    // （bridge 验证成功时已存过一次，这里幂等合并）
    CloudflareCookieJar.instance.store(uri, result.cookies);
    cfLog('已存储 cookie，含 cf_clearance=${result.cookies.containsKey('cf_clearance')}');

    // 路径 A：触发验证的那条请求，验证通过后 WebView 已重定向到目标 URL，
    // 其渲染 DOM 就是这条请求要的数据，直接用（免一次往返）。
    if (result.html != null &&
        result.html!.isNotEmpty &&
        !CloudflareDetector.isHtmlChallengeString(result.html!)) {
      cfLog('html 路径成功，返回真实数据 (len=${result.html!.length})');
      return Response<T>(
        statusCode: 200,
        body: result.html as T,
        bodyString: result.html,
      );
    }

    // 路径 B（关键）：Dart 带 cf_clearance + WebView UA 重放（cookie 重试）。
    // 验证成功时 cookie 与 UA 已同步（UA 不匹配是之前重放必被拒的主因）。
    final retryHeaders = _withCookies(uri, headers);
    cfLog('Dart cookie 重试，含cookie=${retryHeaders.containsKey('cookie')}, '
        'cookie长度=${retryHeaders['cookie']?.length ?? 0}');
    if (method == 'GET') {
      resp = await super.get<T>(url,
          headers: retryHeaders,
          query: query,
          contentType: contentType,
          decoder: decoder);
    } else {
      resp = await super.post<T>(url, body,
          headers: retryHeaders,
          query: query,
          contentType: contentType,
          decoder: decoder,
          uploadProgress: uploadProgress);
    }
    cfLog('cookie 重试返回 status=${resp.statusCode}, '
        'isChallenge=${CloudflareDetector.isChallenge(resp)}, '
        'bodyLen=${(resp.body is String) ? (resp.body as String).length : 'n/a'}');
    if (!CloudflareDetector.isChallenge(resp)) return resp;

    // 路径 C（降级）：Dart 重放仍被挑战（该站查 TLS 指纹）→ 经已验证的
    // 常驻 WebView 导航取数（导航请求不会被该站 WAF 挑战）。
    final bridgedUrl = completionUri(url);
    cfLog('Dart 重放被挑战，走 WebView 桥接取数: $bridgedUrl');
    final bridgedHtml = await CloudflareBridge.instance.fetchHtml(bridgedUrl);
    if (bridgedHtml != null &&
        bridgedHtml.isNotEmpty &&
        !CloudflareDetector.isHtmlChallengeString(bridgedHtml)) {
      cfLog('桥接取数成功 (len=${bridgedHtml.length})');
      return Response<T>(
        statusCode: 200,
        body: bridgedHtml as T,
        bodyString: bridgedHtml,
      );
    }

    // 全部失败：标记失败防止对每个请求重复弹 WebView 循环。
    CloudflareSolver.markFailed(uri.host);
    Get.snackbar(
      'Cloudflare 验证失败',
      '请在「设置 → 导入 cf_clearance」从浏览器复制 cookie 绕过',
      duration: const Duration(seconds: 5),
    );
    throw CloudflareVerificationFailedException();
  }

  @override
  Future<Response<T>> get<T>(String url,
      {Map<String, String>? headers,
      String? contentType,
      Decoder<T>? decoder,
      Map<String, dynamic>? query}) {
    return _withCloudflare<T>('GET', url,
        headers: headers,
        contentType: contentType,
        decoder: decoder,
        query: query);
  }

  @override
  Future<Response<T>> post<T>(String? url, dynamic body,
      {Map<String, String>? headers,
      String? contentType,
      Decoder<T>? decoder,
      Map<String, dynamic>? query,
      Progress? uploadProgress}) {
    return _withCloudflare<T>('POST', url ?? '',
        body: body,
        headers: headers,
        contentType: contentType,
        decoder: decoder,
        query: query,
        uploadProgress: uploadProgress);
  }
}

final _HttpService httpService = _HttpService().onInit();
