import 'package:flutter/widgets.dart';

import 'pixel_sprite.dart';
import 'zoo_character_part.dart';

class ZooCharacterSprite extends StatelessWidget {
  const ZooCharacterSprite({
    super.key,
    required this.part,
    this.scale = 2,
    this.semanticLabel,
  }) : assert(scale > 0 && scale < double.infinity);
  static const assetPath = 'assets/sprites/zoo_characters.png';
  static const sheetSize = 64.0;
  final ZooCharacterPart part;
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
