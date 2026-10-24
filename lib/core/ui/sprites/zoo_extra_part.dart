import 'dart:ui';

/// Original 64x64 sheet, divided into 16x16 cells in reading order.
enum ZooExtraPart {
  woodenButtonLeft(Rect.fromLTWH(0, 0, 16, 16)),
  woodenButtonMiddle(Rect.fromLTWH(16, 0, 16, 16)),
  woodenButtonRight(Rect.fromLTWH(32, 0, 16, 16)),
  graySquareButton(Rect.fromLTWH(48, 0, 16, 16)),
  grayRoundButton(Rect.fromLTWH(0, 16, 16, 16)),
  creamSquareButton(Rect.fromLTWH(16, 16, 16, 16)),
  limeButtonLeft(Rect.fromLTWH(32, 16, 16, 16)),
  limeButtonRight(Rect.fromLTWH(48, 16, 16, 16)),
  magnifyingGlass(Rect.fromLTWH(0, 32, 16, 16)),
  brickLeft(Rect.fromLTWH(16, 32, 16, 16)),
  brickMiddle(Rect.fromLTWH(32, 32, 16, 16)),
  brickRight(Rect.fromLTWH(48, 32, 16, 16)),
  fenceVertical(Rect.fromLTWH(0, 48, 16, 16)),
  fenceBottomLeft(Rect.fromLTWH(16, 48, 16, 16)),
  grassWaterQuarter(Rect.fromLTWH(32, 48, 16, 16)),
  grassWaterHalf(Rect.fromLTWH(48, 48, 16, 16));

  const ZooExtraPart(this.sourceRect);
  final Rect sourceRect;
}
