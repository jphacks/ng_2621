import 'dart:async';

import '../domain/game_repository.dart';
import '../domain/game_snapshot.dart';

enum DemoScenario { assigned, submitted, needsRevision, resubmitted, approved }

/// Development fixture adapter only. Never a source of production rewards.
class MockGameRepository implements GameRepository {
  MockGameRepository({DemoScenario scenario = DemoScenario.assigned})
    : _current = snapshotFor(scenario);

  GameSnapshot _current;
  final _changes = StreamController<GameSnapshot>.broadcast(sync: true);

  @override
  GameConnection get connection => GameConnection.demo;

  @override
  Stream<GameSnapshot> watchGameState() => Stream.multi((controller) {
    final subscription = _changes.stream.listen(
      controller.addSync,
      onError: controller.addErrorSync,
      onDone: controller.closeSync,
    );
    controller.addSync(_current);
    controller.onCancel = subscription.cancel;
  });

  /// Test harness entry point, deliberately absent from GameRepository.
  void receiveConfirmedSnapshot(GameSnapshot snapshot) {
    if (snapshot.organizationId != _current.organizationId ||
        snapshot.studentId != _current.studentId) {
      throw const FormatException('Cannot change mock session identity');
    }
    if (snapshot.revision <= _current.revision) return;
    _current = snapshot;
    _changes.add(snapshot);
  }

  Future<void> dispose() => _changes.close();

  static GameSnapshot snapshotFor(DemoScenario scenario, {int? revision}) {
    final time = DateTime.utc(2026, 10, 24, 3);
    final submitted = scenario != DemoScenario.assigned;
    final approved = scenario == DemoScenario.approved;
    return GameSnapshot(
      organizationId: 'demo_org',
      studentId: 'demo_student',
      classIds: ['demo_class'],
      revision: revision ?? scenario.index,
      coins: approved
          ? 100
          : submitted
          ? 30
          : 0,
      confirmedAt: time.add(Duration(minutes: scenario.index)),
      assignments: [
        AssignmentSummary(
          id: 'demo_assignment',
          organizationId: 'demo_org',
          classId: 'demo_class',
          title: '数学プリント No.3',
          description: '指定された問題に取り組みましょう。',
          dueAt: DateTime.utc(2026, 10, 30, 14, 59),
          submittedAt: submitted ? time : null,
          state: switch (scenario) {
            DemoScenario.assigned => AssignmentState.notSubmitted,
            DemoScenario.needsRevision => AssignmentState.needsRevision,
            DemoScenario.approved => AssignmentState.approved,
            _ => AssignmentState.pendingReview,
          },
          revisionCount: scenario == DemoScenario.resubmitted || approved
              ? 1
              : 0,
          feedback: scenario == DemoScenario.needsRevision
              ? '途中の計算も書いてみよう。'
              : null,
        ),
      ],
      rewards: [
        if (submitted)
          RewardReceipt(
            assignmentId: 'demo_assignment',
            studentId: 'demo_student',
            kind: RewardKind.submit,
            amount: 30,
            confirmedAt: time,
          ),
        if (approved)
          RewardReceipt(
            assignmentId: 'demo_assignment',
            studentId: 'demo_student',
            kind: RewardKind.approve,
            amount: 70,
            confirmedAt: time.add(const Duration(minutes: 4)),
          ),
      ],
    );
  }
}
