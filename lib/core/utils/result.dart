import 'package:carcare_service/core/errors/app_error.dart';

sealed class Result<T> {
  const Result();
  T? get valueOrNull => switch (this) {
    Ok(:final value) => value,
    Err() => null,
  };
}

final class Ok<T> extends Result<T> {
  final T value;
  const Ok(this.value);
}

final class Err<T> extends Result<T> {
  final AppError error;
  const Err(this.error);
}
