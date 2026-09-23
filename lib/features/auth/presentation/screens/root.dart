import 'package:carcare_service/features/controllers.dart';
import 'package:carcare_service/features/auth/presentation/screens/login_screen.dart';
import 'package:carcare_service/features/shell/presentation/screens/index.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class RootPage extends StatefulWidget {
  const RootPage({super.key});

  @override
  State<RootPage> createState() => _RootPageState();
}

class _RootPageState extends State<RootPage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => initer());
  }

  Future<void> initer() async {
    final pro = context.read<AuthController>();
    await pro.loadUser();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AuthController>(
      builder: (context, value, child) {
        if (value.authState == AuthState.authorized) {
          return IndexScreen();
        }
        return LoginScreen();
      },
    );
  }
}
