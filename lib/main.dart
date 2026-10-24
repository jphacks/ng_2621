import 'package:flutter/material.dart';

import 'features/auth/role_selection_screen.dart';

void main() {
  runApp(const ZooStudyApp());
}

class ZooStudyApp extends StatelessWidget {
  const ZooStudyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ZooっとStudy',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF39785A)),
        scaffoldBackgroundColor: const Color(0xFFF7F9F3),
      ),
      home: const RoleSelectionScreen(),
    );
  }
}
