import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/widgets.dart';

import '../sprites/sprite_sheet_image.dart';
import 'pixel_text_outline.dart';

enum ButtonPalette { yellow, green, cyan, orange, pink, blue, white, gray }

/// The supplied 64px sheet has eight normal/pressed pairs in reading order.
/// Crop transparent top/bottom rows before slicing to avoid holes in tall buttons.
class ColorButtonPanel extends StatelessWidget {
  const ColorButtonPanel({
    super.key,
    required this.child,
    this.palette = ButtonPalette.cyan,
    this.pressed = false,
    this.enabled = true,
  });
  static const assetPath = 'assets/sprites/color_buttons.png';
  final Widget child;
  final ButtonPalette palette;
  final bool pressed, enabled;

  static Rect sourceRect(ButtonPalette palette, {bool pressed = false}) {
    final row = palette.index ~/ 2,
        column = (palette.index % 2) * 2 + (pressed ? 1 : 0);
    final top = pressed ? (row < 2 ? 3 : 2) : 0;
    final height = pressed ? 13 : (row == 3 ? 15 : 16);
    return Rect.fromLTWH(
      column * 16.0,
      row * 16.0 + top,
      16,
      height.toDouble(),
    );
  }

  @override
  Widget build(BuildContext context) => SpriteSheetImage(
    assetPath: assetPath,
    builder: (context, image) => CustomPaint(
      painter: _ButtonPainter(
        image,
        sourceRect(
          enabled ? palette : ButtonPalette.gray,
          pressed: enabled && pressed,
        ),
        enabled && pressed,
      ),
      child: Transform.translate(
        offset: Offset(0, enabled && pressed ? 2 : 0),
        child: PixelTextOutline(
          lightText:
              !enabled ||
              palette == ButtonPalette.blue ||
              palette == ButtonPalette.gray,
          child: child,
        ),
      ),
    ),
  );
}

class _ButtonPainter extends CustomPainter {
  _ButtonPainter(this.image, this.source, this.pressed);
  final ui.Image? image;
  final Rect source;
  final bool pressed;
  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final image = this.image;
    if (image == null) {
      canvas.drawRect(
        Offset.zero & size,
        Paint()..color = const Color(0xFFCBECF0),
      );
      return;
    }
    final top = pressed ? 2.0 : 0.0;
    const edge = 4.0;
    // The released sprite has a two-pixel plinth plus its lower rim and
    // rounded corners. Keep all seven lower rows OUT of the repeated body.
    // Pressed art has no plinth and retains its existing four-row cap.
    final bottomEdge = pressed ? 4.0 : 7.0;
    final dx = math.min(8.0, size.width / 2);
    final availableHeight = math.max(0.0, size.height - top);
    final capScale = math.min(2.0, availableHeight / (edge + bottomEdge));
    final topHeight = edge * capScale, bottomHeight = bottomEdge * capScale;
    final sx = [
      source.left,
      source.left + edge,
      source.right - edge,
      source.right,
    ];
    final sy = [
      source.top,
      source.top + edge,
      source.bottom - bottomEdge,
      source.bottom,
    ];
    final tx = [0.0, dx, size.width - dx, size.width];
    final ty = [top, top + topHeight, size.height - bottomHeight, size.height];
    final paint = Paint()
      ..filterQuality = FilterQuality.none
      ..isAntiAlias = false;
    for (var row = 0; row < 3; row++) {
      for (var col = 0; col < 3; col++) {
        final from = Rect.fromLTRB(sx[col], sy[row], sx[col + 1], sy[row + 1]);
        final to = Rect.fromLTRB(tx[col], ty[row], tx[col + 1], ty[row + 1]);
        if (to.isEmpty) continue;
        canvas.save();
        canvas.clipRect(to, doAntiAlias: false);
        final w = col == 1 ? from.width * 2 : to.width,
            h = row == 1 ? from.height * 2 : to.height;
        for (var y = to.top; y < to.bottom; y += h) {
          for (var x = to.left; x < to.right; x += w) {
            canvas.drawImageRect(image, from, Rect.fromLTWH(x, y, w, h), paint);
          }
        }
        canvas.restore();
      }
    }
  }

  @override
  bool shouldRepaint(_ButtonPainter old) =>
      old.image != image || old.source != source || old.pressed != pressed;
}

/// For existing InkWell-based cards. Standard buttons use WidgetState.pressed.
class ColorActionPanel extends StatefulWidget {
  const ColorActionPanel({
    super.key,
    required this.child,
    this.palette = ButtonPalette.cyan,
    this.enabled = true,
  });
  final Widget child;
  final ButtonPalette palette;
  final bool enabled;
  @override
  State<ColorActionPanel> createState() => _ColorActionPanelState();
}

class _ColorActionPanelState extends State<ColorActionPanel> {
  bool _pressed = false;
  @override
  Widget build(BuildContext context) => Listener(
    onPointerDown: (_) {
      if (widget.enabled) setState(() => _pressed = true);
    },
    onPointerUp: (_) {
      if (mounted) setState(() => _pressed = false);
    },
    onPointerCancel: (_) {
      if (mounted) setState(() => _pressed = false);
    },
    child: ColorButtonPanel(
      palette: widget.palette,
      enabled: widget.enabled,
      pressed: _pressed,
      child: widget.child,
    ),
  );
}
