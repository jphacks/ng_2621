import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zoo_study/features/study/demo_assignment_store.dart';
import 'package:zoo_study/features/study/study_detector/automatic_study_mode.dart';
import 'package:zoo_study/features/study/study_detector/detector_engine.dart';
import 'package:zoo_study/features/study/study_detector/study_mode_screen.dart';
import 'package:zoo_study/features/study/study_detector/study_record.dart';
import 'package:zoo_study/features/study/study_detector/study_record_journal.dart';
import 'package:zoo_study/features/study/study_detector/study_records_screen.dart';
import 'package:zoo_study/features/study/study_detector/study_session.dart';
import 'package:zoo_study/features/study/study_detector/face_study.dart';

import 'memory_storage.dart';

class FakeDetector extends StudyDetectorEngine {
  bool open = false;
  bool awake = false;
  @override
  Future<void> keepAwake(bool enabled) async {
    awake = enabled;
  }

  int frames = 0;
  @override
  bool get supported => true;
  @override
  bool get canSwitchCamera => true;
  @override
  Widget preview() => const Text('カメラプレビュー');
  @override
  Future<void> initialize() async {
    open = true;
  }

  @override
  Future<void> switchCamera() async {}
  @override
  Future<void> reset() async {}
  @override
  Future<void> suspend() async {
    open = false;
    awake = false;
  }

  @override
  Future<void> close() async {
    open = false;
    awake = false;
  }

  @override
  Future<DetectorSample> analyze(Duration at, StudyMode? mode) async {
    frames++;
    return const DetectorSample(
      face: true,
      decision: StudyDecision(StudyState.faceCheck, '初期姿勢を確認中'),
    );
  }
}

StudyRecord record({bool completed = true}) {
  final session = StudySession(
    DateTime.utc(2026, 10, 24),
    mode: StudyMode.face,
  );
  session.record(
    const Duration(seconds: 2),
    const StudyDecision(StudyState.facePosture, '姿勢'),
  );
  session.record(
    const Duration(seconds: 5),
    const StudyDecision(StudyState.suspended, '画面外'),
    expires: false,
  );
  return StudyRecord.fromReport(
    'session-test',
    session.finish(const Duration(seconds: 20)),
    subject: '数学',
    samples: 2,
    completed: completed,
  );
}

