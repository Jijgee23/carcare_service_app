import 'package:flutter/material.dart';

mixin LoadingMixin<T extends StatefulWidget> on State<T> {
  bool isLoading = false;
  bool isSubmitting = false;

  Future<void> withLoading(Future<void> Function() fn) async {
    if (isLoading) return;
    setState(() => isLoading = true);
    try {
      await fn();
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  Future<R?> withSubmit<R>(Future<R?> Function() fn) async {
    if (isSubmitting) return null;
    setState(() => isSubmitting = true);
    try {
      return await fn();
    } finally {
      if (mounted) setState(() => isSubmitting = false);
    }
  }
}
