import 'dart:convert';
import 'dart:ui' as ui;

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zoo_study/core/ui/zoo_ui.dart';
import 'package:zoo_study/features/game/demo/demo_finale.dart';
import 'package:zoo_study/features/game/domain/zoo_layout.dart';
import 'package:zoo_study/features/zoo/domain/zoo_world.dart';
import 'package:zoo_study/features/zoo/presentation/terrain/terrain_painter.dart';

Future<ui.Image> load(WidgetTester tester, String asset) async =>
    (await tester.runAsync(() async {
      final data = await rootBundle.load(asset);
      final codec = await ui.instantiateImageCodec(data.buffer.asUint8List());
      final image = (await codec.getNextFrame()).image;
      codec.dispose();
      return image;
    }))!;
Future<ByteData> pixels(WidgetTester tester, ZooTerrainPainter painter) async =>
    (await tester.runAsync(() async {
      final recorder = ui.PictureRecorder();
      final size = ui.Size(painter.world.columns * 16, painter.world.rows * 16);
      painter.paint(ui.Canvas(recorder), size);
      final picture = recorder.endRecording();
      final image = await picture.toImage(
        size.width.toInt(),
        size.height.toInt(),
      );
      final bytes = (await image.toByteData())!;
      image.dispose();
      picture.dispose();
      return bytes;
    }))!;

void main() {
  testWidgets(
    'top and bottom fences share orientation and trees never enter fence cells',
    (tester) async {
      final sheet = await load(tester, TerrainSprite.assetPath);
      final extra = await load(tester, ZooExtraSprite.assetPath);
      addTearDown(sheet.dispose);
      addTearDown(extra.dispose);
      final source = (await tester.runAsync(() => sheet.toByteData()))!;
      final world = ZooWorld(
        columns: 5,
        rows: 5,
        tileSize: 16,
        tiles: List.filled(5, '.....'),
        animals: [],
        facilities: const [
          FacilityDefinition(
            id: 'forest',
            tile: 'forest',
            left: 0,
            top: 0,
            width: 5,
            height: 5,
          ),
        ],
      );
      const pens = {
        'pen': Enclosure(id: 'pen', left: 0, top: 0, width: 5, height: 5),
      };
      final normal = await pixels(
        tester,
        ZooTerrainPainter(
          world,
          [],
          {},
          sheet,
          extraImage: extra,
          enclosures: pens,
        ),
      );
      final forest = await pixels(
        tester,
        ZooTerrainPainter(
          world,
          [],
          {'forest'},
          sheet,
          extraImage: extra,
          enclosures: pens,
        ),
      );
      for (var y = 0; y < 80; y++) {
        for (var x = 0; x < 80; x++) {
          if (x < 16 || x >= 64 || y < 16 || y >= 64) {
            expect(
              forest.getUint32((y * 80 + x) * 4),
              normal.getUint32((y * 80 + x) * 4),
              reason: 'Tree on fence at $x,$y',
            );
          }
        }
      }
      expect(
        forest.getUint32(((2 * 16 + 3) * 80 + 2 * 16 + 4) * 4),
        isNot(normal.getUint32(((2 * 16 + 3) * 80 + 2 * 16 + 4) * 4)),
      );
      // Top edges and corners use the same unflipped artwork as the bottom.
      for (var y = 0; y < 16; y++) {
        for (var x = 0; x < 16; x++) {
          final i = ((16 + y) * 64 + 32 + x) * 4;
          final color = source.getUint8(i + 3) == 0
              ? source.getUint32((y * 64 + x) * 4)
              : source.getUint32(i);
          expect(
            normal.getUint32((y * 80 + 32 + x) * 4),
            color,
            reason: 'Top fence pixel $x,$y',
          );
        }
      }
      final extraBytes = (await tester.runAsync(() => extra.toByteData()))!;
      for (final y in [7, 8, 10, 11]) {
        expect(
          normal.getUint32((y * 80 + 15) * 4),
          extraBytes.getUint32(((48 + y) * 64 + 31) * 4),
        );
        expect(
          normal.getUint32((y * 80 + 16) * 4),
          source.getUint32(((16 + y) * 64 + 32) * 4),
        );
      }
    },
  );

  testWidgets(
    'stone and dirt never directly touch at crossings, including the demo plaza',
    (tester) async {
      final sheet = await load(tester, TerrainSprite.assetPath);
      addTearDown(sheet.dispose);
      final source = (await tester.runAsync(() => sheet.toByteData()))!;
      Set<int> palette(TerrainPart part) => {
        for (
          var y = part.sourceRect.top.toInt();
          y < part.sourceRect.bottom;
          y++
        )
          for (
            var x = part.sourceRect.left.toInt();
            x < part.sourceRect.right;
            x++
          )
            source.getUint32((y * 64 + x) * 4),
      };
      final stone = palette(TerrainPart.stone),
          dirt = palette(TerrainPart.dirt);
      final data = (await tester.runAsync(
        () => rootBundle.loadString('assets/zoo/world.json'),
      ))!;
      final world = ZooWorld.fromJson(jsonDecode(data) as Map<String, dynamic>);
      for (final overrides in [<(int, int), String>{}]) {
        final actual = await pixels(
          tester,
          ZooTerrainPainter(world, [], {}, sheet, tileOverrides: overrides),
        );
        final width = world.columns * 16, height = world.rows * 16;
        for (var y = 0; y < height; y++) {
          for (var x = 0; x < width; x++) {
            if (!stone.contains(actual.getUint32((y * width + x) * 4))) {
              continue;
            }
            for (final d in [(1, 0), (-1, 0), (0, 1), (0, -1)]) {
              final nx = x + d.$1, ny = y + d.$2;
              if (nx >= 0 && ny >= 0 && nx < width && ny < height) {
                expect(
                  dirt.contains(actual.getUint32((ny * width + nx) * 4)),
                  isFalse,
                  reason: 'Stone touches dirt at $x,$y -> $nx,$ny',
                );
              }
            }
          }
        }
      }
    },
  );

  test(
    'demo arches share the normal path and fountain furniture is symmetric',
    () {
      final arches = DemoFinale.decorativeArches;
      expect(arches, hasLength(3));
      expect(arches[1].top - arches[0].top, arches[2].top - arches[1].top);
      for (final arch in arches) {
        expect(arch.center.dx, 9.5);
        expect(arch.left, greaterThanOrEqualTo(8.5));
        expect(arch.right, lessThanOrEqualTo(10.5));
      }
      final furniture = DemoFinale.furnishings;
      final bench = furniture.singleWhere(
        (d) => d.part == ZooBuildingPart.bench,
      );
      final trees = furniture
          .where((d) => d.part == ZooBuildingPart.topiary)
          .toList();
      expect(bench.bounds.center.dx, 15);
      expect(bench.bounds.top, greaterThanOrEqualTo(2));
      expect(trees[0].bounds.center.dy, bench.bounds.center.dy);
      expect(trees[1].bounds.center.dy, bench.bounds.center.dy);
      expect(
        bench.bounds.center.dx - trees[0].bounds.center.dx,
        trees[1].bounds.center.dx - bench.bounds.center.dx,
      );
    },
  );
}
