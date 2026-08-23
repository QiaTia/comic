import 'package:comic/utils/cloudflare.dart';

void main() {
  const cases = {
    '5wh备用域名-mxgmxg点com.mxgmxgcom.com':
        'xn--5wh-mxgmxgcom-yp8ve33bkpevz1kpxq.mxgmxgcom.com',
    '8uw备用域名-mxgmxg点com.mxgmh.com':
        'xn--8uw-mxgmxgcom-yp8ve33bkpevz1kpxq.mxgmh.com',
    'o79备用域名-mxgmxg点com.manxiange.com':
        'xn--o79-mxgmxgcom-yp8ve33bkpevz1kpxq.manxiange.com',
    'bücher': 'xn--bcher-kva',
    'example.com': 'example.com',
  };
  var failed = 0;
  cases.forEach((input, expected) {
    final got = punycodeEncodeHost(input);
    final ok = got == expected;
    if (!ok) failed++;
    print('${ok ? "PASS" : "FAIL"} $input => $got (expect $expected)');
  });
  if (failed > 0) throw Exception('$failed case(s) failed');
  print('ALL PASS');
}
