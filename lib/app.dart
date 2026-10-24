import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'features/auth/presentation/saved_role_gate.dart';
import 'core/storage/draft_storage.dart';
import 'features/study/demo_assignment_store.dart';
import 'features/study/study_repository.dart';
import 'features/game/domain/game_repository.dart';
import 'features/zoo/presentation/zoo_screen.dart';

class ZooStudyApp extends StatefulWidget {
  const ZooStudyApp({
    super.key,
    this.gameRepository,
    this.studyRepository,
    this.roleStorage,
  });

  final GameRepository? gameRepository;
  final StudyRepository? studyRepository;
  final DraftStorage? roleStorage;

  @override
  State<ZooStudyApp> createState() => _ZooStudyAppState();
}

class _ZooStudyAppState extends State<ZooStudyApp> {
  late final StudyRepository _assignments =
      widget.studyRepository ?? DemoAssignmentStore();

  @override
  void dispose() {
    _assignments.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ZooっとStudy',
      home: SavedRoleGate(
        storage: widget.roleStorage,
        storageDescription: _assignments.storageLabel,
        teacherPageBuilder: (_) => ZooScreen(
          gameRepository:
              widget.gameRepository ?? (kDebugMode ? _assignments : null),
          isTeacher: true,
          assignmentStore: kDebugMode ? _assignments : null,
        ),
        studentPageBuilder: (_) => ZooScreen(
          gameRepository:
              widget.gameRepository ?? (kDebugMode ? _assignments : null),
          assignmentStore: kDebugMode ? _assignments : null,
        ),
      ),
    );
  }
}
