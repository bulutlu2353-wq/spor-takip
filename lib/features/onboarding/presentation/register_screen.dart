import 'package:flutter/material.dart';

class RegisterScreen extends StatelessWidget {
  const RegisterScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      key: Key('register_screen'),
      body: Center(child: Text('Register')),
    );
  }
}
