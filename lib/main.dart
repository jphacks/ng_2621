import 'package:flutter/material.dart';

import 'features/zoo/presentation/zoo_screen.dart';

void main() {
  runApp(const ZooStudyApp());
}

class ZooStudyApp extends StatelessWidget {
  const ZooStudyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(title: 'ZooっとStudy', home: ZooScreen());
  }
}
