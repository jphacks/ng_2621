import 'package:flutter/material.dart';

class RoleHomeScreen extends StatelessWidget {
  const RoleHomeScreen({super.key, required this.isTeacher});

  final bool isTeacher;

  @override
  Widget build(BuildContext context) {
    final role = isTeacher ? '先生' : '生徒';
    return Scaffold(
      appBar: AppBar(title: Text('$roleのページ')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            '$roleのページは準備中です',
            style: Theme.of(context).textTheme.titleLarge,
            textAlign: TextAlign.center,
          ),
        ),
      ),
    );
  }
}
