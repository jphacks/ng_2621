import 'package:flutter/material.dart';

import 'features/game/domain/game_repository.dart';
import 'features/zoo/presentation/zoo_screen.dart';

void main() {
  runApp(const ZooStudyApp());
}

class ZooStudyApp extends StatelessWidget {
  const ZooStudyApp({super.key, this.gameRepository});

  final GameRepository? gameRepository;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ZooっとStudy',
      home: ZooScreen(gameRepository: gameRepository),
    );
  }
}
