import 'color_button_panel.dart';
import 'pixel_text_outline.dart';

import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../sprites/sprite_sheet_image.dart';
import '../sprites/zoo_extra_sprite.dart';
import '../sprites/zoo_extra_part.dart';
import '../sprites/zoo_building_sprite.dart';
import '../zoo_font.dart';

enum SpritePanelStyle { wood, cream, creamRound, gray, lime, roundGray, brick }

/// Nine-slice frames from the supplied sheet. Edges and fill are tiled at 2x;
/// corners keep their original shape rather than being stretched with content.
class SpritePanel extends StatelessWidget {
  const SpritePanel({
    super.key,
    required this.child,
    this.style = SpritePanelStyle.cream,
  });
  final Widget child;
  final SpritePanelStyle style;

  @override
  Widget build(BuildContext context) => SpriteSheetImage(
    assetPath: style == SpritePanelStyle.creamRound
        ? ZooBuildingSprite.assetPath
        : ZooExtraSprite.assetPath,
    builder: (context, image) => CustomPaint(
      painter: _PanelPainter(image, style),
      child: style == SpritePanelStyle.wood
          ? PixelTextOutline(child: child)
          : child,
    ),
  );
}

class _PanelPainter extends CustomPainter {
  _PanelPainter(this.image, this.style);
  final ui.Image? image;
  final SpritePanelStyle style;

