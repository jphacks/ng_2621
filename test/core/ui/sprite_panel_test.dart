import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zoo_study/core/ui/zoo_ui.dart';

void main() {
  testWidgets('wide and tall frames preserve all four source corners at 2x', (
    tester,
  ) async {
    final image = (await tester.runAsync(() async {
      final data = await rootBundle.load(ZooExtraSprite.assetPath);
      final codec = await ui.instantiateImageCodec(
        data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes),
      );
      final image = (await codec.getNextFrame()).image;
      codec.dispose();
      return image;
    }))!;
    final source = (await tester.runAsync(() => image.toByteData()))!;
    image.dispose();
    final key = GlobalKey();
    for (final entry in [
      (SpritePanelStyle.cream, const ui.Rect.fromLTWH(16, 16, 16, 16)),
      (SpritePanelStyle.gray, const ui.Rect.fromLTWH(48, 0, 16, 16)),
      (SpritePanelStyle.lime, const ui.Rect.fromLTWH(32, 16, 32, 16)),
      (SpritePanelStyle.wood, const ui.Rect.fromLTWH(0, 0, 48, 16)),
    ]) {
      await tester.runAsync(() async {
        await tester.pumpWidget(
          Directionality(
            textDirection: TextDirection.ltr,
            child: Center(
              child: RepaintBoundary(
                key: key,
                child: SpritePanel(
                  style: entry.$1,
                  child: const SizedBox(width: 152, height: 80),
                ),
              ),
            ),
          ),
        );
        await precacheImage(
          const AssetImage(ZooExtraSprite.assetPath),
          tester.element(find.byType(SpritePanel)),
        );
      });
      await tester.pump();
      final boundary =
          key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
      final actualImage = (await tester.runAsync(
        () => boundary.toImage(pixelRatio: 1),
      ))!;
      final bytes = (await tester.runAsync(() => actualImage.toByteData()))!;
      expect(actualImage.width, 152);
      expect(actualImage.height, 80);
      for (final right in [false, true]) {
        for (final bottom in [false, true]) {
          for (var y = 0; y < 6; y++) {
            for (var x = 0; x < 6; x++) {
              final sx =
                  (right ? entry.$2.right.toInt() - 3 : entry.$2.left.toInt()) +
                  x ~/ 2;
              final sy =
                  (bottom
                      ? entry.$2.bottom.toInt() - 3
                      : entry.$2.top.toInt()) +
                  y ~/ 2;
              final target =
                  (((bottom ? 74 : 0) + y) * 152 + (right ? 146 : 0) + x) * 4;
              for (var channel = 0; channel < 4; channel++) {
                expect(
                  bytes.getUint8(target + channel),
                  source.getUint8((sy * 64 + sx) * 4 + channel),
                  reason:
                      '${entry.$1}: corner must keep original pixels and alpha',
                );
              }
            }
          }
        }
      }
      actualImage.dispose();
      expect(tester.takeException(), isNull);
    }
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
