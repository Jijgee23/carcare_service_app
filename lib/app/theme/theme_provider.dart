import 'package:flutter/material.dart';

class ThemeProvider extends ChangeNotifier {
  ThemeMode mode = ThemeMode.light;
  bool get userChoosedSystem => mode == ThemeMode.system;
  void toggleTheme() {
    if (mode == ThemeMode.dark) {
      mode = ThemeMode.light;
      notifyListeners();
    }
    mode = ThemeMode.dark;
    notifyListeners();
  }
}
