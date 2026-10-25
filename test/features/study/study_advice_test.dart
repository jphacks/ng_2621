import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zoo_study/features/study/demo_assignment_store.dart';
import 'package:zoo_study/features/study/advice/study_advice_panel.dart';

import 'memory_storage.dart';

void main() {
  test('draft is private, edited approval persists and repeated sending is idempotent', () async {
    final storage = MemoryStorage();
    final store = await DemoAssignmentStore.open(storage);
    final a = await store.generateStudyAdvice('demo_student');
    expect(a.source, 'template');
    expect(a.summary, contains('記録はありません'));
    expect(await store.loadStudyAdvice(teacher: false), isEmpty);
    final reopened = await DemoAssignmentStore.open(storage);
    expect(
      (await reopened.loadStudyAdvice(teacher: true)).single.published,
      false,
    );
    await reopened.publishStudyAdvice(a.id, '  よくとりくんだね！  ');
    await reopened.publishStudyAdvice(a.id, 'よくとりくんだね！');
    final again = await DemoAssignmentStore.open(storage);
    expect(
      (await again.loadStudyAdvice(teacher: false)).single.message,
      'よくとりくんだね！',
    );
    expect(
      () => again.publishStudyAdvice(a.id, '別の文章'),
      throwsA(isA<StudyFailure>()),
    );
    store.dispose();
    reopened.dispose();
    again.dispose();
  });
  testWidgets(
    'teacher generates and edits, student sees only approved message',
    (tester) async {
      final store = DemoAssignmentStore();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: StudyAdvicePanel(store: store, teacher: true),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('アドバイス案を作成'));
      await tester.pumpAndSettle();
      expect(find.text('定型文プレビュー（AI未使用）'), findsOneWidget);
      await tester.enterText(find.byType(TextField), 'いっしょにがんばろう！');
      await tester.tap(find.text('確認して生徒へ送る'));
      await tester.pumpAndSettle();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StudyAdvicePanel(
              key: const ValueKey('student'),
              store: store,
              teacher: false,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('いっしょにがんばろう！'), findsOneWidget);
      expect(find.textContaining('未記録の学習'), findsNothing);
      expect(find.text('アドバイス案を作成'), findsNothing);
      store.dispose();
    },
  );
}