void main() {
  test('automatic selection requires three stable observations', () {
    final selector = AutomaticStudyMode();
    for (var i = 0; i < 10; i++) {
      expect(selector.observe(face: false, desk: false), isNull);
    }
    expect(selector.observe(face: true, desk: false), isNull);
    expect(selector.observe(face: false, desk: false), isNull);
    expect(selector.observe(face: false, desk: true), isNull);
    expect(selector.observe(face: false, desk: true), isNull);
    expect(selector.observe(face: false, desk: true), StudyMode.desk);
    selector.reset();
    selector.observe(face: true, desk: false);
    selector.observe(face: true, desk: false);
    expect(selector.observe(face: true, desk: false), StudyMode.face);
  });
  test(
    'stale observations and background are separate from estimated study',
    () {
      final session = StudySession(DateTime.now());
      session.record(
        Duration.zero,
        const StudyDecision(StudyState.studying, '手元'),
      );
      expect(
        session
            .snapshot(const Duration(seconds: 40))
            .total(StudyState.studying),
        const Duration(seconds: 8),
      );
      session.record(
        const Duration(seconds: 40),
        const StudyDecision(StudyState.suspended, '画面外'),
        expires: false,
      );
      final report = session.finish(const Duration(seconds: 100));
      expect(report.total(StudyState.unknown), const Duration(seconds: 32));
      expect(report.total(StudyState.suspended), const Duration(seconds: 60));
      expect(
        session.finish(const Duration(seconds: 500)).elapsed,
        const Duration(seconds: 100),
      );
    },
  );
  test(
    'submillisecond buckets serialize to exactly the elapsed integer duration',
    () {
      final session = StudySession(DateTime.now());
      session.record(
        const Duration(microseconds: 1100),
        const StudyDecision(StudyState.material, '教材'),
      );
      session.record(
        const Duration(microseconds: 2600),
        const StudyDecision(StudyState.studying, '手元'),
      );
      final result = StudyRecord.fromReport(
        'rounding',
        session.finish(const Duration(microseconds: 3900)),
        subject: '数学',
        samples: 2,
        completed: true,
      );
      expect(() => result.validate(), returnsNormally);
      expect(result.stateMs.values.reduce((a, b) => a + b), result.elapsedMs);
    },
  );
  test('face calibration is not a claim of studying or concentration', () {
    final classifier = FacePostureClassifier();
    FaceObservation sample(int second) => FaceObservation(
      Duration(seconds: second),
      count: 1,
      usable: true,
      pitch: 0,
      yaw: 0,
      roll: 0,
      leftEye: .9,
      rightEye: .9,
    );
    expect(classifier.classify(sample(0)).state, StudyState.faceCheck);
    classifier.classify(sample(3));
    expect(classifier.classify(sample(6)).state, StudyState.facePosture);
    expect(
      classifier.classify(const FaceObservation(Duration(seconds: 9))).state,
      StudyState.unknown,
    );
  });
  test('records persist independently of rewards and repeated saves are idempotent', () async {
    final disk = MemoryStorage();
    var store = await DemoAssignmentStore.open(disk);
    await store.saveStudyRecord(record());
    await store.saveStudyRecord(record());
    expect(store.coins, 0);
    store.dispose();
    store = await DemoAssignmentStore.open(disk);
    final records = await store.loadStudyRecords();
    expect(records, hasLength(1));
    expect(records.single.activeMs, 5000);
    expect(records.single.suspendedMs, 15000);
    expect(store.coins, 0);
    store.dispose();
  });
  test('interrupted checkpoint recovers without counting time while app was closed', () async {
    final disk = MemoryStorage();
    final store = await DemoAssignmentStore.open(disk);
    await StudyRecordJournal(disk).write(record(completed: false));
    await recoverStudyRecord(store);
    await recoverStudyRecord(store);
    final saved = (await store.loadStudyRecords()).single;
    expect(saved.elapsedMs, 20000);
    expect(saved.completed, false);
    expect(await disk.read(StudyRecordJournal.key), isNull);
    store.dispose();
  });
  test('failed saving preserves the outbox for retry', () async {
    final disk = MemoryStorage();
    final store = await DemoAssignmentStore.open(disk);
    await StudyRecordJournal(disk).write(record());
    disk.fail = true;
    await expectLater(recoverStudyRecord(store), throwsA(anything));
    expect(await disk.read(StudyRecordJournal.key), isNotNull);
    disk.fail = false;
    await recoverStudyRecord(store);
    expect((await store.loadStudyRecords()), hasLength(1));
    expect(await disk.read(StudyRecordJournal.key), isNull);
    store.dispose();
  });
  testWidgets(
    'study screen prepares automatically, hides preview while running and saves',
    (tester) async {
      final disk = MemoryStorage();
      final store = DemoAssignmentStore(storage: disk);
      final engine = FakeDetector();
      await tester.pumpWidget(
        MaterialApp(
          home: StudyModeScreen(store: store, engine: engine),
        ),
      );
      await tester.pumpAndSettle();
      expect(engine.open, false);
      await tester.ensureVisible(find.text('確認してカメラを準備'));
      await tester.tap(find.text('確認してカメラを準備'));
      await tester.pumpAndSettle();
      await tester.pump(const Duration(seconds: 3));
      await tester.pump(const Duration(seconds: 3));
      await tester.pumpAndSettle();
      expect(engine.frames, greaterThanOrEqualTo(3));
      await tester.scrollUntilVisible(
        find.text('自動選択：顔モード'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('自動選択：顔モード'), findsOneWidget);
      await tester.scrollUntilVisible(
        find.text('勉強を開始'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.ensureVisible(find.widgetWithText(FilledButton, '勉強を開始'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('勉強を開始'));
      await tester.pumpAndSettle();
      expect(find.text('勉強中'), findsOneWidget);
      expect(engine.awake, true);
      expect(find.text('カメラプレビュー'), findsNothing);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      await tester.pumpAndSettle();
      expect(engine.open, false);
      final beforePause = engine.frames;
      await tester.pump(const Duration(seconds: 12));
      expect(engine.frames, beforePause);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpAndSettle();
      expect(engine.open, true);
      disk.fail = true;
      await tester.tap(find.text('終了して保存'));
      await tester.pumpAndSettle();
      expect(engine.open, false);
      expect(engine.awake, false);
      expect(find.text('保存を再試行'), findsOneWidget);
      disk.fail = false;
      await tester.tap(find.text('保存を再試行'));
      await tester.pumpAndSettle();
      expect(engine.open, false);
      expect(find.text('学習記録を保存しました'), findsOneWidget);
      expect(await store.loadStudyRecords(), hasLength(1));
      await tester.pumpWidget(
        MaterialApp(home: StudyRecordsScreen(store: store, isTeacher: true)),
      );
      await tester.pumpAndSettle();
      expect(find.text('デモ生徒'), findsOneWidget);
      expect(find.text('判定方式：顔の姿勢'), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
      store.dispose();
    },
  );
}
