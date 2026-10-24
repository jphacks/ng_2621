import 'package:flutter/services.dart';

class TextRegion {
  final Rect bounds;
  final int lines;
  final int characters;
  const TextRegion(this.bounds, this.lines, this.characters);
}

class PaperEvidence {
  final bool material;
  final bool nearHand;
  final List<TextRegion> regions;
  final List<Rect> books;
  const PaperEvidence(
    this.material,
    this.nearHand, [
    this.regions = const [],
    this.books = const [],
  ]);
}

class DeskTextEvidence {
  final int lines;
  final int characters;
  final double areaRatio;
  final bool ocrAvailable;
  final bool handAvailable;
  final int hands;
  final bool handNearText;
  final bool handMoving;
  final String error;
  final Uint8List? uprightImage;
  final List<TextRegion> regions;
  final List<Offset> handPoints;
  final List<List<Offset>> handLandmarks;
  final Size imageSize;

  const DeskTextEvidence({
    this.lines = 0,
    this.characters = 0,
    this.areaRatio = 0,
    this.ocrAvailable = true,
    this.handAvailable = false,
    this.hands = 0,
    this.handNearText = false,
    this.handMoving = false,
    this.error = '',
    this.uprightImage,
    this.regions = const [],
    this.handPoints = const [],
    this.handLandmarks = const [],
    this.imageSize = const Size(1, 1),
  });

  bool get hasMaterial =>
      ocrAvailable && lines >= 3 && characters >= 24 && areaRatio >= 0.008;

  PaperEvidence paperOutsideScreens(List<dynamic> boxes) {
    final screens = <Rect>[];
    final books = <Rect>[];
    Rect? boxBounds(Map raw) {
      if (![
        'x1_norm',
        'y1_norm',
        'x2_norm',
        'y2_norm',
      ].every((key) => raw[key] is num && (raw[key] as num).isFinite)) {
        return null;
      }
      final bounds = Rect.fromLTRB(
        (raw['x1_norm'] as num).toDouble(),
        (raw['y1_norm'] as num).toDouble(),
        (raw['x2_norm'] as num).toDouble(),
        (raw['y2_norm'] as num).toDouble(),
      ).intersect(const Rect.fromLTWH(0, 0, 1, 1));
      return bounds.isEmpty ? null : bounds;
    }

    for (final raw in boxes) {
      if (raw is! Map) continue;
      final name = (raw['className'] ?? raw['class']).toString().toLowerCase();
      final score = (raw['confidence'] as num? ?? 0).toDouble();
      if (name == 'book' && score >= 0.30) {
        final bounds = boxBounds(raw);
        if (bounds != null && bounds.width * bounds.height >= 0.015) {
          books.add(bounds);
        }
      }
      if (!((name == 'cell phone' && score >= 0.35) ||
          (name == 'laptop' && score >= 0.40))) {
        continue;
      }
      if ([
        'x1_norm',
        'y1_norm',
        'x2_norm',
        'y2_norm',
      ].every((key) => raw[key] is num)) {
        screens.add(
          Rect.fromLTRB(
            (raw['x1_norm'] as num).toDouble(),
            (raw['y1_norm'] as num).toDouble(),
            (raw['x2_norm'] as num).toDouble(),
            (raw['y2_norm'] as num).toDouble(),
          ).inflate(0.02),
        );
      } else {
        // Missing spatial data cannot justify treating screen text as paper.
        return const PaperEvidence(false, false);
      }
    }
    books.removeWhere(
      (book) => screens.any((screen) {
        final overlap = screen.intersect(book);
        return screen.contains(book.center) ||
            (!overlap.isEmpty &&
                overlap.width * overlap.height / (book.width * book.height) >
                    0.25);
      }),
    );
    final paper = regions.where((region) {
      return !screens.any((screen) {
        final intersection = screen.intersect(region.bounds);
        final regionArea = region.bounds.width * region.bounds.height;
        final overlap = intersection.isEmpty
            ? 0.0
            : intersection.width * intersection.height;
        return screen.contains(region.bounds.center) ||
            (regionArea > 0 && overlap / regionArea > 0.25);
      });
    }).toList();
    final lines = paper.fold(0, (sum, item) => sum + item.lines);
    final characters = paper.fold(0, (sum, item) => sum + item.characters);
    final area = paper.fold(
      0.0,
      (sum, item) => sum + item.bounds.width * item.bounds.height,
    );
    final material =
        books.isNotEmpty ||
        (ocrAvailable && lines >= 3 && characters >= 24 && area >= 0.008);
    // Use all hand joints, not just an index fingertip that may hide text.
    // OCR may split handwriting into single-line blocks; the overall material
    // threshold still applies before testing proximity to any useful block.
    final points = handLandmarks.isEmpty
        ? handPoints
        : handLandmarks.expand((hand) => hand).toList();
    final near =
        material &&
        points.any(
          (point) =>
              !screens.any((screen) => screen.contains(point)) &&
              (books.any((book) => book.inflate(0.05).contains(point)) ||
                  paper.any(
                    (region) =>
                        region.lines >= 1 &&
                        region.characters >= 2 &&
                        region.bounds.inflate(0.12).contains(point),
                  )),
        );
    // A hand can straddle the book edge even when its individual joints fall
    // outside the small margin. Require meaningful hand-area overlap.
    final overlapNear =
        material &&
        handLandmarks.any((hand) {
          final usable = hand
              .where(
                (point) => !screens.any((screen) => screen.contains(point)),
              )
              .toList();
          if (usable.length < 3) return false;
          var left = usable.first.dx,
              right = left,
              top = usable.first.dy,
              bottom = top;
          for (final point in usable) {
            if (point.dx < left) left = point.dx;
            if (point.dx > right) right = point.dx;
            if (point.dy < top) top = point.dy;
            if (point.dy > bottom) bottom = point.dy;
          }
          final handArea = Rect.fromLTRB(left, top, right, bottom);
          final area = handArea.width * handArea.height;
          return area > 0 &&
              books.any((book) {
                final overlap = handArea.intersect(book.inflate(0.03));
                return !overlap.isEmpty &&
                    overlap.width * overlap.height / area >= 0.15;
              });
        });
    return PaperEvidence(
      material,
      near || overlapNear,
      paper,
      List.unmodifiable(books),
    );
  }
}

