import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:zoo_study/features/game/data/mock_game_repository.dart';
import 'package:zoo_study/features/game/domain/game_repository.dart';
import 'package:zoo_study/features/game/domain/game_snapshot.dart';
import 'package:zoo_study/features/game/presentation/game_session.dart';

Map<String, dynamic> fixture() => jsonDecode(
  jsonEncode(MockGameRepository.snapshotFor(DemoScenario.approved).toJson()),
) as Map<String, dynamic>;

void main() {
  test('snapshot contract round trips without losing server result', () {
    final snapshot = GameSnapshot.fromJson(fixture());
    expect(snapshot.coins, 100);
    expect(snapshot.assignments.single.state, AssignmentState.approved);
    expect(snapshot.rewards.map((r) => r.transactionId), [
      'demo_assignment_demo_student_submit',
      'demo_assignment_demo_student_approve',
    ]);
    expect(snapshot.rewards.map((r) => r.amount), [30, 70]);
    expect(
      GameSnapshot.fromJson(snapshot.toJson()).toJson(),
      snapshot.toJson(),
    );
    expect(() => snapshot.assignments.clear(), throwsUnsupportedError);
    expect(() => snapshot.ownedAnimalIds.add('fox'), throwsUnsupportedError);
  });

  test('rejects unknown schema/status and negative balances', () {
    final schema = fixture()..['schemaVersion'] = 2;
    expect(() => GameSnapshot.fromJson(schema), throwsFormatException);
    final status = fixture();
    (status['assignments'] as List).first['status'] = 'invented';
    expect(() => GameSnapshot.fromJson(status), throwsFormatException);
    final negative = fixture()..['coins'] = -1;
    expect(() => GameSnapshot.fromJson(negative), throwsFormatException);
  });

  test('rejects mixed organization, class, student and duplicate receipts', () {
    final organization = fixture();
    (organization['assignments'] as List).first['organizationId'] = 'other_org';
    expect(() => GameSnapshot.fromJson(organization), throwsFormatException);
    final classroom = fixture();
    (classroom['assignments'] as List).first['classId'] = 'other_class';
    expect(() => GameSnapshot.fromJson(classroom), throwsFormatException);
    final student = fixture();
    (student['rewards'] as List).first['studentId'] = 'other_student';
    expect(() => GameSnapshot.fromJson(student), throwsFormatException);
    final duplicate = fixture();
    (duplicate['rewards'] as List).add((duplicate['rewards'] as List).first);
    expect(() => GameSnapshot.fromJson(duplicate), throwsFormatException);
  });

  test('submission time determines late label independently of status', () {
    final data = fixture();
    (data['assignments'] as List).first['submittedAt'] = '2026-10-31T10:00:00Z';
    final assignment = GameSnapshot.fromJson(data).assignments.single;
    expect(assignment.submittedLate, isTrue);
    expect(assignment.state, AssignmentState.approved);
    expect(
      MockGameRepository.snapshotFor(DemoScenario.assigned)
          .assignments
          .single
          .submittedLate,
      isFalse,
    );
  });

  test(
    'mock projections distinguish 0,30,100 and never reward revisions twice',
    () {
      final expected = {
        DemoScenario.assigned: 0,
        DemoScenario.submitted: 30,
        DemoScenario.needsRevision: 30,
        DemoScenario.resubmitted: 30,
        DemoScenario.approved: 100,
      };
      for (final entry in expected.entries) {
        final snapshot = MockGameRepository.snapshotFor(entry.key);
        expect(snapshot.coins, entry.value);
        expect(
          snapshot.rewards.where((r) => r.kind == RewardKind.submit).length,
          entry.value == 0 ? 0 : 1,
        );
      }
    },
  );

  test(
    'confirmed updates reach multiple game subscribers and ignore replays',
    () async {
      final repository = MockGameRepository();
      final session = GameSession(repository);
      final other = GameSession(repository);
      addTearDown(() async {
        session.dispose();
        other.dispose();
        await repository.dispose();
      });
      await Future<void>.delayed(Duration.zero);
      expect(session.snapshot!.coins, 0);
      repository.receiveConfirmedSnapshot(
        MockGameRepository.snapshotFor(DemoScenario.submitted),
      );
      expect(session.snapshot!.coins, 30);
      expect(
        other.snapshot!.assignments.single.state,
        AssignmentState.pendingReview,
      );
      repository.receiveConfirmedSnapshot(
        MockGameRepository.snapshotFor(DemoScenario.approved),
      );
      repository.receiveConfirmedSnapshot(
        MockGameRepository.snapshotFor(DemoScenario.submitted),
      );
      repository.receiveConfirmedSnapshot(
        MockGameRepository.snapshotFor(DemoScenario.approved),
      );
      expect(session.snapshot!.coins, 100);
      expect(session.snapshot!.rewards, hasLength(2));
      final foreign = fixture()..['studentId'] = 'stranger';
      foreign['rewards'] = <dynamic>[];
      expect(
        () =>
            repository.receiveConfirmedSnapshot(GameSnapshot.fromJson(foreign)),
        throwsFormatException,
      );
    },
  );

  test(
    'session retains confirmed balance on stream errors and can retry',
    () async {
      final repository = _TestRepository();
      final session = GameSession(repository);
      addTearDown(() async {
        session.dispose();
        await repository.events.close();
      });
      repository.events.add(
        MockGameRepository.snapshotFor(DemoScenario.submitted),
      );
      expect(session.snapshot!.coins, 30);
      repository.events.addError(StateError('offline'));
      expect(session.failed, isTrue);
      expect(session.snapshot!.coins, 30);
      session.refresh();
      repository.events.add(
        MockGameRepository.snapshotFor(DemoScenario.approved),
      );
      expect(session.failed, isFalse);
      expect(session.snapshot!.coins, 100);
    },
  );

  test('disconnected source supplies no invented balance', () async {
    final session = GameSession(const DisconnectedGameRepository());
    addTearDown(session.dispose);
    await Future<void>.delayed(Duration.zero);
    expect(session.snapshot, isNull);
    expect(session.loading, isFalse);
  });
}

class _TestRepository implements GameRepository {
  final events = StreamController<GameSnapshot>.broadcast(sync: true);
  @override
  GameConnection get connection => GameConnection.connected;
  @override
  Stream<GameSnapshot> watchGameState() => events.stream;
}
