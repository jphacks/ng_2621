import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zoo_study/core/ui/zoo_ui.dart';

void main() {
  testWidgets('all visible atlas pixels belong to one button state', (
    tester,
  ) async {
    final image = await tester.runAsync(() async {
      final data = await rootBundle.load(ColorButtonPanel.assetPath);
      final codec = await ui.instantiateImageCodec(data.buffer.asUint8List());
      final frame = await codec.getNextFrame();
      codec.dispose();
      return frame.image;
    });
    final bytes = (await tester.runAsync(() => image!.toByteData()))!;
    expect(image!.width, 64);
    expect(image.height, 64);
    final regions = [
      for (final palette in ButtonPalette.values)
        for (final pressed in [false, true])
          ColorButtonPanel.sourceRect(palette, pressed: pressed),
    ];
    for (var y = 0; y < 64; y++) {
      for (var x = 0; x < 64; x++) {
        if (bytes.getUint8((y * 64 + x) * 4 + 3) == 0) continue;
        expect(
          regions.where((r) => r.contains(Offset(x + .5, y + .5))),
          hasLength(1),
          reason: 'Pixel $x,$y',
        );
      }
    }
    image.dispose();
  });

  testWidgets(
    'nine-slice preserves corner pixels and fills tall button bodies',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetDevicePixelRatio);
      final source = await tester.runAsync(() async {
        final data = await rootBundle.load(ColorButtonPanel.assetPath);
        final codec = await ui.instantiateImageCodec(data.buffer.asUint8List());
        final image = (await codec.getNextFrame()).image;
        codec.dispose();
        return image;
      });
      final original = (await tester.runAsync(() => source!.toByteData()))!;
      final key = GlobalKey();
      for (final palette in ButtonPalette.values) {
        for (final pressed in [false, true]) {
          await tester.pumpWidget(
            Directionality(
              textDirection: TextDirection.ltr,
              child: Center(
                child: RepaintBoundary(
                  key: key,
                  child: SizedBox(
                    width: 140,
                    height: 100,
                    child: ColorButtonPanel(
                      palette: palette,
                      pressed: pressed,
                      child: const SizedBox.expand(),
                    ),
                  ),
                ),
              ),
            ),
          );
          await tester.runAsync(() async {
            await Future<void>.delayed(const Duration(milliseconds: 10));
          });
          await tester.pumpAndSettle();
          final boundary =
              key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
          final rendered = await tester.runAsync(
            () => boundary.toImage(pixelRatio: 1),
          );
          final pixels = (await tester.runAsync(() => rendered!.toByteData()))!;
          final rect = ColorButtonPanel.sourceRect(palette, pressed: pressed);
          final top = pressed ? 2 : 0;
          for (var y = 0; y < 8; y++) {
            for (var x = 0; x < 8; x++) {
              final sx = rect.left.toInt() + x ~/ 2;
              final sy = rect.top.toInt() + y ~/ 2;
              expect(
                pixels.getUint32(((y + top) * 140 + x) * 4),
                original.getUint32((sy * 64 + sx) * 4),
                reason: '$palette pressed=$pressed corner $x,$y',
              );
            }
          }
          for (var y = top + 8; y < 92; y++) {
            expect(
              pixels.getUint8((y * 140 + 70) * 4 + 3),
              255,
              reason: '$palette pressed=$pressed has a gap at row $y',
            );
          }
          rendered!.dispose();
        }
      }
      source!.dispose();
    },
  );

  testWidgets('standard buttons use pressed state and disable interaction', (
    tester,
  ) async {
    var taps = 0;
    Widget app({required bool enabled}) => MaterialApp(
      home: PixelUiTheme(
        child: Scaffold(
          body: Center(
            child: FilledButton(
              onPressed: enabled ? () => taps++ : null,
              child: const Text('購入'),
            ),
          ),
        ),
      ),
    );
    await tester.pumpWidget(app(enabled: true));
    await tester.pumpAndSettle();
    ColorButtonPanel panel() =>
        tester.widget<ColorButtonPanel>(find.byType(ColorButtonPanel).first);
    expect(panel().palette, ButtonPalette.green);
    expect(panel().pressed, isFalse);
    final gesture = await tester.startGesture(
      tester.getCenter(find.byType(FilledButton)),
    );
    await tester.pump();
    expect(panel().pressed, isTrue);
    await gesture.up();
    await tester.pumpAndSettle();
    expect(panel().pressed, isFalse);
    expect(taps, 1);
    await tester.pumpWidget(app(enabled: false));
    await tester.pumpAndSettle();
    expect(panel().enabled, isFalse);
    await tester.tap(find.byType(FilledButton));
    expect(taps, 1);
  });
}
