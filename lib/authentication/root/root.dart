import 'package:carcare_service/app/app.dart';
import 'package:carcare_service/authentication/auth_provider.dart';
import 'package:carcare_service/authentication/login/login_screen.dart';
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
    final pro = context.read<AuthProvider>();
    await pro.loadUser();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AuthProvider>(
      builder: (context, value, child) {
        if (value.authState == AuthState.authorized) {
          return IndexScreen();
        }
        return LoginScreen();
      },
    );
  }
}
