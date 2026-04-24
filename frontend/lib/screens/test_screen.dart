import 'package:flutter/material.dart';

class TestScreen extends StatelessWidget {
  const TestScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Тест ввода')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            TextField(decoration: InputDecoration(labelText: 'Логин')),
            const SizedBox(height: 16),
            TextField(decoration: InputDecoration(labelText: 'Пароль')),
          ],
        ),
      ),
    );
  }
}