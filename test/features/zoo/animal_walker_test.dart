import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:zoo_study/features/zoo/domain/animal_walker.dart';
import 'package:zoo_study/features/zoo/domain/zoo_world.dart';

const animal = AnimalDefinition(
  id: 'rabbit',
  name: 'うさぎ',
  imagePath: null,
  speed: 1,
  area: MovementArea(1, 1, 5, 5),
  placeholderColor: 0xFFFFFFFF,
);

void main() {
  test('alternates waiting and walking without leaving its own area', () {
    final walker = AnimalWalker(
      instanceId: 'rabbit-1',
      definition: animal,
      random: Random(42),
    );
    var arrivals = 0;
    var walkingFrames = 0;
    var waitingFrames = 0;
    for (var frame = 0; frame < 10000; frame++) {
      final before = walker.position;
      final previousActivity = walker.activity;
      walker.advance(0.05);
      expect(animal.area.contains(walker.position), isTrue);
      final distance = walker.position.distanceTo(before);
      expect(distance, lessThanOrEqualTo(animal.speed * 0.05 + 1e-9));
      if (previousActivity == AnimalActivity.waiting) {
        waitingFrames++;
        expect(walker.position, before);
      } else {
        walkingFrames++;
        if (walker.activity == AnimalActivity.waiting) {
          arrivals++;
        } else {
          expect(distance, closeTo(0.05, 1e-9));
        }
      }
    }
    expect(arrivals, greaterThan(10));
    expect(walkingFrames, greaterThan(0));
    expect(waitingFrames, greaterThan(0));
  });

  test(
    'zero-sized area remains safe and invalid time does not move animal',
    () {
      const stationary = AnimalDefinition(
        id: 'panda',
        name: 'パンダ',
        imagePath: null,
        speed: 1,
        area: MovementArea(2, 2, 2, 2),
        placeholderColor: 0xFFFFFFFF,
      );
      final walker = AnimalWalker(
        instanceId: 'panda-1',
        definition: stationary,
        random: Random(1),
      );
      for (var i = 0; i < 100; i++) {
        walker.advance(0.1);
        expect(walker.position, const Point<double>(2, 2));
      }
      for (final invalid in [0.0, -1.0, double.nan, double.infinity]) {
        walker.advance(invalid);
        expect(walker.position, const Point<double>(2, 2));
      }
    },
  );
}
