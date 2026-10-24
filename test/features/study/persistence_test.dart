import 'package:flutter/material.dart';
import 'package:zoo_study/features/study/teacher_assignments_screen.dart';
import 'package:zoo_study/features/study/assignment_detail_screen.dart';

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:zoo_study/core/storage/draft_storage.dart';
import 'package:zoo_study/features/study/demo_assignment_store.dart';
import 'package:zoo_study/features/game/domain/game_snapshot.dart';
import 'package:zoo_study/features/shop/domain/shop_repository.dart';

class MemoryStorage implements DraftStorage {
  final data = <String, String>{};
  bool fail = false;
  int writes = 0;
  @override
  Future<Map<String, dynamic>?> read(String key) async =>
      data[key] == null ? null : jsonDecode(data[key]!) as Map<String, dynamic>;
  @override
  Future<void> write(String key, Map<String, dynamic> value) async {
    if (fail) throw StateError('Disk full');
    writes++;
    data[key] = jsonEncode(value);
  }

  @override
  Future<void> remove(String key) async {
    data.remove(key);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'restart restores tasks, revisions, rewards, purchases and retry receipts',
    () async {
      final disk = MemoryStorage();
      final first = await DemoAssignmentStore.open(disk);
      first.publish(
        DemoAssignment(
          id: 'stable-id',
          subject: AssignmentSubject.english,
          title: '単語',
          description: '復習',
          dueAt: DateTime(2026, 11, 1),
        ),
      );
      first.submit('stable-id', '回答', role: DemoStudyRole.student);
      first.review(
        'stable-id',
        role: DemoStudyRole.teacher,
        approve: false,
        feedback: '修正してね',
      );
      first.submit('stable-id', '修正した回答', role: DemoStudyRole.student);
      first.review('stable-id', role: DemoStudyRole.teacher, approve: true);
      const purchase = PurchaseRequest(
        requestId: 'saved-purchase',
        itemId: 'rabbit',
      );
      await first.purchase(purchase);
      await first.flush();
      first.dispose();
      final restored = await DemoAssignmentStore.open(disk);
      expect(restored.assignments.single.subject, AssignmentSubject.english);
      expect(restored.submissionFor('stable-id')!.answerText, '修正した回答');
      expect(restored.submissionFor('stable-id')!.revisionCount, 1);
      expect(
        restored.submissionFor('stable-id')!.status,
        AssignmentState.approved,
      );
      expect(restored.coins, 0);
      expect(restored.snapshot.rewards.length, 2);
      expect(restored.snapshot.ownedAnimalIds, contains('rabbit'));
      await restored.purchase(purchase);
      expect(restored.coins, 0);
      expect(
        restored.review(
          'stable-id',
          role: DemoStudyRole.teacher,
          approve: true,
        ),
        0,
      );
      restored.dispose();
    },
  );
  test('save failure is visible and retry retains current work', () async {
    final disk = MemoryStorage();
    final store = await DemoAssignmentStore.open(disk);
    disk.fail = true;
    store.publish(
      DemoAssignment(
        subject: AssignmentSubject.science,
        title: '理科',
        description: '復習',
        dueAt: DateTime(2026, 11, 1),
      ),
    );
    await expectLater(store.flush(), throwsA(isA<StudyFailure>()));
    expect(store.storageError, isNotNull);
    disk.fail = false;
    await store.refresh();
    expect(store.storageError, isNull);
    final restored = await DemoAssignmentStore.open(disk);
    expect(restored.assignments.single.title, '理科');
    store.dispose();
    restored.dispose();
  });
  test('corrupt existing data is never silently overwritten', () async {
    final disk = MemoryStorage();
    disk.data['study-state'] = '{broken';
    await expectLater(
      DemoAssignmentStore.open(disk),
      throwsA(isA<StudyFailure>()),
    );
    expect(disk.data['study-state'], '{broken');
    expect(disk.writes, 0);
  });
  test('queued draft saves and clear cannot restore an older answer', () async {
    final disk = MemoryStorage();
    final session = DraftSession(disk, 'answer');
    session.save({'answer': 'old'});
    session.save({'answer': 'new'});
    await session.clear();
    expect(await disk.read('answer'), isNull);
    session.save({'answer': '最新'});
    await Future<void>.delayed(Duration.zero);
    expect((await DraftSession(disk, 'answer').read())!['answer'], '最新');
  });
  testWidgets(
    'teacher task draft is restored and cleared only after publication',
    (tester) async {
      final disk = MemoryStorage();
      final store = await DemoAssignmentStore.open(disk);
      addTearDown(store.dispose);
      await tester.pumpWidget(
        MaterialApp(home: TeacherAssignmentsScreen(store: store)),
      );
      await tester.tap(find.text('課題を作成'));
      await tester.pumpAndSettle();
      await tester.tap(find.byType(DropdownButtonFormField<AssignmentSubject>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('英語').last);
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextFormField).at(0), '保存する課題');
      await tester.enterText(find.byType(TextFormField).at(1), '説明の下書き');
      await tester.pumpAndSettle();
      await tester.pageBack();
      await tester.pumpAndSettle();
      await tester.tap(find.text('課題を作成'));
      await tester.pumpAndSettle();
      expect(find.text('保存する課題'), findsOneWidget);
      expect(find.text('説明の下書き'), findsOneWidget);
      await tester.ensureVisible(find.text('課題を配布する'));
      await tester.tap(find.text('課題を配布する'));
      await tester.pumpAndSettle();
      expect(store.assignments.single.title, '保存する課題');
      expect(await disk.read('new-assignment'), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
  testWidgets(
    'unsubmitted answer survives closing the page and clears after confirmed submission',
    (tester) async {
      final disk = MemoryStorage();
      final store = await DemoAssignmentStore.open(disk);
      addTearDown(store.dispose);
      store.publish(
        DemoAssignment(
          id: 'answer-draft',
          subject: AssignmentSubject.science,
          title: '理科',
          description: '復習',
          dueAt: DateTime(2026, 11, 1),
        ),
      );
      await store.flush();
      Future<void> open() async {
        await tester.pumpWidget(
          MaterialApp(
            home: AssignmentDetailScreen(
              store: store,
              assignmentId: 'answer-draft',
              isTeacher: false,
            ),
          ),
        );
        await tester.pumpAndSettle();
      }

      await open();
      await tester.enterText(find.byType(TextFormField), '途中まで書いた回答');
      await tester.pumpAndSettle();
      await tester.pumpWidget(const SizedBox.shrink());
      await open();
      expect(find.text('途中まで書いた回答'), findsOneWidget);
      await tester.ensureVisible(find.text('課題を提出する'));
      await tester.tap(find.text('課題を提出する'));
      await tester.pumpAndSettle();
      expect(store.submissionFor('answer-draft')!.answerText, '途中まで書いた回答');
      expect(await disk.read('answer-answer-draft-self'), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
}
