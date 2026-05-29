import 'package:carcare_service/authentication/auth_provider.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  @override
  Widget build(BuildContext context) {
    return Consumer<AuthProvider>(
      builder: (context, auth, child) {
        return Material(
          color: Colors.blueGrey,
          child: Container(
            padding: EdgeInsets.all(16),
            child: SafeArea(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                spacing: 14,
                children: [
                  Text('carCare.mn', style: TextStyle(color: Colors.black)),
                  XField(hint: 'Имейл', controller: auth.emailControler),
                  XField(hint: 'Нууц үг', controller: auth.passwordControler),
                  Align(
                    alignment: Alignment.centerRight,
                    child: GestureDetector(onTap: () {}, child: Text('Нууц үг мартсан?')),
                  ),
                  XButton(label: 'Нэвтрэх', handler: () => auth.login()),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class XField extends StatelessWidget {
  final String hint;
  final TextEditingController? controller;
  const XField({super.key, required this.hint, this.controller});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey),
      ),
      padding: EdgeInsets.symmetric(vertical: 12, horizontal: 14),
      child: TextFormField(
        controller: controller,
        decoration: InputDecoration.collapsed(hintText: hint),
      ),
    );
  }
}

class XButton extends StatelessWidget {
  final String label;
  final void Function() handler;
  const XButton({super.key, required this.label, required this.handler});

  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      style: ElevatedButton.styleFrom(
        minimumSize: Size(double.maxFinite, 48),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        backgroundColor: Colors.redAccent,
      ),
      onPressed: handler,
      child: Text(label, style: TextStyle(color: Colors.white)),
    );
  }
}
