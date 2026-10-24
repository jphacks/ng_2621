import 'dart:ui';

/// Source rectangles in the original 64x64 sprite sheet (pixel coordinates).
/// Currency slots intentionally have no gameplay meaning assigned yet.
enum ZooUiPart {
  currency1(Rect.fromLTWH(1, 1, 8, 8)),
  currency2(Rect.fromLTWH(10, 1, 8, 8)),
  currency3(Rect.fromLTWH(19, 1, 8, 8)),
  currency4(Rect.fromLTWH(28, 1, 8, 8)),
  currency5(Rect.fromLTWH(37, 1, 8, 8)),
  currency6(Rect.fromLTWH(46, 1, 8, 8)),
  currency7(Rect.fromLTWH(55, 1, 8, 8)),
  cross(Rect.fromLTWH(1, 10, 11, 11)),
  check(Rect.fromLTWH(13, 11, 12, 10)),
  exclamation(Rect.fromLTWH(26, 10, 4, 11)),
  dot(Rect.fromLTWH(31, 14, 4, 4)),
  smile(Rect.fromLTWH(36, 10, 11, 11)),
  cry(Rect.fromLTWH(48, 10, 11, 11)),
  sickness(Rect.fromLTWH(1, 22, 11, 11)),
  anger(Rect.fromLTWH(13, 22, 11, 11)),
  woodenButtonLeft(Rect.fromLTWH(26, 22, 11, 11)),
  woodenButtonMiddle(Rect.fromLTWH(38, 22, 9, 11)),
  woodenButtonRight(Rect.fromLTWH(48, 22, 11, 11)),
  lock(Rect.fromLTWH(2, 34, 9, 10)),
  back(Rect.fromLTWH(13, 34, 10, 10)),
  arrowLeft(Rect.fromLTWH(24, 35, 9, 7)),
  arrowRight(Rect.fromLTWH(34, 35, 9, 7)),
  encyclopediaRed(Rect.fromLTWH(44, 35, 8, 9)),
  encyclopediaBlue(Rect.fromLTWH(53, 35, 8, 9)),
  cylinder(Rect.fromLTWH(2, 45, 9, 18)),
  cylinderGauge(Rect.fromLTWH(12, 46, 7, 16)),
  plus(Rect.fromLTWH(20, 46, 7, 7)),
  minus(Rect.fromLTWH(20, 54, 7, 7)),
  sliderLeft(Rect.fromLTWH(29, 46, 8, 3)),
  sliderMiddle(Rect.fromLTWH(38, 46, 9, 3)),
  sliderRight(Rect.fromLTWH(48, 46, 8, 3)),
  sliderThumb(Rect.fromLTWH(30, 50, 6, 6)),
  speechBubble(Rect.fromLTWH(38, 50, 17, 13));

  const ZooUiPart(this.sourceRect);

  final Rect sourceRect;
}
