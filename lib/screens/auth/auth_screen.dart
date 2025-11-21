import 'package:flutter/material.dart';

// Это заглушка. Вам нужно добавить реальную логику аутентификации.
class AuthScreen extends StatelessWidget {
  const AuthScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Аутентификация')),
      body: const Center(
        child: Text('Экран входа/регистрации'),
      ),
    );
  }
}