  Rect get source => switch (style) {
    SpritePanelStyle.wood =>
      ZooExtraPart.woodenButtonLeft.sourceRect.expandToInclude(
        ZooExtraPart.woodenButtonRight.sourceRect,
      ),
    SpritePanelStyle.cream => ZooExtraPart.creamSquareButton.sourceRect,
    SpritePanelStyle.creamRound => ZooBuildingPart.creamRoundFrame.sourceRect,
    SpritePanelStyle.gray => ZooExtraPart.graySquareButton.sourceRect,
    SpritePanelStyle.lime =>
      ZooExtraPart.limeButtonLeft.sourceRect.expandToInclude(
        ZooExtraPart.limeButtonRight.sourceRect,
      ),
    SpritePanelStyle.roundGray => ZooExtraPart.grayRoundButton.sourceRect,
    SpritePanelStyle.brick => ZooExtraPart.brickLeft.sourceRect.expandToInclude(
      ZooExtraPart.brickRight.sourceRect,
    ),
  };

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final image = this.image;
    if (image == null) {
      canvas.drawRect(
        Offset.zero & size,
        Paint()..color = const Color(0xFFF6F2C5),
      );
      return;
    }
    final paint = Paint()
      ..filterQuality = FilterQuality.none
      ..isAntiAlias = false;
    if (style == SpritePanelStyle.brick) {
      // Keep the recessed top two source rows only at the outer top edge.
      // Repeat the opaque 14-row body so internal seams have no gaps.
      final cap = math.min(32.0, size.width / 2);
      void strip(Rect source, double left, double width) {
        if (width <= 0) return;
        canvas.save();
        canvas.clipRect(
          Rect.fromLTWH(left, 0, width, size.height),
          doAntiAlias: false,
        );
        final top = Rect.fromLTWH(source.left, source.top, source.width, 2);
        final body = Rect.fromLTWH(
          source.left,
          source.top + 2,
          source.width,
          source.height - 2,
        );
        for (var x = left; x < left + width; x += 32) {
          canvas.drawImageRect(image, top, Rect.fromLTWH(x, 0, 32, 4), paint);
          for (var y = 4.0; y < size.height; y += 28) {
            canvas.drawImageRect(
              image,
              body,
              Rect.fromLTWH(x, y, 32, 28),
              paint,
            );
          }
        }
        canvas.restore();
      }

      strip(ZooExtraPart.brickLeft.sourceRect, 0, cap);
      strip(ZooExtraPart.brickMiddle.sourceRect, cap, size.width - 2 * cap);
      strip(ZooExtraPart.brickRight.sourceRect, size.width - cap, cap);
      return;
    }
    if (style == SpritePanelStyle.roundGray) {
      canvas.drawImageRect(image, source, Offset.zero & size, paint);
      return;
    }
    const edge = 3.0;
    final src = source;
    final dx = math.min(edge * 2, size.width / 2);
    final dy = math.min(edge * 2, size.height / 2);
    final sx = [src.left, src.left + edge, src.right - edge, src.right];
    final sy = [src.top, src.top + edge, src.bottom - edge, src.bottom];
    final tx = [0.0, dx, size.width - dx, size.width];
    final ty = [0.0, dy, size.height - dy, size.height];
    for (var row = 0; row < 3; row++) {
      for (var col = 0; col < 3; col++) {
        final from = Rect.fromLTRB(sx[col], sy[row], sx[col + 1], sy[row + 1]);
        final to = Rect.fromLTRB(tx[col], ty[row], tx[col + 1], ty[row + 1]);
        if (to.isEmpty) continue;
        canvas.save();
        canvas.clipRect(to, doAntiAlias: false);
        final w = col == 1 ? from.width * 2 : to.width;
        final h = row == 1 ? from.height * 2 : to.height;
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
  bool shouldRepaint(_PanelPainter old) =>
      old.image != image || old.style != style;
}

/// Shared pixel styling; decorative frames and actionable surfaces are distinct.
class PixelUiTheme extends StatelessWidget {
  const PixelUiTheme({super.key, required this.child});
  final Widget child;

  // Compatibility for existing callers; wood is now reserved for decoration.
  static ButtonStyle buttonStyle(SpritePanelStyle style) =>
      colorfulButtonStyle(switch (style) {
        SpritePanelStyle.lime => ButtonPalette.green,
        SpritePanelStyle.wood => ButtonPalette.cyan,
        SpritePanelStyle.cream ||
        SpritePanelStyle.creamRound => ButtonPalette.yellow,
        _ => ButtonPalette.white,
      });
  static ButtonStyle colorfulButtonStyle(ButtonPalette palette) => ButtonStyle(
    minimumSize: const WidgetStatePropertyAll(Size(48, 48)),
    padding: const WidgetStatePropertyAll(
      EdgeInsets.symmetric(horizontal: 12, vertical: 10),
    ),
    elevation: const WidgetStatePropertyAll(0),
    backgroundColor: const WidgetStatePropertyAll(Colors.transparent),
    shadowColor: const WidgetStatePropertyAll(Colors.transparent),
    surfaceTintColor: const WidgetStatePropertyAll(Colors.transparent),
    side: const WidgetStatePropertyAll(BorderSide.none),
    shape: const WidgetStatePropertyAll(RoundedRectangleBorder()),
    foregroundColor: WidgetStateProperty.resolveWith(
      (states) => states.contains(WidgetState.disabled)
          ? Colors.white
          : palette == ButtonPalette.blue || palette == ButtonPalette.gray
          ? Colors.white
          : const Color(0xFF263D2D),
    ),
    backgroundBuilder: (context, states, child) => ColorButtonPanel(
      palette: palette,
      enabled: !states.contains(WidgetState.disabled),
      pressed: states.contains(WidgetState.pressed),
      child: child ?? const SizedBox.shrink(),
    ),
  );

  @override
  Widget build(BuildContext context) {
    ZooFont.registerLicense();
    final base = Theme.of(context);
    return Theme(
      data: base.copyWith(
        textTheme: base.textTheme.apply(fontFamily: ZooFont.family),
        primaryTextTheme: base.primaryTextTheme.apply(
          fontFamily: ZooFont.family,
        ),
        filledButtonTheme: FilledButtonThemeData(
          style: buttonStyle(SpritePanelStyle.lime),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: buttonStyle(SpritePanelStyle.wood),
        ),
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: colorfulButtonStyle(ButtonPalette.yellow),
        ),
        textButtonTheme: TextButtonThemeData(
          style: colorfulButtonStyle(ButtonPalette.white),
        ),
        iconButtonTheme: IconButtonThemeData(
          style: buttonStyle(SpritePanelStyle.gray),
        ),
        listTileTheme: base.listTileTheme.copyWith(
          shape: const RoundedRectangleBorder(),
        ),
      ),
      child: child,
    );
  }
}

/// Framed rows retain ListTile's focus, disabled and navigation semantics.
class SpriteTile extends StatelessWidget {
  const SpriteTile({
    super.key,
    this.leading,
    this.title,
    this.subtitle,
    this.trailing,
    this.onTap,
    this.enabled = true,
    this.panelStyle,
  });
  final Widget? leading, title, subtitle, trailing;
  final VoidCallback? onTap;
  final bool enabled;
  final SpritePanelStyle? panelStyle;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: panelStyle != null
        ? SpritePanel(
            style: panelStyle!,
            child: PixelTextOutline(child: _tile()),
          )
        : onTap != null
        ? ColorActionPanel(enabled: enabled, child: _tile())
        : SpritePanel(child: _tile()),
  );

  Widget _tile() => Material(
    color: Colors.transparent,
    child: ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      leading: leading,
      title: title,
      subtitle: subtitle,
      trailing: trailing,
      enabled: enabled,
      onTap: enabled ? onTap : null,
    ),
  );
}

/// A scrollable confirmation surface using the same frame as game sheets.
class SpriteAlertDialog extends StatelessWidget {
  const SpriteAlertDialog({
    super.key,
    required this.title,
    required this.content,
    required this.actions,
  });
  final Widget title, content;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) => Dialog(
    backgroundColor: Colors.transparent,
    elevation: 0,
    insetPadding: const EdgeInsets.all(24),
    constraints: const BoxConstraints(maxWidth: 560),
    child: SpritePanel(
      style: SpritePanelStyle.creamRound,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Flexible(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    DefaultTextStyle.merge(
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                      child: title,
                    ),
                    const SizedBox(height: 16),
                    content,
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Wrap(
              alignment: WrapAlignment.end,
              spacing: 8,
              runSpacing: 8,
              children: actions,
            ),
          ],
        ),
      ),
    ),
  );
}
