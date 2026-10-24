import 'package:flutter_test/flutter_test.dart';
import 'package:zoo_study/features/study/demo_assignment_store.dart';
import 'package:zoo_study/features/game/domain/game_snapshot.dart';
import 'package:zoo_study/features/shop/domain/shop_repository.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late DemoAssignmentStore store;
  late String id;
  setUp(() {
    store = DemoAssignmentStore(clock: () => DateTime(2026, 10, 30, 12));
    store.publish(
      DemoAssignment(
        subject: AssignmentSubject.mathematics,
        title: '復習',
        description: '問題を解く',
        dueAt: DateTime(2026, 10, 29),
      ),
    );
    id = store.assignments.single.id;
  });
  tearDown(() => store.dispose());

  test('submit and approve are idempotent, resulting in exactly 100', () {
    expect(store.submit(id, '答え', role: DemoStudyRole.student), 30);
    expect(store.submit(id, '答え', role: DemoStudyRole.student), 0);
    expect(store.coins, 30);
    expect(store.submissionFor(id)!.status, AssignmentState.pendingReview);
    expect(store.snapshot.assignments.single.submittedLate, isTrue);
    expect(store.review(id, role: DemoStudyRole.teacher, approve: true), 70);
    expect(store.review(id, role: DemoStudyRole.teacher, approve: true), 0);
    expect(store.coins, 100);
    expect(store.snapshot.rewards.length, 2);
    expect(
      () => store.submit(id, '変更', role: DemoStudyRole.student),
      throwsA(isA<StudyFailure>()),
    );
  });

  test(
    'revision preserves first reward, comments and one submission record',
    () {
      store.submit(id, '回答1', role: DemoStudyRole.student);
      final submissionId = store.submissionFor(id)!.id;
      store.review(
        id,
        role: DemoStudyRole.teacher,
        approve: false,
        feedback: '途中式を追加',
      );
      expect(store.coins, 30);
      expect(store.submissionFor(id)!.feedback, '途中式を追加');
      expect(store.submit(id, '回答2', role: DemoStudyRole.student), 0);
      expect(store.submit(id, '回答2', role: DemoStudyRole.student), 0);
      expect(store.submissionFor(id)!.revisionCount, 1);
      expect(store.submissionFor(id)!.id, submissionId);
      store.review(id, role: DemoStudyRole.teacher, approve: true);
      expect(store.coins, 100);
    },
  );

  test('invalid input, unknown tasks and wrong roles cannot mutate state', () {
    expect(
      () => store.submit(id, '  ', role: DemoStudyRole.student),
      throwsA(isA<StudyFailure>()),
    );
    expect(
      () => store.submit('missing', '答え', role: DemoStudyRole.student),
      throwsA(isA<StudyFailure>()),
    );
    expect(
      () => store.submit(id, '答え', role: DemoStudyRole.teacher),
      throwsA(isA<StudyFailure>()),
    );
    expect(
      () => store.review(id, role: DemoStudyRole.teacher, approve: true),
      throwsA(isA<StudyFailure>()),
    );
    expect(
      () => store.review(id, role: DemoStudyRole.student, approve: true),
      throwsA(isA<StudyFailure>()),
    );
    expect(store.coins, 0);
    expect(store.submissionFor(id), isNull);
    expect(
      () => store.submit(id, 'a' * 5001, role: DemoStudyRole.student),
      throwsA(isA<StudyFailure>()),
    );
  });

  test(
    'reward coins buy rabbit once and later tasks preserve purchases',
    () async {
      store.submit(id, '答え', role: DemoStudyRole.student);
      store.review(id, role: DemoStudyRole.teacher, approve: true);
      const request = PurchaseRequest(
        requestId: 'purchase-1',
        itemId: 'rabbit',
      );
      await store.purchase(request);
      await store.purchase(request);
      expect(store.coins, 0);
      expect(store.snapshot.ownedAnimalIds, contains('rabbit'));
      store.publish(
        DemoAssignment(
          subject: AssignmentSubject.english,
          title: '英語',
          description: '単語',
          dueAt: DateTime(2026, 11, 1),
        ),
      );
      final next = store.assignments.last.id;
      store.submit(next, '答え', role: DemoStudyRole.student);
      expect(store.coins, 30);
      expect(store.snapshot.ownedAnimalIds, contains('rabbit'));
      expect(store.snapshot.assignments.length, 2);
    },
  );
}
