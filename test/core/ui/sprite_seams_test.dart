import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zoo_study/core/ui/zoo_ui.dart';

Future<ByteData> sourceBytes(WidgetTester tester, String asset) async {
  return (await tester.runAsync(() async {
    final data = await rootBundle.load(asset);
    final codec = await ui.instantiateImageCodec(
      data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes),
    );
    final image = (await codec.getNextFrame()).image;
    codec.dispose();
    final bytes = (await image.toByteData())!;
    image.dispose();
    return bytes;
  }))!;
}

Future<ByteData> render(WidgetTester tester, Widget child, String asset) async {
  final key = GlobalKey();
  await tester.runAsync(() async {
    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: Center(
          child: RepaintBoundary(key: key, child: child),
        ),
      ),
    );
    await precacheImage(AssetImage(asset), key.currentContext!);
  });
  await tester.pump();
  final boundary =
      key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
  final image = (await tester.runAsync(() => boundary.toImage(pixelRatio: 1)))!;
  final bytes = (await tester.runAsync(() => image.toByteData()))!;
  image.dispose();
  return bytes;
}

void main() {
  testWidgets('brick recess appears only in the first two source rows', (
    tester,
  ) async {
    final source = await sourceBytes(tester, ZooExtraSprite.assetPath);
    final actual = await render(
      tester,
      const SpritePanel(
        style: SpritePanelStyle.brick,
        child: SizedBox(width: 152, height: 80),
      ),
      ZooExtraSprite.assetPath,
    );
    for (var y = 0; y < 80; y++) {
      for (var x = 0; x < 152; x++) {
        final alpha = actual.getUint8((y * 152 + x) * 4 + 3);
        if (y >= 4) {
          expect(
            alpha,
            255,
            reason: 'Brick body must have no transparent seam at ($x, $y)',
          );
        } else {
          final sx = x < 32
              ? 16 + x ~/ 2
              : x >= 120
              ? 48 + (x - 120) ~/ 2
              : 32 + ((x - 32) % 32) ~/ 2;
          expect(alpha, source.getUint8(((32 + y ~/ 2) * 64 + sx) * 4 + 3));
        }
      }
    }
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets(
    'corrected old wood joins 11-row pieces without a blank bottom row',
    (tester) async {
      final source = await sourceBytes(tester, ZooUiSprite.assetPath);
      final actual = await render(
        tester,
        const WoodPanel(
          originalSheet: true,
          child: SizedBox(width: 62, height: 22),
        ),
        ZooUiSprite.assetPath,
      );
      for (var y = 0; y < 22; y++) {
        for (var x = 0; x < 62; x++) {
          final sx = x < 22
              ? 26 + x ~/ 2
              : x < 40
              ? 38 + (x - 22) ~/ 2
              : 48 + (x - 40) ~/ 2;
          for (var channel = 0; channel < 4; channel++) {
            expect(
              actual.getUint8((y * 62 + x) * 4 + channel),
              source.getUint8(((22 + y ~/ 2) * 64 + sx) * 4 + channel),
              reason: 'Wood pixel mismatch at ($x, $y), channel $channel',
            );
          }
        }
      }
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
}
