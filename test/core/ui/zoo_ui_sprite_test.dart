import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zoo_study/core/ui/zoo_ui.dart';

void main() {
  test(
    'all 33 source rectangles are integral and within the original sheet',
    () {
      expect(ZooUiPart.values, hasLength(33));
      for (final part in ZooUiPart.values) {
        final rect = part.sourceRect;
        expect(rect.width, greaterThan(0));
        expect(rect.height, greaterThan(0));
        expect(rect.left, greaterThanOrEqualTo(0));
        expect(rect.top, greaterThanOrEqualTo(0));
        expect(rect.right, lessThanOrEqualTo(ZooUiSprite.sheetSize));
        expect(rect.bottom, lessThanOrEqualTo(ZooUiSprite.sheetSize));
        for (final value in [rect.left, rect.top, rect.width, rect.height]) {
          expect(value, value.roundToDouble());
        }
      }
    },
  );

  testWidgets('every sprite preserves source pixels and transparency at 2x', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(800, 600);
    addTearDown(tester.view.resetPhysicalSize);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetDevicePixelRatio);
    final source = await tester.runAsync(() async {
      final data = await rootBundle.load(ZooUiSprite.assetPath);
      final codec = await ui.instantiateImageCodec(
        data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes),
      );
      final frame = await codec.getNextFrame();
      codec.dispose();
      return frame.image;
    });
    expect(source!.width, 64);
    expect(source.height, 64);
    final sourceBytes = (await tester.runAsync(() => source.toByteData()))!;
    source.dispose();
    // The corrected sheet places minus above plus. Check the vertical stroke,
    // so matching enum names to the wrong glyph cannot pass a pixel-copy test.
    int redAt(ZooUiPart part) => sourceBytes.getUint8(
      ((part.sourceRect.top.toInt() + 2) * 64 +
              part.sourceRect.left.toInt() +
              3) *
          4,
    );
    expect(redAt(ZooUiPart.plus), lessThan(100));
    expect(redAt(ZooUiPart.minus), greaterThan(100));

    // Every visible source pixel belongs to exactly one named part.
    for (var y = 0; y < 64; y++) {
      for (var x = 0; x < 64; x++) {
        if (sourceBytes.getUint8((y * 64 + x) * 4 + 3) == 0) continue;
        expect(
          ZooUiPart.values.where(
            (part) => part.sourceRect.contains(Offset(x + 0.5, y + 0.5)),
          ),
          hasLength(1),
          reason: 'Source pixel ($x, $y) must not be omitted or duplicated',
        );
      }
    }

    final boundaryKey = GlobalKey();
    for (final part in ZooUiPart.values) {
      await tester.runAsync(() async {
        await tester.pumpWidget(
          Directionality(
            textDirection: TextDirection.ltr,
            child: Center(
              child: RepaintBoundary(
                key: boundaryKey,
                child: ZooUiSprite(part: part, scale: 2),
              ),
            ),
          ),
        );
        await precacheImage(
          const AssetImage(ZooUiSprite.assetPath),
          tester.element(find.byType(ZooUiSprite)),
        );
      });
      await tester.pump();
      final boundary =
          boundaryKey.currentContext!.findRenderObject()!
              as RenderRepaintBoundary;
      final image = (await tester.runAsync(
        () => boundary.toImage(pixelRatio: 1),
      ))!;
      final actual = (await tester.runAsync(() => image.toByteData()))!;
      final width = image.width;
      final height = image.height;
      image.dispose();
      expect(width, part.sourceRect.width * 2);
      expect(height, part.sourceRect.height * 2);
      for (var y = 0; y < height; y++) {
        for (var x = 0; x < width; x++) {
          final sourceIndex =
              ((part.sourceRect.top.toInt() + y ~/ 2) * 64 +
                  part.sourceRect.left.toInt() +
                  x ~/ 2) *
              4;
          final actualIndex = (y * width + x) * 4;
          for (var channel = 0; channel < 4; channel++) {
            expect(
              actual.getUint8(actualIndex + channel),
              sourceBytes.getUint8(sourceIndex + channel),
              reason: '${part.name} at ($x, $y) channel $channel',
            );
          }
        }
      }
      expect(tester.takeException(), isNull);
    }
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
