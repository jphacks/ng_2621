import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:ultralytics_yolo/ultralytics_yolo.dart';

import 'detector_engine.dart';
import 'study_session.dart';
import 'face_study.dart';
import 'face_detector_service.dart';
import 'desk_text_detector.dart';
import 'detection_summary.dart';

StudyDetectorEngine createStudyDetectorEngine() => _NativeDetector();

class _NativeDetector extends StudyDetectorEngine {
  final _yolo = YOLO(modelPath: 'yolo26s', task: YOLOTask.detect);
  final _desk = DeskTextDetector();
  final _face = FaceStudyDetector();
  final _deskClassifier = ActivityClassifier();
  final _faceClassifier = FacePostureClassifier();
  List<CameraDescription> _cameras = [];
  CameraDescription? _selected;
  CameraController? _camera;
  bool _modelReady = false;
  bool _cancelled = false;
  int _reacquireSamples = 0;
  @override
  void cancel() {
    _cancelled = true;
  }

  @override
  bool get supported =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;
  @override
  bool get canSwitchCamera => _cameras.length > 1;
  @override
  Widget preview() =>
      _camera == null ? const SizedBox.shrink() : CameraPreview(_camera!);
  @override
  Future<void> initialize() async {
    if (!supported) throw UnsupportedError('勉強判定はAndroid版で利用できます');
    _cancelled = false;
    if (!_modelReady) {
      // Official model download on first use; camera frames stay on this device.
      _modelReady = await _yolo.loadModel();
      if (!_modelReady) throw StateError('教材認識モデルを準備できません。通信を確認してください');
    }
    if (_cancelled) throw StateError('カメラ準備を中止しました');
    _cameras = await availableCameras();
    if (_cameras.isEmpty) throw StateError('カメラがありません');
    _selected ??= _cameras.firstWhere(
      (c) => c.lensDirection == CameraLensDirection.front,
      orElse: () => _cameras.first,
    );
    final camera = CameraController(
      _selected!,
      ResolutionPreset.high,
      enableAudio: false,
    );
    try {
      await camera.initialize();
      if (_cancelled) {
        await camera.dispose();
        return;
      }
      _camera = camera;
    } catch (_) {
      await camera.dispose();
      rethrow;
    }
    await reset();
  }

  @override
  Future<void> switchCamera() async {
    if (!canSwitchCamera) return;
    final index = _cameras.indexOf(_selected!);
    await suspend();
    _selected = _cameras[(index + 1) % _cameras.length];
    await initialize();
  }

  @override
  Future<void> reset() async {
    _deskClassifier.reset();
    _faceClassifier.reset();
    _face.resetTarget();
    _reacquireSamples = 0;
    await _desk.reset();
  }

  @override
  Future<DetectorSample> analyze(Duration at, StudyMode? mode) async {
    final camera = _camera;
    if (camera == null) throw StateError('カメラは停止しています');
    File? image;
    try {
      final picture = await camera.takePicture();
      image = File(picture.path);
      var deskEvidence = false, faceEvidence = false;
      var decision = const StudyDecision(StudyState.unknown, '映り方を確認中');
      if (mode != StudyMode.face) {
        final text = await _desk.analyze(image.path);
        final result = await _yolo.predict(
          text.uprightImage ?? await image.readAsBytes(),
          confidenceThreshold: 0.10,
        );
        final boxes = result['boxes'] as List? ?? [];
        final scores = summarizeDetections(boxes).scores;
        final paper = text.paperOutsideScreens(boxes);
        deskEvidence =
            text.handAvailable &&
            text.hands > 0 &&
            paper.material &&
            paper.nearHand;
        decision = _deskClassifier.classify(
          ActivitySample(
            at,
            paper: paper.material,
            computer: (scores['laptop'] ?? 0) >= .40,
            phone: (scores['cell phone'] ?? 0) >= .35,
            handAvailable: text.handAvailable,
            handNearText: paper.nearHand,
            handMoving: text.handMoving && paper.nearHand,
            recognitionAvailable: text.ocrAvailable && _modelReady,
          ),
        );
      }
      if (mode != StudyMode.desk) {
        final face = await _face.analyze(
          image,
          at,
          region: const Rect.fromLTWH(0, 0, 1, 1),
        );
        faceEvidence = face.detectedCount == 1 && face.observation.usable;
        if (mode == StudyMode.face) {
          // After a tracking gap, reacquire only after three single-face frames.
          // This tracks position, never personal identity.
          _reacquireSamples = face.needsConfirmation && face.detectedCount == 1
              ? _reacquireSamples + 1
              : 0;
          if (_reacquireSamples >= 3) {
            _face.resetTarget();
            _faceClassifier.reset();
            _reacquireSamples = 0;
          }
          decision = face.detectedCount > 1
              ? const StudyDecision(StudyState.unknown, '複数の顔が映っているため判定保留')
              : _faceClassifier.classify(face.observation);
        }
      }
      return DetectorSample(
        face: faceEvidence,
        desk: deskEvidence,
        decision: decision,
      );
    } finally {
      if (image != null && await image.exists()) await image.delete();
    }
  }

  @override
  Future<void> keepAwake(bool enabled) => _desk.keepAwake(enabled);
  @override
  Future<void> suspend() async {
    final camera = _camera;
    _camera = null;
    try {
      if (supported) await keepAwake(false);
    } finally {
      await camera?.dispose();
    }
  }

  @override
  Future<void> close() async {
    await suspend();
    await _face.close();
    await _yolo.dispose();
  }
}
