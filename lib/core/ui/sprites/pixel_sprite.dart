import 'dart:ui' as ui;

import 'package:flutter/widgets.dart';

import 'sprite_sheet_image.dart';

class PixelSprite extends StatelessWidget {
  const PixelSprite({
    super.key,
    required this.assetPath,
    required this.sourceRect,
    this.scale = 3,
    this.semanticLabel,
  }) : assert(scale > 0 && scale < double.infinity);
  final String assetPath;
  final Rect sourceRect;
  final double scale;
  final String? semanticLabel;
  @override
  Widget build(BuildContext context) => SpriteSheetImage(
    assetPath: assetPath,
    builder: (context, image) => Semantics(
      label: semanticLabel,
      image: true,
      excludeSemantics: true,
      child: SizedBox(
        width: sourceRect.width * scale,
        height: sourceRect.height * scale,
        child: CustomPaint(painter: _SpritePainter(image, sourceRect)),
      ),
    ),
  );
}

class _SpritePainter extends CustomPainter {
  _SpritePainter(this.image, this.sourceRect);

  final ui.Image? image;
  final Rect sourceRect;

  @override
  void paint(Canvas canvas, Size size) {
    final image = this.image;
    if (image == null) return;
    canvas.drawImageRect(
      image,
      sourceRect,
      Offset.zero & size,
      Paint()
        ..filterQuality = FilterQuality.none
        ..isAntiAlias = false,
    );
  }

  @override
  bool shouldRepaint(_SpritePainter oldDelegate) =>
      oldDelegate.image != image || oldDelegate.sourceRect != sourceRect;
}
