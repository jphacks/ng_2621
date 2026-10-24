import 'dart:io';

import 'package:flutter/services.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';

import 'desk_text_detector.dart';
import 'face_study.dart';
import 'face_target_tracker.dart';

class FaceStudyResult {
  final DeskTextEvidence frame;
  final List<Rect> boxes;
  final FaceObservation observation;
  final int detectedCount;
  final bool needsConfirmation;
  final String targetStatus;
  const FaceStudyResult(
    this.frame,
    this.boxes,
    this.observation, {
    this.detectedCount = 0,
    this.needsConfirmation = false,
    this.targetStatus = '',
  });
  String get description {
    String angle(double? value) =>
        value == null ? '取得不可' : '${value.toStringAsFixed(1)}°';
    String eye(double? value) =>
        value == null ? '取得不可' : '${(value * 100).toStringAsFixed(0)}%';
    return '解析範囲内：$detectedCount人／対象：${observation.count == 1 ? "1人" : "未確認"}\n'
        '$targetStatus\n上下：${angle(observation.pitch)}／左右：${angle(observation.yaw)}／傾き：${angle(observation.roll)}\n'
        '目の開き：左 ${eye(observation.leftEye)}・右 ${eye(observation.rightEye)}（集中度ではありません）';
  }
}

class FaceStudyDetector {
  static const _channel = MethodChannel('study_detector/desk_text');
  final _locator = FaceDetector(
    options: FaceDetectorOptions(performanceMode: FaceDetectorMode.fast),
  );
  final _detector = FaceDetector(
    options: FaceDetectorOptions(
      performanceMode: FaceDetectorMode.fast,
      enableClassification: true,
      enableLandmarks: false,
      enableTracking: false,
    ),
  );
  final _target = FaceTargetTracker();
  int _generation = 0;
  bool get needsConfirmation => _target.needsConfirmation;
  void resetTarget() {
    _generation++;
    _target.reset();
  }

  void requireConfirmation(String reason) {
    _generation++;
    _target.requireConfirmation(reason);
  }

  void _check(int generation) {
    if (generation != _generation) throw StateError('対象の設定が変わったため結果を破棄します');
  }

  Map<String, double> _map(Rect rect) => {
    'left': rect.left,
    'top': rect.top,
    'right': rect.right,
    'bottom': rect.bottom,
  };

  Future<DeskTextEvidence> _prepare(
    File file, {
    Rect? region,
    List<Rect> masks = const [],
  }) async {
    final data = await _channel.invokeMapMethod<String, dynamic>('prepare', {
      'path': file.path,
      if (region != null) 'region': _map(region),
      if (masks.isNotEmpty) 'masks': masks.map(_map).toList(),
    });
    if (data == null) throw StateError('顔解析用の画像を準備できません');
    final width = (data['imageWidth'] as num).toDouble();
    final height = (data['imageHeight'] as num).toDouble();
    if (!width.isFinite || !height.isFinite || width <= 0 || height <= 0) {
      throw StateError('画像の大きさが不正です');
    }
    return DeskTextEvidence(
      uprightImage: data['imageBytes'] as Uint8List,
      imageSize: Size(width, height),
      ocrAvailable: false,
    );
  }

  // Only used by the region editor. No face model is invoked here.
  Future<DeskTextEvidence> prepareRegionEditor(File file) => _prepare(file);

  Future<FaceStudyResult> analyze(
    File file,
    Duration at, {
    Rect region = defaultFaceRegion,
  }) async {
    final generation = _generation;
    // Crop BEFORE invoking either face model. Out-of-region pixels never enter
    // the face detection service or the normal analysis preview.
    final frame = await _prepare(file, region: validatedFaceRegion(region));
    _check(generation);
    await file.writeAsBytes(frame.uprightImage!, flush: true);
    final faces = await _locator.processImage(
      InputImage.fromFilePath(file.path),
    );
    _check(generation);
    final width = frame.imageSize.width, height = frame.imageSize.height;
    final bounds = faces
        .map(
          (face) => Rect.fromLTRB(
            face.boundingBox.left / width,
            face.boundingBox.top / height,
            face.boundingBox.right / width,
            face.boundingBox.bottom / height,
          ),
        )
        .toList();
    var selection = _target.select(bounds, at);
    Rect? detailRegion;
    if (selection.index != null) {
      final targetBox = bounds[selection.index!];
      for (final margin in [.03, .01, 0.0]) {
        final candidate = targetBox
            .inflate(margin)
            .intersect(const Rect.fromLTWH(0, 0, 1, 1));
        final overlapsOther = bounds.indexed.any(
          (item) =>
              item.$1 != selection.index &&
              !candidate.intersect(item.$2).isEmpty,
        );
        if (!overlapsOther &&
            candidate.width >= .05 &&
            candidate.height >= .05) {
          detailRegion = candidate;
          break;
        }
      }
      if (detailRegion == null) {
        _target.requireConfirmation('対象と別の顔が重なっています。位置を調整して対象を再確認してください');
        selection = FaceTargetSelection(
          null,
          '顔が重なり対象だけを解析できないため保留',
          needsConfirmation: true,
        );
      }
    }
    // Non-target face pixels are replaced in the JPEG BEFORE it reaches the UI.
    final masks = bounds.indexed
        .where((item) => item.$1 != selection.index)
        .map(
          (item) =>
              item.$2.inflate(.03).intersect(const Rect.fromLTWH(0, 0, 1, 1)),
        )
        .where((rect) => !rect.isEmpty)
        .toList();
    final preview = masks.isEmpty ? frame : await _prepare(file, masks: masks);
    _check(generation);
    if (selection.index == null || detailRegion == null) {
      return FaceStudyResult(
        preview,
        const [],
        FaceObservation(at, targetIssue: selection.reason),
        detectedCount: faces.length,
        needsConfirmation: selection.needsConfirmation,
        targetStatus: selection.reason,
      );
    }
    // Obtain pose/eyes only from a second crop that excludes every other
    // detected face. The locator's non-target pose/eye fields are never read.
    final detail = await _prepare(file, region: detailRegion);
    _check(generation);
    await file.writeAsBytes(detail.uprightImage!, flush: true);
    final detailed = await _detector.processImage(
      InputImage.fromFilePath(file.path),
    );
    _check(generation);
    if (detailed.length != 1) {
      _target.requireConfirmation('対象の詳細を確認できません。対象を再確認してください');
      // Do not expose non-target face pixels if the detailed pass is ambiguous.
      final hidden = DeskTextEvidence(
        imageSize: frame.imageSize,
        ocrAvailable: false,
      );
      return FaceStudyResult(
        hidden,
        const [],
        FaceObservation(at, targetIssue: '対象の詳細解析が不確かなため保留'),
        detectedCount: faces.length,
        needsConfirmation: true,
        targetStatus: '対象の詳細を再確認してください',
      );
    }
    final face = detailed.single;
    return FaceStudyResult(
      preview,
      [bounds[selection.index!]],
      FaceObservation(
        at,
        count: 1,
        usable: true,
        pitch: face.headEulerAngleX,
        yaw: face.headEulerAngleY,
        roll: face.headEulerAngleZ,
        leftEye: face.leftEyeOpenProbability,
        rightEye: face.rightEyeOpenProbability,
      ),
      detectedCount: faces.length,
      targetStatus: selection.reason,
    );
  }

  Future<void> close() async {
    await _locator.close();
    await _detector.close();
  }
}
