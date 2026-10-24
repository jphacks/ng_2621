import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zoo_study/features/study/demo_assignment_store.dart';
import 'package:zoo_study/features/study/teacher_assignments_screen.dart';

void main() {
  testWidgets('teacher selects a subject and publishes required content', (
    tester,
  ) async {
    final store = DemoAssignmentStore();
    addTearDown(store.dispose);
    await tester.pumpWidget(
      MaterialApp(home: TeacherAssignmentsScreen(store: store)),
    );
    await tester.tap(find.text('課題を作成'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('課題を配布する'));
    await tester.tap(find.text('課題を配布する'));
    await tester.pumpAndSettle();
    expect(store.assignments, isEmpty);
    await tester.ensureVisible(
      find.byType(DropdownButtonFormField<AssignmentSubject>),
    );
    await tester.tap(find.byType(DropdownButtonFormField<AssignmentSubject>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('英語').last);
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField).at(0), '単語の復習');
    await tester.enterText(
      find.byType(TextFormField).at(1),
      '20ページの単語をノートに書いてください。',
    );
    await tester.ensureVisible(find.text('課題を配布する'));
    await tester.tap(find.text('課題を配布する'));
    await tester.pumpAndSettle();
    expect(store.assignments.single.subject, AssignmentSubject.english);
    expect(store.assignments.single.title, '単語の復習');
    expect(store.assignments.single.description, '20ページの単語をノートに書いてください。');
    expect(find.text('英語'), findsOneWidget);
    expect(find.text('単語の復習'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
