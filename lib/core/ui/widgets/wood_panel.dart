import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import 'sprite_panel.dart';
import 'color_button_panel.dart';
import 'pixel_text_outline.dart';
import '../sprites/sprite_sheet_image.dart';
import '../sprites/zoo_ui_part.dart';
import '../sprites/zoo_ui_sprite.dart';

/// Joins the supplied left/middle/right artwork; borders keep their pixel size.
class WoodPanel extends StatelessWidget {
  const WoodPanel({super.key, required this.child, this.originalSheet = false});
  final bool originalSheet;
  final Widget child;
  @override
  Widget build(BuildContext context) => originalSheet
      ? SpriteSheetImage(
          assetPath: ZooUiSprite.assetPath,
          builder: (context, image) => CustomPaint(
            painter: _OriginalWoodPainter(image),
            child: PixelTextOutline(child: child),
          ),
        )
      : SpritePanel(style: SpritePanelStyle.wood, child: child);
}

/// Legacy API; actionable surfaces now use the colorful button atlas.
class WoodButton extends StatefulWidget {
  const WoodButton({super.key, required this.onPressed, required this.child});
  final VoidCallback? onPressed;
  final Widget child;
  @override
  State<WoodButton> createState() => _WoodButtonState();
}

class _WoodButtonState extends State<WoodButton> {
  bool _pressed = false;
  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    enabled: widget.onPressed != null,
    child: AnimatedScale(
      scale: _pressed && !MediaQuery.disableAnimationsOf(context) ? 0.98 : 1,
      duration: MediaQuery.disableAnimationsOf(context)
          ? Duration.zero
          : const Duration(milliseconds: 90),
      child: ColorButtonPanel(
        enabled: widget.onPressed != null,
        pressed: _pressed,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: widget.onPressed,
            onHighlightChanged: (pressed) => setState(() => _pressed = pressed),
            borderRadius: BorderRadius.circular(8),
            child: ConstrainedBox(
              constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                child: DefaultTextStyle.merge(
                  style: const TextStyle(
                    color: Color(0xFF4D321F),
                    fontWeight: FontWeight.w800,
                  ),
                  child: widget.child,
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

class _OriginalWoodPainter extends CustomPainter {
  _OriginalWoodPainter(this.image);
  final ui.Image? image;
  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final image = this.image;
    if (image == null) {
      canvas.drawRect(
        Offset.zero & size,
        Paint()..color = const Color(0xFFE5C17A),
      );
      return;
    }
    final paint = Paint()
      ..isAntiAlias = false
      ..filterQuality = FilterQuality.none;
    final cap = math.min(22.0, size.width / 2);
    final border = math.min(6.0, size.height / 2);
    void piece(Rect source, Rect dest) {
      final src = [
        Rect.fromLTWH(source.left, source.top, source.width, 3),
        Rect.fromLTWH(
          source.left,
          source.top + 3,
          source.width,
          source.height - 6,
        ),
        Rect.fromLTWH(source.left, source.bottom - 3, source.width, 3),
      ];
      final dst = [
        Rect.fromLTWH(dest.left, 0, dest.width, border),
        Rect.fromLTWH(
          dest.left,
          border,
          dest.width,
          math.max(0, size.height - 2 * border),
        ),
        Rect.fromLTWH(dest.left, size.height - border, dest.width, border),
      ];
      for (var i = 0; i < 3; i++) {
        if (!dst[i].isEmpty) canvas.drawImageRect(image, src[i], dst[i], paint);
      }
    }

    canvas.save();
    canvas.clipRect(Offset.zero & size);
    piece(
      ZooUiPart.woodenButtonLeft.sourceRect,
      Rect.fromLTWH(0, 0, cap, size.height),
    );
    piece(
      ZooUiPart.woodenButtonRight.sourceRect,
      Rect.fromLTWH(size.width - cap, 0, cap, size.height),
    );
    canvas.save();
    canvas.clipRect(
      Rect.fromLTWH(cap, 0, math.max(0, size.width - 2 * cap), size.height),
    );
    for (var x = cap; x < size.width - cap; x += 18) {
      piece(
        ZooUiPart.woodenButtonMiddle.sourceRect,
        Rect.fromLTWH(x, 0, 18, size.height),
      );
    }
    canvas.restore();
    canvas.restore();
  }

  @override
  bool shouldRepaint(_OriginalWoodPainter old) => old.image != image;
}
