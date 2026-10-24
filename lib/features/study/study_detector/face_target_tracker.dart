import 'package:flutter/services.dart';

const defaultFaceRegion = Rect.fromLTRB(.18, .06, .82, .94);

Rect validatedFaceRegion(Rect region) {
  if (![
        region.left,
        region.top,
        region.right,
        region.bottom,
      ].every((value) => value.isFinite) ||
      region.left < 0 ||
      region.top < 0 ||
      region.right > 1 ||
      region.bottom > 1 ||
      region.width < .05 ||
      region.height < .05) {
    throw ArgumentError('解析範囲が不正です');
  }
  return region;
}

Rect mirrorFaceRegion(Rect region) =>
    Rect.fromLTRB(1 - region.right, region.top, 1 - region.left, region.bottom);

class FaceTargetSelection {
  final int? index;
  final String reason;
  final bool needsConfirmation;
  const FaceTargetSelection(
    this.index,
    this.reason, {
    this.needsConfirmation = false,
  });
}

// Position/size continuity only: no biometric template or identity matching.
class FaceTargetTracker {
  Rect? _target;
  Duration? _lastAt;
  bool _blocked = false;
  String _blockReason = '';
  bool get needsConfirmation => _blocked;

  void reset() {
    _target = null;
    _lastAt = null;
    _blocked = false;
    _blockReason = '';
  }

  void requireConfirmation(String reason) {
    _blocked = true;
    _blockReason = reason;
  }

  FaceTargetSelection _block(String reason) {
    requireConfirmation(reason);
    return FaceTargetSelection(null, reason, needsConfirmation: true);
  }

  bool _usable(Rect bounds) {
    final area = bounds.width * bounds.height;
    return !bounds.isEmpty &&
        [
          bounds.left,
          bounds.top,
          bounds.right,
          bounds.bottom,
        ].every((value) => value.isFinite) &&
        area >= .025 &&
        area <= .85 &&
        bounds.left >= -.03 &&
        bounds.top >= -.03 &&
        bounds.right <= 1.03 &&
        bounds.bottom <= 1.03;
  }

  double _iou(Rect a, Rect b) {
    final overlap = a.intersect(b);
    if (overlap.isEmpty) return 0;
    final intersection = overlap.width * overlap.height;
    return intersection /
        (a.width * a.height + b.width * b.height - intersection);
  }

  FaceTargetSelection select(List<Rect> boxes, Duration at) {
    if (_blocked) {
      return FaceTargetSelection(null, _blockReason, needsConfirmation: true);
    }
    final candidates = <({int index, double score})>[];
    if (_target == null) {
      var maxArea = 0.0;
      for (final box in boxes.where(_usable)) {
        final area = box.width * box.height;
        if (area > maxArea) maxArea = area;
      }
      for (var index = 0; index < boxes.length; index++) {
        final box = boxes[index];
        if (!_usable(box)) continue;
        final centered =
            (1 - (box.center - const Offset(.5, .5)).distance / .707).clamp(
              0.0,
              1.0,
            );
        candidates.add((
          index: index,
          score: .65 * box.width * box.height / maxArea + .35 * centered,
        ));
      }
      candidates.sort((a, b) => b.score.compareTo(a.score));
      if (candidates.isEmpty) {
        return const FaceTargetSelection(null, '解析範囲内に十分な大きさの顔を確認できません');
      }
      if (candidates.length > 1 &&
          candidates.first.score - candidates[1].score < .12) {
        return const FaceTargetSelection(
          null,
          '対象候補が同程度です。解析範囲を狭めるか位置を調整してください',
        );
      }
    } else {
      if (_lastAt != null && at - _lastAt! > const Duration(seconds: 12)) {
        return _block('観測が途切れたため対象を再確認してください');
      }
      final old = _target!;
      for (var index = 0; index < boxes.length; index++) {
        final box = boxes[index];
        if (!_usable(box)) continue;
        final distance = (box.center - old.center).distance;
        final scale = box.width * box.height / (old.width * old.height);
        final overlap = _iou(old, box);
        if (scale < .5 ||
            scale > 2 ||
            distance > .22 ||
            (overlap < .15 && distance > .10)) {
          continue;
        }
        final score =
            .6 * overlap +
            .3 * (1 - distance / .22) +
            .1 * (scale < 1 ? scale : 1 / scale);
        candidates.add((index: index, score: score));
      }
      candidates.sort((a, b) => b.score.compareTo(a.score));
      if (candidates.isEmpty) return _block('対象の顔を見失いました。別の顔へ切り替えず保留しています');
      if (candidates.length > 1 &&
          candidates.first.score - candidates[1].score < .15) {
        return _block('対象の顔を区別できません。「対象を再確認」で選び直してください');
      }
    }
    final index = candidates.first.index;
    _target = boxes[index];
    _lastAt = at;
    return FaceTargetSelection(index, '位置・大きさの連続性から対象の顔を確認');
  }
}
