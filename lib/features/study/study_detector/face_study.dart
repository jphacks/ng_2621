import 'study_session.dart';

class FaceObservation {
  final Duration at;
  final String? targetIssue;
  final int count;
  final bool usable;
  final double? pitch;
  final double? yaw;
  final double? roll;
  final double? leftEye;
  final double? rightEye;
  const FaceObservation(
    this.at, {
    this.count = 0,
    this.targetIssue,
    this.usable = false,
    this.pitch,
    this.yaw,
    this.roll,
    this.leftEye,
    this.rightEye,
  });
  bool get anglesAvailable =>
      [pitch, yaw, roll].every((value) => value != null && value.isFinite);
  bool get eyesClosed =>
      leftEye != null && rightEye != null && leftEye! < .25 && rightEye! < .25;
}

// This is a transparent posture heuristic. It does not estimate concentration,
// identify the person, or detect whether the task is study, video or a game.
class FacePostureClassifier {
  final List<FaceObservation> _calibration = [];
  double? _pitch;
  double? _yaw;
  double? _roll;
  Duration? _lastAt;
  Duration? _closedSince;
  Duration? _lastAccepted;
  bool get calibrated => _pitch != null;
  int get calibrationCount => _calibration.length;
  String get baselineDescription => !calibrated
      ? '初期姿勢を確認中（$calibrationCount/3）'
      : '初期姿勢：上下 ${_pitch!.toStringAsFixed(1)}°／左右 ${_yaw!.toStringAsFixed(1)}°';

  void reset() {
    _calibration.clear();
    _pitch = _yaw = _roll = null;
    _lastAt = _closedSince = _lastAccepted = null;
  }

  double _median(Iterable<double?> values) {
    final sorted = values.cast<double>().toList()..sort();
    return sorted[sorted.length ~/ 2];
  }

  StudyDecision classify(FaceObservation sample) {
    if (_lastAt != null && sample.at - _lastAt! > const Duration(seconds: 15)) {
      reset();
    }
    _lastAt = sample.at;
    if (sample.targetIssue != null ||
        sample.count != 1 ||
        !sample.usable ||
        !sample.anglesAvailable) {
      _calibration.clear();
      _closedSince = null;
      _lastAccepted = null;
      return StudyDecision(
        StudyState.unknown,
        sample.targetIssue ??
            (sample.count == 0
                ? '顔を確認できません。顔が映る位置・明るさを調整してください'
                : sample.count > 1
                ? '複数の顔を検出したため判定を保留します'
                : '顔の大きさ・欠け・向きを十分に確認できないため判定保留'),
      );
    }
    if (!calibrated) {
      if (sample.eyesClosed ||
          sample.yaw!.abs() > 45 ||
          sample.pitch!.abs() > 45 ||
          sample.roll!.abs() > 30) {
        _calibration.clear();
        return const StudyDecision(
          StudyState.faceCheck,
          '普段の勉強姿勢で顔を映してください。初期姿勢を再確認します',
          20,
        );
      }
      if (_calibration.isNotEmpty) {
        final first = _calibration.first;
        if ((sample.pitch! - first.pitch!).abs() > 15 ||
            (sample.yaw! - first.yaw!).abs() > 15) {
          _calibration.clear();
        }
      }
      _calibration.add(sample);
      if (_calibration.length < 3 ||
          sample.at - _calibration.first.at < const Duration(seconds: 5)) {
        if (_calibration.length > 3) _calibration.removeAt(1);
        return StudyDecision(
          StudyState.faceCheck,
          '普段の学習姿勢を確認中（${_calibration.length}/3）。カメラを見つめ続ける必要はありません',
          30,
        );
      }
      _pitch = _median(_calibration.map((item) => item.pitch));
      _yaw = _median(_calibration.map((item) => item.yaw));
      _roll = _median(_calibration.map((item) => item.roll));
    }
    final closeToBaseline =
        (sample.pitch! - _pitch!).abs() <= 25 &&
        (sample.yaw! - _yaw!).abs() <= 30 &&
        (sample.roll! - _roll!).abs() <= 25;
    if (!closeToBaseline ||
        sample.yaw!.abs() > 65 ||
        sample.pitch!.abs() > 60) {
      _closedSince = null;
      _lastAccepted = null;
      return const StudyDecision(
        StudyState.faceCheck,
        '初期姿勢から顔の向きが大きく変化：資料を見る動作などの用途は未確認',
        35,
      );
    }
    if (sample.eyesClosed) {
      _closedSince ??= sample.at;
      if (sample.at - _closedSince! >= const Duration(seconds: 8) ||
          _lastAccepted == null ||
          sample.at - _lastAccepted! > const Duration(seconds: 8)) {
        return const StudyDecision(
          StudyState.faceCheck,
          '目を閉じた状態を再確認中（思考・休息・眠気などの区別はできません）',
          40,
        );
      }
      return const StudyDecision(
        StudyState.facePosture,
        '短い閉眼を再確認中：すぐに姿勢継続判定を取り消しません',
        60,
      );
    }
    _closedSince = null;
    _lastAccepted = sample.at;
    final eyesKnown = sample.leftEye != null && sample.rightEye != null;
    return StudyDecision(
      StudyState.facePosture,
      eyesKnown
          ? '顔の向きが初期の学習姿勢に近い状態です。実際の学習・集中は未確認'
          : '顔の向きは初期姿勢に近い状態です。目の開閉は取得できず、学習・集中は未確認',
      eyesKnown ? 80 : 65,
    );
  }
}
