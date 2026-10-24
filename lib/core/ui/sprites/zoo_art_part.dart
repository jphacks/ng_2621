import 'dart:ui';

/// The second user-supplied sheet. Bird order is left-to-right, top-to-bottom.
enum ZooArtPart {
  bookAndPen(Rect.fromLTWH(1, 2, 14, 13)),
  home(Rect.fromLTWH(17, 1, 14, 14)),
  shop(Rect.fromLTWH(33, 1, 14, 14)),
  coins(Rect.fromLTWH(51, 2, 11, 13)),
  deer(Rect.fromLTWH(2, 17, 11, 12)),
  rabbit(Rect.fromLTWH(19, 19, 9, 9)),
  penguin(Rect.fromLTWH(38, 20, 5, 8)),
  monkey(Rect.fromLTWH(50, 20, 11, 7)),
  bird1(Rect.fromLTWH(0, 31, 7, 7)),
  bird2(Rect.fromLTWH(9, 33, 6, 4)),
  bird3(Rect.fromLTWH(0, 38, 7, 4)),
  bird4(Rect.fromLTWH(9, 38, 6, 4)),
  bird5(Rect.fromLTWH(0, 43, 7, 4)),
  bird6(Rect.fromLTWH(9, 43, 6, 4)),
  rhino(Rect.fromLTWH(18, 37, 11, 7)),
  fox(Rect.fromLTWH(34, 36, 10, 8)),
  evolvedFox(Rect.fromLTWH(51, 36, 11, 8)),
  giraffe(Rect.fromLTWH(2, 51, 8, 10)),
  elephant(Rect.fromLTWH(17, 52, 15, 10)),
  pond(Rect.fromLTWH(33, 51, 15, 12)),
  tree(Rect.fromLTWH(52, 51, 9, 12));

  const ZooArtPart(this.sourceRect);
  final Rect sourceRect;
}
