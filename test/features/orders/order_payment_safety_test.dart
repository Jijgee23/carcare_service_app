import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';

import 'package:carcare_service/features/orders/presentation/screens/order_payment_screen.dart';

void main() {
  test(
    'QR decoder accepts data URIs and rejects malformed or empty values',
    () {
      expect(decodeQrImage(null), isNull);
      expect(decodeQrImage(''), isNull);
      expect(decodeQrImage('not-base64'), isNull);
      expect(decodeQrImage('data:image/png;base64,SGVsbG8='), isA<Uint8List>());
      expect(decodeQrImage('SGVsbG8='), isA<Uint8List>());
    },
  );

  test('bank URL validation allows HTTPS/custom schemes only', () {
    expect(isSafeBankUrl('https://bank.example/pay?id=1'), isTrue);
    for (final scheme in [
      'khanbank',
      'golomtbank',
      'tdbbank',
      'statebank',
      'monpay',
      'socialpay',
      'bogdbank',
      'mostmoney',
      'qpay',
    ]) {
      expect(isSafeBankUrl('$scheme://pay?id=1'), isTrue, reason: scheme);
    }
    for (final value in [
      'javascript:alert(1)',
      'data:text/html,hello',
      'file:///etc/passwd',
      'about:blank',
      'blob:https://example.test/id',
      'http://bank.example/pay',
      'evil://bank.example/pay',
      '/missing-scheme',
    ]) {
      expect(isSafeBankUrl(value), isFalse, reason: value);
    }
  });
}
