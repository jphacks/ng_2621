import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zoo_study/features/zoo/domain/zoo_world.dart';
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
      final grass = await sample(tester, 15, 12);
      expect(grass, isNot([0x6C, 0xBC, 0xCB, 255]));
      controller.synchronizeOwnership({}, {'pond', 'forest'});
      await tester.pump();
      expect(await sample(tester, 15, 12), [0x6C, 0xBC, 0xCB, 255]);
      expect(await sample(tester, 2, 2), [0x31, 0x5C, 0x3A, 255]);
      controller.synchronizeOwnership({}, {});
      await tester.pump();
      expect(await sample(tester, 15, 12), grass);
      expect(world.tiles[12][15], '~');
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
}
