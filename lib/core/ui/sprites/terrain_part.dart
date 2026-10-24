import 'dart:ui';

/// Preserve 16x16 fence cells for connection alignment; patterns omit padding.
enum TerrainPart {
  grass(Rect.fromLTWH(0, 0, 16, 16)),
  grassQuarterDirt(Rect.fromLTWH(16, 0, 16, 16)),
  grassHalfDirt(Rect.fromLTWH(32, 0, 16, 16)),
  grassQuarterStone(Rect.fromLTWH(48, 0, 16, 16)),
  fenceEnd(Rect.fromLTWH(0, 16, 16, 16)),
  fenceGate(Rect.fromLTWH(16, 16, 16, 16)),
  fence(Rect.fromLTWH(32, 16, 16, 16)),
  grassHalfStone(Rect.fromLTWH(48, 16, 16, 16)),
  bluePattern(Rect.fromLTWH(0, 32, 15, 15)),
  water(Rect.fromLTWH(16, 32, 16, 16)),
  dirt(Rect.fromLTWH(32, 32, 16, 16)),
  stone(Rect.fromLTWH(48, 32, 16, 16)),
  greenPattern(Rect.fromLTWH(0, 48, 15, 15)),
  brownStripe(Rect.fromLTWH(16, 48, 15, 15)),
  woodPattern(Rect.fromLTWH(32, 48, 15, 15)),
  creamPattern(Rect.fromLTWH(48, 48, 15, 15));

  const TerrainPart(this.sourceRect);
  final Rect sourceRect;
}
