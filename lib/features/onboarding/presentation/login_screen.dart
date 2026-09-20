import 'package:flutter/material.dart';

class LoginScreen extends StatelessWidget {
  const LoginScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      key: Key('login_screen'),
      body: Center(child: Text('Login')),
    );
  }
}
