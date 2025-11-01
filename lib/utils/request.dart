import 'dart:convert';
import 'package:get/get_connect/connect.dart';
import 'package:get/get_connect/http/src/request/request.dart';

const SERVER_API_URL = 'https://xn--ej1-mxgmxgcom-yp8ve33bkpevz1kpxq.mxgmxgcom.com/';

final Map<String, String> imageHeader = {
  'referer': SERVER_API_URL,
  'user-agent': 'Mozilla/5.0 (Windows NT 6.1; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/70.0.3538.102 Safari/537.36',
    
};

class RequestOptions {
  final Map<String, String> params;

  RequestOptions({required this.params});
}

class _HttpService extends GetConnect {
  @override
  _HttpService onInit() {
    httpClient.baseUrl = SERVER_API_URL;
    // 请求拦截
    httpClient.addRequestModifier<void>((request) {
      imageHeader.forEach((key, value) {
        request.headers[key] = value;
      });
      return request;
    });

    // httpClient.addAuthenticator<dynamic>((Request request) async {
    //   // Set the header
    //   request.headers['token'] =
    //       '6e9c9ba1f56d406fb35926475906f9215f0a099abae929eb041cb59900de955a';
    //   return request;
    // });

    // 响应拦截
    httpClient.addResponseModifier(_responseHandler);
    super.onInit();
    return this;
  }

  bool _isExternalUrl(String url) {
    final RegExp regExp = RegExp(r"^https?://");

    if (regExp.hasMatch(url)) {
      return true;
    }

    return false;
  }

  String completionUri(String url) {
    if (false == _isExternalUrl(url)) url = SERVER_API_URL + url;
    return url.replaceFirst('http://', 'https://');
  }

  Uri _parseUrl(String url, RequestOptions? options) {
    Uri result = Uri.parse(completionUri(url));
    if (options != null) {
      result = result.replace(queryParameters: options.params);
    }

    return result;
  }

  Response<dynamic> _responseHandler(Request<Object?> request, Response response) {
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
    } else {
      throw Exception(body);
    }
  }
}

final _HttpService httpService = _HttpService().onInit();
