import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zoo_study/core/storage/draft_storage.dart';
import 'package:zoo_study/features/auth/presentation/saved_role_gate.dart';

import '../study/memory_storage.dart';

Widget app(DraftStorage storage) => MaterialApp(
  home: SavedRoleGate(
    storage: storage,
    teacherPageBuilder: (_) => const Scaffold(body: Text('先生のホーム')),
    studentPageBuilder: (_) => const Scaffold(body: Text('生徒のホーム')),
  ),
);

void main() {
  for (final role in ['先生', '生徒']) {
    testWidgets('$role resumes after closing the app without asking again', (
      tester,
    ) async {
      SharedPreferences.setMockInitialValues({});
      final preferences = await SharedPreferences.getInstance();
      final storage = PreferencesDraftStorage(preferences, 'local-demo');
      await tester.pumpWidget(app(storage));
      await tester.pumpAndSettle();
      await tester.tap(find.text('$roleはこちら'));
      await tester.pump();
      await tester.tap(find.text('確定'));
      await tester.pumpAndSettle();
      expect(find.text('$roleのホーム'), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
      // A new storage adapter and widget tree simulate re-entering after restart.
      await tester.pumpWidget(
        app(PreferencesDraftStorage(preferences, 'local-demo')),
      );
      await tester.pumpAndSettle();
      expect(find.text('$roleのホーム'), findsOneWidget);
      expect(find.text('先生はこちら'), findsNothing);
      expect(find.text('生徒はこちら'), findsNothing);
      expect(
        Navigator.of(tester.element(find.text('$roleのホーム'))).canPop(),
        isFalse,
      );
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }
  testWidgets('failed role saving stays on selection and permits retry', (
    tester,
  ) async {
    final storage = MemoryStorage();
    await tester.pumpWidget(app(storage));
    await tester.pumpAndSettle();
    storage.fail = true;
    await tester.tap(find.text('先生はこちら'));
    await tester.pump();
    await tester.tap(find.text('確定'));
    await tester.pumpAndSettle();
    expect(find.textContaining('選択を保存できませんでした'), findsOneWidget);
    expect(find.text('先生のホーム'), findsNothing);
    storage.fail = false;
    await tester.tap(find.text('確定'));
    await tester.pumpAndSettle();
    expect(find.text('先生のホーム'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpWidget(app(storage));
    await tester.pumpAndSettle();
    expect(find.text('先生のホーム'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
