import 'package:flutter/widgets.dart';

import 'pixel_sprite.dart';
import 'zoo_art_part.dart';

class ZooArtSprite extends StatelessWidget {
  const ZooArtSprite({
    super.key,
    required this.part,
    this.scale = 2,
    this.semanticLabel,
  }) : assert(scale > 0 && scale < double.infinity);
  static const assetPath = 'assets/sprites/20261024_2.png';
  static const sheetSize = 64.0;
  final ZooArtPart part;
  final double scale;
  final String? semanticLabel;
  @override
  Widget build(BuildContext context) => PixelSprite(
    assetPath: assetPath,
    sourceRect: part.sourceRect,
    scale: scale,
    semanticLabel: semanticLabel,
  );
}
