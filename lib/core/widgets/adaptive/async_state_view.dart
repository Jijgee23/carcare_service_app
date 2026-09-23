import 'package:flutter/material.dart';

import '../../errors/app_error.dart';
import '../../utils/async_value.dart';

/// Standard read-state rendering. A stale result remains visible while its
/// refresh is in flight; it is never confused with an empty result.
class AsyncStateView<T> extends StatelessWidget {
  const AsyncStateView({
    super.key,
    required this.state,
    required this.builder,
    this.isEmpty,
    this.empty,
    this.loading,
    this.error,
    this.onRetry,
    this.stale = false,
    this.staleLabel = 'Шинэчлэгдээгүй мэдээлэл',
  });
  final AsyncValue<T> state;
  final Widget Function(BuildContext context, T value) builder;
  final bool Function(T value)? isEmpty;
  final Widget? empty;
  final Widget? loading;
  final Widget Function(BuildContext, AppError)? error;
  final VoidCallback? onRetry;
  final bool stale;
  final String staleLabel;

  @override
  Widget build(BuildContext context) {
    final child = switch (state) {
      AsyncLoading() =>
        loading ?? const Center(child: CircularProgressIndicator()),
      AsyncError(:final error) =>
        this.error?.call(context, error) ?? _errorView(context, error),
      AsyncData(:final value) when isEmpty?.call(value) ?? false =>
        empty ?? const Center(child: Text('Мэдээлэл алга')),
      AsyncData(:final value) => builder(context, value),
    };
    if (!stale || state is! AsyncData<T>) return child;
    return Stack(
      children: [
        child,
        Positioned(
          top: 8,
          left: 8,
          right: 8,
          child: Align(
            alignment: Alignment.topCenter,
            child: Chip(
              avatar: const Icon(Icons.sync_problem_rounded, size: 16),
              label: Text(staleLabel),
            ),
          ),
        ),
      ],
    );
  }

  Widget _errorView(BuildContext context, AppError? value) => Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.cloud_off_rounded, size: 48),
        const SizedBox(height: 12),
        Text(
          value?.message ?? 'Мэдээлэл ачаалж чадсангүй',
          textAlign: TextAlign.center,
        ),
        if (onRetry != null) ...[
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('Дахин оролдох'),
          ),
        ],
      ],
    ),
  );
}
