import 'package:flutter/widgets.dart';

import 'detector_engine.dart';
import 'study_session.dart';

StudyDetectorEngine createStudyDetectorEngine() => _UnsupportedDetector();

class _UnsupportedDetector extends StudyDetectorEngine {
  @override
  bool get supported => false;
  @override
  bool get canSwitchCamera => false;
  @override
  Widget preview() => const SizedBox.shrink();
  @override
  Future<void> initialize() async =>
      throw UnsupportedError('勉強判定はAndroid版で利用できます');
  @override
  Future<void> switchCamera() async {}
  @override
  Future<void> reset() async {}
  @override
  Future<DetectorSample> analyze(Duration at, StudyMode? mode) async =>
      const DetectorSample();
  @override
  Future<void> suspend() async {}
  @override
  Future<void> close() async {}
}
