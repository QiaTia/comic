import 'package:http/http.dart' as http;
import 'dart:convert';

const _api_host = 'https://xn--ej1-mxgmxgcom-yp8ve33bkpevz1kpxq.mxgmxgcom.com/';

final Map<String, String> imageHeader = {
  'referer': _api_host,
  'user-agent':
      'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/109.0.0.0 Safari/537.36 Edg/109.0.1518.78',
};

class RequestOptions {
  final Map<String, String> params;

  RequestOptions({required this.params});
}

class _HttpService {
  bool _isExternalUrl(String url) {
    final RegExp regExp = RegExp(r"^https?://");

    if (regExp.hasMatch(url)) {
      return true;
    }

    return false;
  }

  String completionUri(String url) {
    if (false == _isExternalUrl(url)) url = _api_host + url;
    return url.replaceFirst('http://', 'https://');
  }

  Uri _parseUrl(String url, RequestOptions? options) {
    Uri result = Uri.parse(completionUri(url));
    if (options != null) {
      result = result.replace(queryParameters: options.params);
    }

    return result;
  }

  Map<String, String> _parseHeader(String url, bool withContentType) {
    Map<String, String> header = {
      'user-agent': 'Mozilla/5.0 (Windows NT 6.1; Win64; x64) ' +
          'AppleWebKit/537.36 (KHTML, like Gecko) Chrome/70.0.3538.102 Safari/537.36',
    };

    if (withContentType == true) {
      header['Content-Type'] = 'application/json; charset=UTF-8';
    }

    if (_isExternalUrl(url) != true) {
      // TODO：读取本地缓存中的token
      header['token'] = 'xxx';
    }

    return header;
  }

  Map<String, dynamic> _responseHandler(http.Response response) {
    Map<String, dynamic> body;

    try {
      body = json.decode(response.body);
    } catch (e) {
      body = {'code': 'unknown', "data": response.body};
    }

    if (response.statusCode == 200 || response.statusCode == 201) {
      return body;
    } else {
      throw Exception(body);
    }
  }

  Future<Map<String, dynamic>> post(String url, Map<String, dynamic> data,
      [RequestOptions? options]) async {
    final http.Response response = await http.post(
      _parseUrl(url, options),
      headers: _parseHeader(url, true),
      body: jsonEncode(data),
    );

    return _responseHandler(response);
  }

  Future<Map<String, dynamic>> get(String url,
      [RequestOptions? options]) async {
    final http.Response response = await http.get(
      _parseUrl(url, options),
      headers: _parseHeader(url, false),
    );

    return _responseHandler(response);
  }
}

final _HttpService httpService = _HttpService();
