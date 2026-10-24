import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zoo_study/features/zoo/domain/zoo_world.dart';
import 'package:zoo_study/features/zoo/domain/facility_placement.dart';
import 'package:zoo_study/core/ui/zoo_ui.dart';
import 'package:zoo_study/features/zoo/presentation/zoo_controller.dart';
import 'package:zoo_study/features/zoo/presentation/zoo_map.dart';

Future<List<int>> sample(WidgetTester tester, int tileX, int tileY) async {
  final boundary = tester.renderObject<RenderRepaintBoundary>(
    find.byKey(const ValueKey('zoo-terrain')),
  );
  final image = (await tester.runAsync(() => boundary.toImage(pixelRatio: 1)))!;
  final data = (await tester.runAsync(() => image.toByteData()))!;
  final offset = ((tileY * 16 + 8) * image.width + tileX * 16 + 8) * 4;
  final rgba = List.generate(4, (channel) => data.getUint8(offset + channel));
  image.dispose();
  return rgba;
}

void main() {
  testWidgets(
    'facility ownership repaints pond and forest without changing map data',
    (tester) async {
      final world = ZooWorld.fromJson(
        jsonDecode(File('assets/zoo/world.json').readAsStringSync())
            as Map<String, dynamic>,
      );
      final controller = ZooController(
        world,
        ownedAnimalIds: {},
        ownedFacilityIds: {},
      );
      addTearDown(controller.dispose);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: ZooMap(controller: controller)),
        ),
      );
      await tester.runAsync(
        () => precacheImage(
          const AssetImage(TerrainSprite.assetPath),
          tester.element(find.byType(ZooMap)),
        ),
      );
      await tester.runAsync(
        () => precacheImage(
          const AssetImage(ZooExtraSprite.assetPath),
          tester.element(find.byType(ZooMap)),
        ),
      );
      await tester.pump();
      final grass = await sample(tester, 15, 12);
      final oldCorner = await sample(tester, 14, 14);
      expect(grass, isNot([117, 244, 254, 255]));
      controller.synchronizeOwnership({}, {'pond', 'forest'});
      await tester.pump();
      expect(await sample(tester, 15, 12), [117, 244, 254, 255]);
      expect(await sample(tester, 2, 2), [0x31, 0x5C, 0x3A, 255]);
      expect(
        controller.placeFacility(
          const FacilityPlacement(facilityId: 'pond', left: 15, top: 10),
        ),
        isTrue,
      );
      await tester.pump();
      expect(await sample(tester, 14, 14), oldCorner);
      expect(await sample(tester, 18, 10), [117, 244, 254, 255]);
      controller.synchronizeOwnership({}, {});
      await tester.pump();
      expect(await sample(tester, 15, 12), grass);
      expect(world.tiles[12][15], '~');
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
}
