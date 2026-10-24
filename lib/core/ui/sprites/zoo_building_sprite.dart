import 'package:flutter/widgets.dart';

import 'pixel_sprite.dart';

/// Source cells retain transparent padding for consistent placement footprints.
enum ZooBuildingPart {
  creamRoundFrame(Rect.fromLTWH(0, 0, 32, 16)),
  laboratory(Rect.fromLTWH(32, 0, 32, 32)),
  bench(Rect.fromLTWH(0, 16, 16, 16)),
  topiary(Rect.fromLTWH(16, 16, 16, 16)),
  fountain(Rect.fromLTWH(0, 32, 32, 32)),
  flowerArch(Rect.fromLTWH(32, 32, 32, 32));

  const ZooBuildingPart(this.sourceRect);
  final Rect sourceRect;

  static ZooBuildingPart? forId(String? id) {
    for (final part in values) {
      if (part.name == id && part != creamRoundFrame) return part;
    }
    return null;
  }
}

class ZooBuildingSprite extends StatelessWidget {
  const ZooBuildingSprite({
    super.key,
    required this.part,
    this.scale = 2,
    this.semanticLabel,
  });
  static const assetPath = 'assets/sprites/zoo_buildings.png';
  final ZooBuildingPart part;
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
