import 'package:flutter/material.dart';

void main() {
  runApp(const ZooStudyApp());
}

class ZooStudyApp extends StatelessWidget {
  const ZooStudyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      title: 'ZooっとStudy',
      home: Scaffold(body: Center(child: Text('ZooっとStudy'))),
    );
  }
}
