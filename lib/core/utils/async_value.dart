import 'package:carcare_service/core/error/app_error.dart';

sealed class AsyncValue<T> {
  const AsyncValue();
  T? get valueOrNull => switch (this) {
    AsyncData(:final value) => value,
    _ => null,
  };
}

final class AsyncLoading<T> extends AsyncValue<T> {
  const AsyncLoading();
}

final class AsyncData<T> extends AsyncValue<T> {
  final T value;
  const AsyncData(this.value);
}

final class AsyncError<T> extends AsyncValue<T> {
  final AppError error;
  const AsyncError(this.error);
}
