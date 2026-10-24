import 'package:flutter/material.dart';

import 'features/auth/presentation/role_selection_screen.dart';
import 'features/study/demo_assignment_store.dart';
import 'features/game/domain/game_repository.dart';
import 'features/zoo/presentation/zoo_screen.dart';

void main() {
  runApp(const ZooStudyApp());
}

class ZooStudyApp extends StatefulWidget {
  const ZooStudyApp({super.key, this.gameRepository});

  final GameRepository? gameRepository;

  @override
  State<ZooStudyApp> createState() => _ZooStudyAppState();
}

class _ZooStudyAppState extends State<ZooStudyApp> {
  final _assignments = DemoAssignmentStore();

  @override
  void dispose() {
    _assignments.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ZooっとStudy',
      home: RoleSelectionScreen(
        teacherPageBuilder: (_) => ZooScreen(
          gameRepository: widget.gameRepository,
          isTeacher: true,
          assignmentStore: _assignments,
        ),
        studentPageBuilder: (_) => ZooScreen(
          gameRepository: widget.gameRepository,
          assignmentStore: _assignments,
        ),
      ),
    );
  }
}
