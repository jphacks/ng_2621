import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zoo_study/features/auth/presentation/account_form.dart';

void main() {
  Future<void> open(
    WidgetTester tester, {
    bool teacher = false,
    String? signedIn,
    Future<void> Function(String, String, String, String)? register,
    Future<void> Function(String, String)? join,
  }) => tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(
          child: AccountForm(
            isTeacher: teacher,
            busy: false,
            signedInEmail: signedIn,
            onSignIn: (_, _) async {},
            onRegister: register ?? (_, _, _, _) async {},
            onJoin: join ?? (_, _) async {},
            onReset: (_) async {},
            onSignOut: () async {},
          ),
        ),
      ),
    ),
  );
  Future<void> tap(WidgetTester tester, Finder target) async {
    await tester.ensureVisible(target);
    await tester.pump();
    await tester.tap(target);
    await tester.pump();
  }

  testWidgets(
    'registration validates required fields and passes no role or coin input',
    (tester) async {
      var calls = 0;
      List<String>? result;
      await open(
        tester,
        register: (email, password, name, invite) async {
          calls++;
          result = [email, password, name, invite];
        },
      );
      await tap(tester, find.text('生徒アカウントを新規作成'));
      await tap(tester, find.byKey(const ValueKey('account-submit')));
      expect(calls, 0);
      await tester.enterText(
        find.byKey(const ValueKey('account-email')),
        'student@example.test',
      );
      await tester.enterText(
        find.byKey(const ValueKey('account-password')),
        'password123',
      );
      await tester.enterText(
        find.byKey(const ValueKey('account-name')),
        ' 新しい生徒 ',
      );
      await tester.enterText(
        find.byKey(const ValueKey('account-invite')),
        '0123456789abcdef0123456789abcdef',
      );
      tester.testTextInput.hide();
      await tap(tester, find.byKey(const ValueKey('account-submit')));
      expect(calls, 1);
      expect(result, [
        'student@example.test',
        'password123',
        '新しい生徒',
        '0123456789abcdef0123456789abcdef',
      ]);
    },
  );
  testWidgets(
    'partially registered users can retry joining without creating another account',
    (tester) async {
      var calls = 0;
      await open(
        tester,
        signedIn: 'student@example.test',
        join: (name, code) async {
          calls++;
        },
      );
      expect(find.byKey(const ValueKey('account-email')), findsNothing);
      await tester.enterText(find.byKey(const ValueKey('account-name')), '生徒');
      await tester.enterText(
        find.byKey(const ValueKey('account-invite')),
        '0123456789abcdef0123456789abcdef',
      );
      tester.testTextInput.hide();
      await tap(tester, find.text('クラスに参加'));
      expect(calls, 1);
    },
  );
  testWidgets(
    'teacher sign-in never exposes student registration or a role picker',
    (tester) async {
      await open(tester, teacher: true);
      expect(find.text('生徒アカウントを新規作成'), findsNothing);
      expect(find.byKey(const ValueKey('account-invite')), findsNothing);
      expect(find.text('ログイン'), findsOneWidget);
      expect(find.text('パスワードを再設定'), findsOneWidget);
    },
  );
}
