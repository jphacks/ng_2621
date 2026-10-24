import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:zoo_study/features/zoo/domain/zoo_world.dart';
import 'package:zoo_study/features/zoo/presentation/zoo_controller.dart';

Map<String, dynamic> fixture() =>
    jsonDecode(File('assets/zoo/world.json').readAsStringSync())
        as Map<String, dynamic>;

void main() {
  test('loads external map and animal definitions', () {
    final world = ZooWorld.fromJson(fixture());
    expect(world.columns, 20);
    expect(world.rows, 16);
    expect(world.animals.map((animal) => animal.id), [
      'rabbit',
      'fox',
      'panda',
    ]);
    expect(world.animals.every((animal) => animal.imagePath == null), isTrue);
  });

  test('rejects malformed maps and out-of-bounds movement areas', () {
    final data = fixture();
    (data['map'] as Map)['columns'] = 1;
    expect(() => ZooWorld.fromJson(data), throwsFormatException);
    final outside = fixture();
    ((outside['animals'] as List).first['movementArea'] as Map)['right'] = 100;
    expect(() => ZooWorld.fromJson(outside), throwsFormatException);
  });

  test('rejects duplicate IDs and missing evolution references', () {
    final duplicate = fixture();
    (duplicate['animals'] as List)[1]['id'] = 'rabbit';
    expect(() => ZooWorld.fromJson(duplicate), throwsFormatException);
    final missing = fixture();
    (missing['animals'] as List).first['evolutionIds'] = ['missing'];
    expect(() => ZooWorld.fromJson(missing), throwsFormatException);
  });

  test(
    'controller clamps long frames and preserves separate movement areas',
    () {
      final controller = ZooController(
        ZooWorld.fromJson(fixture()),
        random: Random(7),
      );
      addTearDown(controller.dispose);
      for (var i = 0; i < 1000; i++) {
        final before = controller.animals.map((a) => a.position).toList();
        controller.advance(30);
        for (var j = 0; j < controller.animals.length; j++) {
          final animal = controller.animals[j];
          expect(animal.definition.area.contains(animal.position), isTrue);
          expect(
            animal.position.distanceTo(before[j]),
            lessThanOrEqualTo(animal.definition.speed * 0.1 + 1e-9),
          );
        }
      }
    },
  );
}
