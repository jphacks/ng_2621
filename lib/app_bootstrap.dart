import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app.dart';
import 'core/storage/draft_storage.dart';
import 'features/auth/data/firebase_configuration.dart';
import 'features/auth/presentation/firebase_login_screen.dart';
import 'features/auth/presentation/role_selection_screen.dart';
import 'features/study/demo_assignment_store.dart';

class AppBootstrap extends StatefulWidget {
  const AppBootstrap({super.key});
  @override
  State<AppBootstrap> createState() => _AppBootstrapState();
}

class _AppBootstrapState extends State<AppBootstrap> {
  late Future<Widget> _startup = _prepare();
  Future<Widget> _prepare() async {
    if (studyStorageMode == 'local') {
      if (!kDebugMode) {
        throw StateError('端末内デモはデバッグ実行専用です。配布版にはFirebase接続設定が必要です。');
      }
      final preferences = await SharedPreferences.getInstance();
      final repository = await DemoAssignmentStore.open(
        PreferencesDraftStorage(preferences, 'local-demo'),
      );
      return ZooStudyApp(studyRepository: repository);
    }
    if (!['firebase', 'emulator'].contains(studyStorageMode)) {
      throw StateError('保存モードが無効です');
    }
    await initializeStudyFirebase();
    return MaterialApp(
      title: 'ZooっとStudy',
      home: RoleSelectionScreen(
        storageDescription: studyStorageMode == 'emulator'
            ? 'Firebaseエミュレーターに接続します'
            : 'Firebaseでデータを共有します',
        teacherPageBuilder: (_) => FirebaseLoginScreen(
          isTeacher: true,
          emulator: studyStorageMode == 'emulator',
        ),
        studentPageBuilder: (_) => FirebaseLoginScreen(
          isTeacher: false,
          emulator: studyStorageMode == 'emulator',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<Widget>(
    future: _startup,
    builder: (context, snapshot) {
      if (snapshot.hasData) return snapshot.data!;
      return MaterialApp(
        home: Scaffold(
          body: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: snapshot.hasError
                  ? Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text('保存先を開けませんでした'),
                        Text('${snapshot.error}'),
                        FilledButton(
                          onPressed: () =>
                              setState(() => _startup = _prepare()),
                          child: const Text('再試行'),
                        ),
                      ],
                    )
                  : const CircularProgressIndicator(),
            ),
          ),
        ),
      );
    },
  );
}
