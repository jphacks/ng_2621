import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zoo_study/features/study/assignment_detail_screen.dart';
import 'package:zoo_study/features/study/demo_assignment_store.dart';
import 'package:zoo_study/features/game/domain/game_snapshot.dart';

void main() {
  testWidgets(
    'student submits, teacher requests revision, student resubmits and teacher approves',
    (tester) async {
      final store = DemoAssignmentStore();
      addTearDown(store.dispose);
      store.publish(
        DemoAssignment(
          subject: AssignmentSubject.english,
          title: '英語の宿題',
          description: '単語を復習',
          dueAt: DateTime.now().subtract(const Duration(days: 1)),
        ),
      );
      final id = store.assignments.single.id;
      Future<void> open(bool teacher) async {
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pumpWidget(
          MaterialApp(
            home: AssignmentDetailScreen(
              store: store,
              assignmentId: id,
              isTeacher: teacher,
            ),
          ),
        );
        await tester.pumpAndSettle();
      }

      Future<void> tap(String label) async {
        tester.testTextInput.hide();
        await tester.pumpAndSettle();
        await tester.scrollUntilVisible(
          find.text(label),
          200,
          scrollable: find.byType(Scrollable).first,
        );
        await tester.ensureVisible(find.text(label));
        await tester.pumpAndSettle();
        await tester.tap(find.text(label));
        await tester.pumpAndSettle();
      }

      await open(false);
      await tester.enterText(find.byType(TextFormField), '最初の回答');
      await tap('課題を提出する');
      expect(store.coins, 30);
      expect(find.textContaining('期限後提出'), findsOneWidget);
      expect(find.text('課題を提出する'), findsNothing);
      await open(true);
      expect(find.text('最初の回答'), findsOneWidget);
      await tester.enterText(find.byType(TextFormField), 'もう一度確認してね');
      await tap('再提出を依頼');
      expect(store.coins, 30);
      expect(store.submissionFor(id)!.status, AssignmentState.needsRevision);
      await open(false);
      expect(find.text('先生から：もう一度確認してね'), findsOneWidget);
      await tester.enterText(find.byType(TextFormField), '修正した回答');
      await tap('再提出する');
      expect(store.coins, 30);
      await open(true);
      expect(find.text('修正した回答'), findsOneWidget);
      await tap('内容を確認して承認');
      expect(store.coins, 100);
      expect(store.submissionFor(id)!.status, AssignmentState.approved);
      expect(find.text('内容を確認して承認'), findsNothing);
      await open(false);
      expect(find.textContaining('100コイン獲得済み'), findsOneWidget);
      expect(find.byType(TextFormField), findsNothing);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
}
