import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:zoo_study/features/auth/data/school_account_api.dart';
import 'package:zoo_study/features/auth/presentation/school_management_screen.dart';
import 'package:zoo_study/features/auth/presentation/student_code_form.dart';

import '../study/memory_storage.dart';

void main() {
  test(
    'preview persists classes and roster; reissue keeps student identity',
    () async {
      final storage = MemoryStorage();
      final api = LocalSchoolAccountApi(storage);
      final room = await api.call('createManagedClass', {'name': 'ひまわり組'});
      final first = await api.call('createManagedStudent', {
        'classId': room['classId'],
        'name': 'はなこ',
      });
      expect(validStudentCode(first['loginCode'] as String), true);
      final reopened = LocalSchoolAccountApi(storage);
      final roster = await reopened.call('listManagedStudents', {
        'classId': room['classId'],
      });
      expect((roster['students'] as List).single['name'], 'はなこ');
      final replacement = await reopened.call('reissueStudentCode', {
        'classId': room['classId'],
        'studentId': first['studentId'],
      });
      expect(replacement['studentId'], first['studentId']);
      expect(replacement['loginCode'], isNot(first['loginCode']));
    },
  );
  testWidgets('student uses code or QR without an email field', (tester) async {
    String? submitted;
    const code = 'ABC234-DEFG-HJKL-MNPQ-RSTU';
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: StudentCodeForm(
            busy: false,
            onLogin: (value) async => submitted = value,
            onScan: () async => code,
          ),
        ),
      ),
    );
    await tester.tap(find.text('このコードで はじめる'));
    await tester.pump();
    expect(submitted, isNull);
    expect(find.text('メールアドレス'), findsNothing);
    await tester.tap(find.text('QRコードを よみとる'));
    await tester.pump();
    await tester.tap(find.text('このコードで はじめる'));
    await tester.pumpAndSettle();
    expect(submitted, 'ABC234DEFGHJKLMNPQRSTU');
  });
  testWidgets(
    'teacher creates a class, registers a student and sees QR and code',
    (tester) async {
      tester.view.physicalSize = const Size(900, 1200);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final api = LocalSchoolAccountApi(MemoryStorage());
      await tester.pumpWidget(
        MaterialApp(home: SchoolManagementScreen(api: api)),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('クラスを作成'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextFormField), 'ひまわり組');
      await tester.tap(find.text('登録'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('生徒を登録'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextFormField).last, 'はなこ');
      await tester.tap(find.text('登録'));
      await tester.pumpAndSettle();
      expect(find.text('はなこさんのログインコード'), findsOneWidget);
      expect(find.byType(QrImageView), findsOneWidget);
      expect(find.text('コードをコピー'), findsOneWidget);
      await tester.tap(find.text('閉じる'));
      await tester.pumpAndSettle();
      expect(find.text('はなこ'), findsOneWidget);
      expect(find.text('専用コード発行済み'), findsOneWidget);
    },
  );
}
