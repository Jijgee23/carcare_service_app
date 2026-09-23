enum ErrorKind { network, notFound, unauthorized, forbidden, server, unknown }

class AppError implements Exception {
  final ErrorKind kind;
  final String message;
  final int? statusCode;
  final String? code;
  final Map<String, String>? fieldErrors;

  const AppError(
    this.kind,
    this.message, {
    this.statusCode,
    this.code,
    this.fieldErrors,
  });

  String get display => switch (kind) {
    ErrorKind.network => 'Интернет холболт байхгүй',
    ErrorKind.notFound => 'Мэдээлэл олдсонгүй',
    ErrorKind.unauthorized => 'Нэвтрэх шаардлагатай',
    ErrorKind.forbidden => message,
    ErrorKind.server => 'Серверийн алдаа гарлаа',
    ErrorKind.unknown => message,
  };
}
