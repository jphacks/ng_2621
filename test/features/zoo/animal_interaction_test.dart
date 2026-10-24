import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zoo_study/features/zoo/domain/zoo_world.dart';
import 'package:zoo_study/features/zoo/presentation/zoo_controller.dart';
import 'package:zoo_study/features/zoo/presentation/zoo_map.dart';

void main() {
  testWidgets('animal has a usable nearby tap target after zoom and pan', (
    tester,
  ) async {
    final world = ZooWorld.fromJson(
      jsonDecode(File('assets/zoo/world.json').readAsStringSync())
          as Map<String, dynamic>,
    );
    final controller = ZooController(
      world,
      random: Random(2),
      ownedAnimalIds: {'rabbit'},
      ownedFacilityIds: {},
    );
    final camera = TransformationController();
    addTearDown(controller.dispose);
    addTearDown(camera.dispose);
    final selected = <String>[];
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: InteractiveViewer(
            transformationController: camera,
            minScale: 1,
            maxScale: 4,
            child: SizedBox.expand(
              child: ZooMap(
                controller: controller,
                onAnimalSelected: (animal) => selected.add(animal.id),
              ),
            ),
          ),
        ),
      ),
    );
    camera.value = Matrix4.translationValues(10, 10, 0)
      ..multiply(Matrix4.diagonal3Values(1.3, 1.3, 1));
    await tester.pump();
    final center = tester.getCenter(find.byKey(const ValueKey('rabbit-1')));
    await tester.tapAt(center + const Offset(20, 0));
    await tester.pump();
    expect(selected, ['rabbit']);
    selected.clear();
    await tester.dragFrom(center, const Offset(35, 0));
    await tester.pump();
    expect(selected, isEmpty);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
