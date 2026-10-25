import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zoo_study/core/storage/attachments/attachment_vault.dart';
import 'package:zoo_study/features/auth/data/school_account_api.dart';
import 'package:zoo_study/features/auth/presentation/local_student_access_screen.dart';
import 'package:zoo_study/features/study/demo_assignment_store.dart';
import 'package:zoo_study/features/zoo/presentation/zoo_screen.dart';

import 'package:zoo_study/features/study/study_detector/study_record.dart';
import 'package:zoo_study/features/study/study_detector/study_session.dart';

import '../study/memory_storage.dart';

void main() {
  test('local code login identifies the registered student, restores class and rejects revoked codes', () async {
    final storage = MemoryStorage(),
        api = LocalSchoolAccountApi(MemoryStorage());
    final room = await api.call('createManagedClass', {'name': 'ひまわり組'});
    final first = await api.call('createManagedStudent', {
      'classId': room['classId'],
      'name': 'はなこ',
    });
    final login = await api.call('loginWithStudentCode', {
      'code': first['loginCode'],
    });
    expect(login['student']['name'], 'はなこ');
    expect(login['student']['className'], 'ひまわり組');
    final restored = await api.call('restoreStudentSession', {
      'studentId': first['studentId'],
    });
    expect(restored['student']['className'], 'ひまわり組');
    await api.call('reissueStudentCode', {
      'classId': room['classId'],
      'studentId': first['studentId'],
    });
    await expectLater(
      api.call('loginWithStudentCode', {'code': first['loginCode']}),
      throwsA(isA<StudyFailure>()),
    );
    final a = await DemoAssignmentStore.open(
      StudentAccountStorage(storage, 'student_a'),
      studentId: 'student_a',
      studentName: 'はなこ',
    );
    a.publish(
      DemoAssignment(
        title: '算数',
        description: '復習',
        subject: AssignmentSubject.mathematics,
        dueAt: DateTime.now(),
      ),
    );
    a.submit(a.assignments.single.id, '回答', role: DemoStudyRole.student);
    await a.flush();
    await a.saveStudyRecord(
      StudyRecord(
        id: 'own-record',
        startedAt: DateTime.now().subtract(const Duration(minutes: 1)),
        mode: StudyMode.desk,
        elapsedMs: 60000,
        stateMs: {
          for (final state in StudyState.values)
            state.name: state == StudyState.material ? 60000 : 0,
        },
        samples: 20,
        subject: '算数',
        completed: true,
      ),
    );
    expect((await a.loadStudyRecords()).single.studentName, 'はなこ');
    expect(a.snapshot.studentId, 'student_a');
    expect(a.submissionsFor(a.assignments.single.id).single.studentName, 'はなこ');
    final b = await DemoAssignmentStore.open(
      StudentAccountStorage(storage, 'student_b'),
      studentId: 'student_b',
      studentName: 'たろう',
    );
    expect(b.coins, 0);
    expect(b.assignments, isEmpty);
    expect(await b.loadStudyRecords(), isEmpty);
    final again = await DemoAssignmentStore.open(
      StudentAccountStorage(storage, 'student_a'),
      studentId: 'student_a',
      studentName: 'はなこ',
    );
    expect(again.coins, 30);
    expect(
      again.submissionsFor(again.assignments.single.id).single.studentId,
      'student_a',
    );
    a.dispose();
    b.dispose();
    again.dispose();
  });
  testWidgets(
    'code entry opens the named student account and remembers its identity',
    (tester) async {
      final storage = MemoryStorage(),
          api = LocalSchoolAccountApi(MemoryStorage());
      final room = await api.call('createManagedClass', {'name': 'ひまわり組'});
      final issued = await api.call('createManagedStudent', {
        'classId': room['classId'],
        'name': 'はなこ',
      });
      await tester.pumpWidget(
        MaterialApp(
          home: LocalStudentAccessScreen(
            api: api,
            storage: storage,
            attachmentVaultFactory: () async => MemoryAttachmentVault(),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const ValueKey('student-login-code')),
        issued['loginCode'] as String,
      );
      await tester.tap(find.text('このコードで はじめる'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      final screen = tester.widget<ZooScreen>(find.byType(ZooScreen));
      expect(screen.accountName, 'はなこ');
      expect(screen.accountClassName, 'ひまわり組');
      expect(
        (await storage.read('student-session'))!['studentId'],
        issued['studentId'],
      );
      expect(find.text('ゲスト'), findsNothing);
      await screen.onSignOut!();
      await tester.pump();
      expect(await storage.read('student-session'), isNull);
      expect(find.byKey(const ValueKey('student-login-code')), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
}
