import 'package:flutter_test/flutter_test.dart';
import 'package:zoo_study/features/study/study_detector/automatic_study_mode.dart';
import 'package:zoo_study/features/study/demo_assignment_store.dart';
import 'package:zoo_study/features/study/study_detector/study_session.dart';
import 'package:zoo_study/features/study/study_detector/study_record.dart';
import 'package:zoo_study/features/study/study_detector/study_reward.dart';

import 'memory_storage.dart';

StudyRecord earned(String id, int seconds, {DateTime? start}) {
  final duration = Duration(seconds: seconds);
  return StudyRecord.fromReport(
    id,
    SessionReport(
      start ?? DateTime.utc(2026, 10, 24, 1),
      duration,
      [
        StudySegment(
          Duration.zero,
          duration,
          const StudyDecision(StudyState.material, '読書'),
        ),
      ],
      rewardIntervals: [RewardInterval(Duration.zero, duration)],
    ),
    subject: '数学',
    samples: seconds,
    completed: true,
  );
}

int eligible(StudySession session, int second) =>
    rewardDays(session.snapshot(Duration(seconds: second))).values
        .fold(0, (a, b) => a + b);
void main() {
  test('material takes priority when face and desk are both visible', () {
    final selector = AutomaticStudyMode();
    selector.observe(face: true, desk: true);
    selector.observe(face: true, desk: true);
    expect(selector.observe(face: true, desk: true), StudyMode.desk);
  });
  test('quiet reading and posture checks qualify without moving a hand or looking at camera', () {
    for (final state in [
      StudyState.material,
      StudyState.studying,
      StudyState.faceCheck,
      StudyState.facePosture,
      StudyState.device,
    ]) {
      final run = StudySession(DateTime.utc(2026, 10, 24));
      for (var second = 0; second < 120; second += 3) {
        run.record(Duration(seconds: second), StudyDecision(state, '観測'));
      }
      expect(eligible(run, 120), 120000);
    }
  });
  test('uncertain observations get at most 30 seconds of continuity; frozen analysis gets only 8', () {
    final run = StudySession(DateTime.utc(2026, 10, 24));
    run.record(Duration.zero, const StudyDecision(StudyState.material, '教材'));
    for (var second = 3; second < 60; second += 3) {
      run.record(
        Duration(seconds: second),
        const StudyDecision(StudyState.unknown, '一時的に見失った'),
      );
    }
    expect(eligible(run, 60), 30000);
    final frozen = StudySession(DateTime.utc(2026, 10, 24));
    frozen.record(
      Duration.zero,
      const StudyDecision(StudyState.facePosture, '姿勢'),
    );
    expect(eligible(frozen, 120), 8000);
  });
  test('errors and background stop immediately and cannot restart grace from old evidence', () {
    final run = StudySession(DateTime.utc(2026, 10, 24));
    run.record(Duration.zero, const StudyDecision(StudyState.material, '教材'));
    run.record(
      const Duration(seconds: 3),
      const StudyDecision(StudyState.unknown, '解析エラー', 0, false),
    );
    run.record(
      const Duration(seconds: 6),
      const StudyDecision(StudyState.unknown, '見失い'),
    );
    run.record(
      const Duration(seconds: 9),
      const StudyDecision(StudyState.suspended, '画面外'),
      expires: false,
    );
    expect(eligible(run, 100), 3000);
  });
  test('2 minute units carry across sessions and cap at 30 with idempotent retries and restart', () async {
    final disk = MemoryStorage();
    var store = await DemoAssignmentStore.open(disk);
    expect(await store.saveStudyRecord(earned('one', 60)), 0);
    expect(await store.saveStudyRecord(earned('two', 60)), 1);
    expect(await store.saveStudyRecord(earned('two', 60)), 1);
    expect(store.coins, 1);
    store.dispose();
    store = await DemoAssignmentStore.open(disk);
    expect(await store.saveStudyRecord(earned('three', 3480)), 29);
    expect(await store.saveStudyRecord(earned('four', 3600)), 0);
    expect(store.coins, 30);
    final records = await store.loadStudyRecords();
    expect(records.firstWhere((r) => r.id == 'three').rewardCoins, 29);
    store.dispose();
  });
  test(
    'midnight splits milliseconds by JST, independent of phone timezone',
    () async {
      final split = earned(
        'midnight',
        120,
        start: DateTime.utc(2026, 10, 24, 14, 59),
      );
      expect(split.rewardMsByDay, {'2026-10-24': 60000, '2026-10-25': 60000});
      final store = DemoAssignmentStore();
      expect(await store.saveStudyRecord(split), 0);
      expect(
        await store.saveStudyRecord(
          earned('after', 60, start: DateTime.utc(2026, 10, 24, 15, 1)),
        ),
        1,
      );
      expect(store.coins, 1);
      store.dispose();
    },
  );
  test('old records do not receive retroactive rewards, and failed persistence can be retried once', () async {
    final disk = MemoryStorage();
    final store = await DemoAssignmentStore.open(disk);
    final legacy = earned('old', 3600).toJson()
      ..remove('rewardMsByDay')
      ..remove('rewardPolicyVersion');
    expect(await store.saveStudyRecord(StudyRecord.fromJson(legacy)), 0);
    disk.fail = true;
    final record = earned('retry', 120);
    await expectLater(store.saveStudyRecord(record), throwsA(anything));
    disk.fail = false;
    expect(await store.saveStudyRecord(record), 1);
    expect(store.coins, 1);
    store.dispose();
  });
}
