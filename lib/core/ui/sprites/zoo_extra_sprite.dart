import 'package:flutter/widgets.dart';

import 'pixel_sprite.dart';
import 'zoo_extra_part.dart';

/// Keeps transparent cell padding so terrain and button segments join at 16px.
class ZooExtraSprite extends StatelessWidget {
  const ZooExtraSprite({
    super.key,
    required this.part,
    this.scale = 2,
    this.quarterTurns = 0,
    this.mirrorX = false,
    this.semanticLabel,
  });
  static const assetPath = 'assets/sprites/20261024_3.png';
  static const sheetSize = 64.0;
  final ZooExtraPart part;
  final double scale;
  final int quarterTurns;
  final bool mirrorX;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) => RotatedBox(
    quarterTurns: quarterTurns,
    child: Transform.flip(
      flipX: mirrorX,
      child: PixelSprite(
        assetPath: assetPath,
        sourceRect: part.sourceRect,
        scale: scale,
        semanticLabel: semanticLabel,
      ),
    ),
  );
}
