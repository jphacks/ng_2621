import 'package:flutter_test/flutter_test.dart';
import 'package:zoo_study/features/game/data/mock_game_repository.dart';
import 'package:zoo_study/features/game/domain/game_notice.dart';
import 'package:zoo_study/features/game/domain/game_snapshot.dart';
import 'package:zoo_study/features/game/presentation/game_session.dart';

void main() {
  test('initial confirmed history is a baseline, not new rewards', () {
    final tracker = GameNoticeTracker();
    expect(
      tracker.receive(MockGameRepository.snapshotFor(DemoScenario.approved)),
      isEmpty,
    );
    expect(
      tracker.receive(
        MockGameRepository.snapshotFor(DemoScenario.approved, revision: 9),
      ),
      isEmpty,
    );
  });

  test('submission and approval notify once with their actual receipts', () {
    final tracker = GameNoticeTracker();
    tracker.receive(MockGameRepository.snapshotFor(DemoScenario.assigned));
    final submitted = tracker.receive(
      MockGameRepository.snapshotFor(DemoScenario.submitted),
    );
    expect(submitted.single.message, '課題を提出！ +30コイン');
    expect(submitted.single.detail, contains('先生の確認でさらに +70コイン'));
    expect(
      tracker.receive(
        MockGameRepository.snapshotFor(DemoScenario.submitted, revision: 2),
      ),
      isEmpty,
    );
    final approved = tracker.receive(
      MockGameRepository.snapshotFor(DemoScenario.approved, revision: 3),
    );
    expect(approved.single.message, '先生が確認！ +70コイン');
    expect(
      tracker.receive(MockGameRepository.snapshotFor(DemoScenario.submitted)),
      isEmpty,
    );
    expect(
      tracker.receive(
        MockGameRepository.snapshotFor(DemoScenario.approved, revision: 4),
      ),
      isEmpty,
    );
  });

  test('revision request notifies once per cycle and resubmission adds no reward notice', () {
    final tracker = GameNoticeTracker();
    tracker.receive(MockGameRepository.snapshotFor(DemoScenario.submitted));
    final revision = tracker.receive(
      MockGameRepository.snapshotFor(DemoScenario.needsRevision),
    );
    expect(revision.single.kind, GameNoticeKind.revisionRequested);
    expect(revision.single.message, 'もう一度チャレンジ！ 前回の30コインはそのまま');
    expect(revision.single.detail, contains('途中の計算も書いてみよう。'));
    expect(
      tracker.receive(
        MockGameRepository.snapshotFor(DemoScenario.needsRevision, revision: 3),
      ),
      isEmpty,
    );
    expect(
      tracker.receive(
        MockGameRepository.snapshotFor(DemoScenario.resubmitted, revision: 4),
      ),
      isEmpty,
    );
    final next = MockGameRepository.snapshotFor(
      DemoScenario.needsRevision,
      revision: 5,
    ).toJson();
    (next['assignments'] as List).single['revisionCount'] = 1;
    expect(tracker.receive(GameSnapshot.fromJson(next)), hasLength(1));
    expect(
      tracker
          .receive(
            MockGameRepository.snapshotFor(DemoScenario.approved, revision: 6),
          )
          .single
          .message,
      contains('+70'),
    );
  });

  test('two new receipts in one update remain separate and do not claim pending review', () {
    final tracker = GameNoticeTracker();
    tracker.receive(MockGameRepository.snapshotFor(DemoScenario.assigned));
    final notices = tracker.receive(
      MockGameRepository.snapshotFor(DemoScenario.approved),
    );
    expect(notices.map((n) => n.message), ['課題を提出！ +30コイン', '先生が確認！ +70コイン']);
    expect(notices.first.detail, isNot(contains('さらに')));
  });

  test('status alone cannot create a reward notice', () {
    final tracker = GameNoticeTracker();
    tracker.receive(MockGameRepository.snapshotFor(DemoScenario.assigned));
    final data = MockGameRepository.snapshotFor(DemoScenario.approved).toJson();
    data['rewards'] = <dynamic>[];
    expect(tracker.receive(GameSnapshot.fromJson(data)), isEmpty);
  });

  test('temporarily omitted receipts do not become new after reappearing', () {
    final tracker = GameNoticeTracker();
    tracker.receive(MockGameRepository.snapshotFor(DemoScenario.submitted));
    final missing = MockGameRepository.snapshotFor(
      DemoScenario.submitted,
      revision: 2,
    ).toJson();
    missing['rewards'] = <dynamic>[];
    tracker.receive(GameSnapshot.fromJson(missing));
    expect(
      tracker.receive(
        MockGameRepository.snapshotFor(DemoScenario.submitted, revision: 3),
      ),
      isEmpty,
    );
  });

  test('session queues notifications, preserves coins and does not replay after refresh', () async {
    final repository = MockGameRepository();
    final session = GameSession(repository);
    addTearDown(() async {
      session.dispose();
      await repository.dispose();
    });
    await Future<void>.delayed(Duration.zero);
    repository.receiveConfirmedSnapshot(
      MockGameRepository.snapshotFor(DemoScenario.approved),
    );
    expect(session.pendingNotices, hasLength(2));
    expect(session.snapshot!.coins, 100);
    final firstId = session.currentNotice!.id;
    session.dismissNotice(firstId);
    expect(session.currentNotice!.message, contains('+70'));
    session.dismissNotice(
      firstId,
    ); // A delayed callback must not dismiss the next reward.
    expect(session.pendingNotices, hasLength(1));
    session.dismissNotice(session.currentNotice!.id);
    session.refresh();
    await Future<void>.delayed(Duration.zero);
    expect(session.pendingNotices, isEmpty);
    expect(session.snapshot!.coins, 100);
  });
}