class DeskTextDetector {
  static const _channel = MethodChannel('study_detector/desk_text');

  Future<void> keepAwake(bool enabled) =>
      _channel.invokeMethod<void>('keepAwake', {'enabled': enabled});

  Future<void> reset() => _channel.invokeMethod<void>('reset');

  Future<DeskTextEvidence> analyze(String path) async {
    final result = await _channel.invokeMapMethod<String, dynamic>('analyze', {
      'path': path,
    });
    if (result == null) throw StateError('認識の結果がありません');
    return DeskTextEvidence(
      lines: (result['lines'] as num).toInt(),
      characters: (result['characters'] as num).toInt(),
      areaRatio: (result['areaRatio'] as num).toDouble(),
      ocrAvailable: result['ocrAvailable'] == true,
      handAvailable: result['handAvailable'] == true,
      hands: (result['hands'] as num? ?? 0).toInt(),
      handNearText: result['handNearText'] == true,
      handMoving: result['handMoving'] == true,
      error: [
        result['ocrError'],
        result['handError'],
      ].whereType<String>().join('\n'),
      uprightImage: result['imageBytes'] as Uint8List?,
      imageSize: Size(
        (result['imageWidth'] as num? ?? 1).toDouble(),
        (result['imageHeight'] as num? ?? 1).toDouble(),
      ),
      handLandmarks: (result['handLandmarks'] as List? ?? [])
          .whereType<List>()
          .map(
            (hand) => hand
                .whereType<Map>()
                .map(
                  (point) => Offset(
                    (point['x'] as num).toDouble(),
                    (point['y'] as num).toDouble(),
                  ),
                )
                .toList(),
          )
          .toList(),
      regions: (result['textBlocks'] as List? ?? [])
          .whereType<Map>()
          .map(
            (item) => TextRegion(
              Rect.fromLTRB(
                (item['left'] as num).toDouble(),
                (item['top'] as num).toDouble(),
                (item['right'] as num).toDouble(),
                (item['bottom'] as num).toDouble(),
              ),
              (item['lines'] as num).toInt(),
              (item['characters'] as num).toInt(),
            ),
          )
          .toList(),
      handPoints: (result['handPoints'] as List? ?? [])
          .whereType<Map>()
          .map(
            (item) => Offset(
              (item['x'] as num).toDouble(),
              (item['y'] as num).toDouble(),
            ),
          )
          .toList(),
    );
  }
}
