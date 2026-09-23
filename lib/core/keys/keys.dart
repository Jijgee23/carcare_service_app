import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

class GlobalKeys {
  static final navigator = GlobalKey<NavigatorState>();
  static GoRouter? router;
}
