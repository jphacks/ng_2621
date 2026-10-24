import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zoo_study/features/zoo/domain/facility_placement.dart';
import 'package:zoo_study/features/zoo/domain/zoo_world.dart';
import 'package:zoo_study/features/zoo/presentation/zoo_controller.dart';
import 'package:zoo_study/features/zoo/presentation/zoo_map.dart';

void main() {
  testWidgets(
    'new buildings appear only after placement and previews reflect proposed locations',
    (tester) async {
      final world = ZooWorld.fromJson(
        jsonDecode(File('assets/zoo/world.json').readAsStringSync())
            as Map<String, dynamic>,
      );
      final buildings = world.facilities
          .where((f) => f.tile == 'sprite')
          .toList();
      final controller = ZooController(
        world,
        ownedAnimalIds: {},
        ownedFacilityIds: buildings.map((f) => f.id).toSet(),
      );
      addTearDown(controller.dispose);
      Widget map({Map<String, FacilityPlacement>? preview}) => MaterialApp(
        home: Scaffold(
          body: ZooMap(controller: controller, placementsOverride: preview),
        ),
      );
      await tester.pumpWidget(map());
      for (final building in buildings) {
        expect(find.byKey(ValueKey('facility-${building.id}')), findsNothing);
        expect(
          controller.placeFacility(
            FacilityPlacement(
              facilityId: building.id,
              left: building.left,
              top: building.top,
            ),
          ),
          isTrue,
        );
      }
      await tester.pump();
      for (final building in buildings) {
        final position = tester.widget<Positioned>(
          find.byKey(ValueKey('facility-${building.id}')),
        );
        expect(position.left, building.left * 16);
        expect(position.width, building.width * 16);
        expect(position.height, building.height * 16);
      }
      final previous = controller.placements['laboratory']!;
      await tester.pumpWidget(
        map(
          preview: {
            ...controller.placements,
            'laboratory': const FacilityPlacement(
              facilityId: 'laboratory',
              left: 17,
              top: 5,
            ),
          },
        ),
      );
      expect(
        tester
            .widget<Positioned>(
              find.byKey(const ValueKey('facility-laboratory')),
            )
            .left,
        17 * 16,
      );
      expect(controller.placements['laboratory'], previous);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
}
