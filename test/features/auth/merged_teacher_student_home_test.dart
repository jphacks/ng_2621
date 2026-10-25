import 'package:zoo_study/features/zoo/presentation/zoo_navigation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zoo_study/features/auth/data/school_account_api.dart';
import 'package:zoo_study/features/study/demo_assignment_store.dart';
import 'package:zoo_study/features/zoo/presentation/teacher_class_home.dart';
import 'package:zoo_study/features/zoo/presentation/zoo_chrome.dart';
import 'package:zoo_study/features/zoo/presentation/zoo_screen.dart';
import 'package:zoo_study/features/zoo/presentation/zoo_viewport.dart';

import '../study/memory_storage.dart';

void main() {
  testWidgets(
    'merged teacher shell retains class home, class header and class assignment destination',
    (tester) async {
      final storage = MemoryStorage();
      final api = LocalSchoolAccountApi(storage);
      final store = DemoAssignmentStore();
      addTearDown(store.dispose);
      await api.call('createManagedClass', {'name': 'ひまわり組'});
      await tester.runAsync(() async {
        await tester.pumpWidget(
          MaterialApp(
            home: ZooScreen(
              isTeacher: true,
              schoolAccountApi: api,
              schoolStorage: storage,
              gameRepository: store,
              assignmentStore: store,
              teacherAssignmentsBuilder: (_) =>
                  const Scaffold(body: Text('既存のクラス別課題画面')),
            ),
          ),
        );
        await Future<void>.delayed(Duration.zero);
      });
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.byType(TeacherClassHome), findsOneWidget);
      expect(find.byType(TeacherZooHeader), findsOneWidget);
      expect(find.byType(ZooHomeTabs), findsNothing);
      expect(find.text('ひまわり組の動物園'), findsOneWidget);
      expect(
        tester.widget<ZooViewport>(find.byType(ZooViewport)).showAnimalList,
        isFalse,
      );
      await tester.tap(find.byKey(const ValueKey('main-tab-study')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.text('既存のクラス別課題画面'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
}
