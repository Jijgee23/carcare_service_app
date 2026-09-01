import 'dart:async';

import 'package:flutter/material.dart';

mixin SearchDebounceMixin<T extends StatefulWidget> on State<T> {
  Timer? _debounce;

  void onSearchChanged(String value, void Function(String) callback) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () => callback(value));
  }

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }
}
