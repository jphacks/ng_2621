import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zoo_study/core/ui/zoo_ui.dart';

void main() {
  test(
    'all 16 source rectangles are integral and within the original sheet',
    () {
      expect(TerrainPart.values, hasLength(16));
      for (final part in TerrainPart.values) {
        final rect = part.sourceRect;
        expect(rect.width, greaterThan(0));
        expect(rect.height, greaterThan(0));
        expect(rect.left, greaterThanOrEqualTo(0));
        expect(rect.top, greaterThanOrEqualTo(0));
        expect(rect.right, lessThanOrEqualTo(TerrainSprite.sheetSize));
        expect(rect.bottom, lessThanOrEqualTo(TerrainSprite.sheetSize));
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
      final data = await rootBundle.load(TerrainSprite.assetPath);
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
    // Every visible source pixel belongs to exactly one named part.
    for (var y = 0; y < 64; y++) {
      for (var x = 0; x < 64; x++) {
        if (sourceBytes.getUint8((y * 64 + x) * 4 + 3) == 0) continue;
        expect(
          TerrainPart.values.where(
            (part) => part.sourceRect.contains(Offset(x + 0.5, y + 0.5)),
          ),
          hasLength(1),
          reason: 'Source pixel ($x, $y) must not be omitted or duplicated',
        );
      }
    }

    final boundaryKey = GlobalKey();
    final cases = [
      for (final part in TerrainPart.values) (part, 0, false),
      for (final part in [
        TerrainPart.grassQuarterDirt,
        TerrainPart.grassHalfDirt,
        TerrainPart.grassQuarterStone,
        TerrainPart.grassHalfStone,
      ])
        for (var turns = 1; turns < 4; turns++) (part, turns, false),
      (TerrainPart.fenceEnd, 0, true),
    ];
    for (final (part, turns, mirror) in cases) {
      await tester.runAsync(() async {
        await tester.pumpWidget(
          Directionality(
            textDirection: TextDirection.ltr,
            child: Center(
              child: RepaintBoundary(
                key: boundaryKey,
                child: TerrainSprite(
                  part: part,
                  scale: 2,
                  quarterTurns: turns,
                  mirrorX: mirror,
                ),
              ),
            ),
          ),
        );
        await precacheImage(
          const AssetImage(TerrainSprite.assetPath),
          tester.element(find.byType(TerrainSprite)),
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
          var sx = x ~/ 2;
          var sy = y ~/ 2;
          for (var turn = 0; turn < turns; turn++) {
            final previousX = sx;
            sx = sy;
            sy = part.sourceRect.width.toInt() - 1 - previousX;
          }
          if (mirror) sx = part.sourceRect.width.toInt() - 1 - sx;
          final sourceIndex =
              ((part.sourceRect.top.toInt() + sy) * 64 +
                  part.sourceRect.left.toInt() +
                  sx) *
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
