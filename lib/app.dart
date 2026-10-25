import 'features/auth/presentation/local_student_access_screen.dart';
import 'features/auth/data/school_account_api.dart';
import 'features/auth/presentation/school_management_screen.dart';
import 'core/ui/zoo_ui.dart';
import 'core/ui/zoo_font.dart';

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
    this.enableStudentCodes = false,
  });

  final GameRepository? gameRepository;
  final StudyRepository? studyRepository;
  final DraftStorage? roleStorage;
  final bool enableStudentCodes;

  @override
  State<ZooStudyApp> createState() => _ZooStudyAppState();
}

class _ZooStudyAppState extends State<ZooStudyApp> {
  int _sessionRevision = 0;
  void _switchUser() => setState(() => _sessionRevision++);
  late final _schoolAccounts = LocalSchoolAccountApi(widget.roleStorage);
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
      key: ValueKey(_sessionRevision),
      builder: (context, child) =>
          PixelUiTheme(child: child ?? const SizedBox.shrink()),
      theme: ThemeData(fontFamily: ZooFont.family),
      title: 'ZooっとStudy',
      home: SavedRoleGate(
        storage: widget.roleStorage,
        storageDescription: _assignments.storageLabel,
        teacherPageBuilder: (context) => ZooScreen(
          schoolAccountApi: _schoolAccounts,
          schoolStorage: widget.roleStorage,
          onManageAccounts: () async {
            await Navigator.of(context).push<void>(
              MaterialPageRoute(
                builder: (_) => SchoolManagementScreen(api: _schoolAccounts),
              ),
            );
          },
          gameRepository:
              widget.gameRepository ?? (kDebugMode ? _assignments : null),
          isTeacher: true,
          onSignOut: () async => _switchUser(),
          accountName: '先生',
          accountStorageDescription: '端末内モードです。この端末のデータを利用しています。',
          assignmentStore: kDebugMode ? _assignments : null,
        ),
        studentPageBuilder: (_) =>
            widget.enableStudentCodes && widget.roleStorage != null
            ? LocalStudentAccessScreen(
                api: _schoolAccounts,
                storage: widget.roleStorage!,
                onExit: _switchUser,
              )
            : ZooScreen(
                gameRepository:
                    widget.gameRepository ?? (kDebugMode ? _assignments : null),
                assignmentStore: kDebugMode ? _assignments : null,
              ),
      ),
    );
  }
}
