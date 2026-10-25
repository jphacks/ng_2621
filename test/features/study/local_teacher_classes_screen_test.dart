import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zoo_study/core/storage/attachments/attachment_vault.dart';
import 'package:zoo_study/features/auth/data/school_account_api.dart';
import 'package:zoo_study/features/study/demo_assignment_store.dart';
import 'package:zoo_study/features/study/local_teacher_classes_screen.dart';
import 'package:zoo_study/features/study/local_class_study_repository.dart';

import 'memory_storage.dart';

void main() {
  testWidgets(
    'teacher chooses target class and delivers older assignments explicitly',
    (tester) async {
      final disk = MemoryStorage(),
          api = LocalSchoolAccountApi(MemoryStorage());
      final vault = MemoryAttachmentVault();
      final first =
          (await api.call('createManagedClass', {'name': 'ひまわり組'}))['classId']
              as String;
      final second =
          (await api.call('createManagedClass', {'name': 'さくら組'}))['classId']
              as String;
      final legacy = DemoAssignmentStore();
      legacy.publish(
        DemoAssignment(
          id: 'old',
          subject: AssignmentSubject.japanese,
          title: '以前の課題',
          description: '音読',
          dueAt: DateTime(2030),
        ),
      );
      await tester.pumpWidget(
        MaterialApp(
          home: LocalTeacherClassesScreen(
            api: api,
            storage: disk,
            legacyStore: legacy,
            attachmentVaultFactory: () async => vault,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('課題・学習記録の対象クラス'), findsOneWidget);
      await tester.tap(find.byType(DropdownButtonFormField<String>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('さくら組').last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('以前の課題をこのクラスに配布'));
      await tester.pumpAndSettle();
      expect(find.text('以前の課題'), findsOneWidget);
      final a = await LocalClassStudyRepository.open(
        storage: disk,
        api: api,
        classId: first,
        vault: vault,
      );
      final b = await LocalClassStudyRepository.open(
        storage: disk,
        api: api,
        classId: second,
        vault: vault,
      );
      expect(a.assignments, isEmpty);
      expect(b.assignments.single.title, '以前の課題');
      a.dispose();
      b.dispose();
      await tester.pumpWidget(const SizedBox());
      legacy.dispose();
    },
  );
}
