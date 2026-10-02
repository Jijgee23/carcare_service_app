import 'package:carservice_business/core/network/api_client.dart';

/// Серверийн харьцангуй `/uploads/...` замыг API-н origin-д залгаж бүтэн
/// URL болгоно. Бүтэн URL бол хэвээр буцаана.
String resolveMediaUrl(String url, {String? baseUrl}) {
  final parsed = Uri.tryParse(url);
  if (parsed != null && parsed.hasScheme) return url;
  final base = baseUrl ?? ApiService.instance.dio.options.baseUrl;
  final origin = Uri.parse(base).origin;
  return url.startsWith('/') ? '$origin$url' : '$origin/$url';
}
