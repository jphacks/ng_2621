import 'package:flutter/widgets.dart';

import 'pixel_sprite.dart';
import 'terrain_part.dart';

class TerrainSprite extends StatelessWidget {
  const TerrainSprite({
    super.key,
    required this.part,
    this.scale = 2,
    this.quarterTurns = 0,
    this.mirrorX = false,
  });
  static const assetPath = 'assets/sprites/20261023.png';
  static const sheetSize = 64.0;
  final TerrainPart part;
  final double scale;
  final int quarterTurns;
  final bool mirrorX;
  @override
  Widget build(BuildContext context) => RotatedBox(
    quarterTurns: quarterTurns,
    child: Transform.flip(
      flipX: mirrorX,
      child: PixelSprite(
        assetPath: assetPath,
        sourceRect: part.sourceRect,
        scale: scale,
      ),
    ),
  );
}
