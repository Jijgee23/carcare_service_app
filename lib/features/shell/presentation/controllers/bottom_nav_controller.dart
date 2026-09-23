import 'package:flutter/material.dart';

class BottomNavController extends ChangeNotifier {
  final scaffoldKey = GlobalKey<ScaffoldState>();

  int _index = 0;
  int get index => _index;

  void setIndex(int i) {
    _index = i;
    notifyListeners();
    scaffoldKey.currentState?.closeDrawer();
  }

  void openMenu() => scaffoldKey.currentState?.openDrawer();
}
