import 'package:flutter/widgets.dart';

import 'pixel_sprite.dart';
import 'zoo_ui_part.dart';

/// Original UI sheet. Existing callers retain the same API.
class ZooUiSprite extends StatelessWidget {
  const ZooUiSprite({
    super.key,
    required this.part,
    this.scale = 3,
    this.semanticLabel,
  }) : assert(scale > 0 && scale < double.infinity);
  static const assetPath = 'assets/ui/zooStudyUI.png';
  static const sheetSize = 64.0;
  final ZooUiPart part;
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
