import 'package:flutter/widgets.dart';

import 'study_session.dart';

class DetectorSample {
  const DetectorSample({
    this.face = false,
    this.desk = false,
    this.decision = const StudyDecision(StudyState.unknown, '映り方を確認中'),
  });
  final bool face, desk;
  final StudyDecision decision;
}

abstract class StudyDetectorEngine {
  void cancel() {}
  Future<void> keepAwake(bool enabled) async {}
  bool get supported;
  bool get canSwitchCamera;
  Widget preview();
  Future<void> initialize();
  Future<void> switchCamera();
  Future<void> reset();
  Future<DetectorSample> analyze(Duration at, StudyMode? mode);
  Future<void> suspend();
  Future<void> close();
}
