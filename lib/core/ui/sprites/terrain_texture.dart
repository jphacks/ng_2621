import 'dart:ui' as ui;

import 'package:flutter/widgets.dart';

import 'sprite_sheet_image.dart';
import 'terrain_part.dart';
import 'terrain_sprite.dart';

/// Repeats the opaque pattern area without the sheet's transparent gutter.
class TerrainTexture extends StatelessWidget {
  const TerrainTexture({
    super.key,
    required this.child,
    this.part = TerrainPart.creamPattern,
    this.scale = 2,
    this.opacity = 0.14,
    this.backgroundColor = const Color(0xFFFAF9F0),
  }) : assert(scale > 0),
       assert(opacity >= 0 && opacity <= 1);
  final Widget child;
  final TerrainPart part;
  final double scale;
  final double opacity;
  final Color backgroundColor;
  @override
  Widget build(BuildContext context) => ColoredBox(
    color: backgroundColor,
    child: SpriteSheetImage(
      assetPath: TerrainSprite.assetPath,
      builder: (context, image) => CustomPaint(
        painter: _PatternPainter(image, part, scale, opacity),
        child: child,
      ),
    ),
  );
}

class _PatternPainter extends CustomPainter {
  _PatternPainter(this.image, this.part, this.scale, this.opacity);
  final ui.Image? image;
  final TerrainPart part;
  final double scale, opacity;
  @override
  void paint(Canvas canvas, Size size) {
    final image = this.image;
    if (image == null) return;
    final source = part.sourceRect;
    final paint = Paint()
      ..filterQuality = FilterQuality.none
      ..isAntiAlias = false
      ..color = Color.fromRGBO(255, 255, 255, opacity);
    canvas.save();
    canvas.clipRect(Offset.zero & size);
    for (var y = 0.0; y < size.height; y += source.height * scale) {
      for (var x = 0.0; x < size.width; x += source.width * scale) {
        canvas.drawImageRect(
          image,
          source,
          Rect.fromLTWH(x, y, source.width * scale, source.height * scale),
          paint,
        );
      }
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(_PatternPainter old) =>
      old.image != image ||
      old.part != part ||
      old.scale != scale ||
      old.opacity != opacity;
}
