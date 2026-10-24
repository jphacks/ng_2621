import 'dart:math';

import 'package:flutter/foundation.dart';

import '../domain/animal_walker.dart';
import '../domain/zoo_world.dart';

class ZooController extends ChangeNotifier {
  ZooController(
    this.world, {
    Random? random,
    Set<String>? ownedAnimalIds,
    Set<String>? ownedFacilityIds,
  }) : _random = random ?? Random() {
    synchronizeOwnership(
      ownedAnimalIds ?? world.animals.map((a) => a.id).toSet(),
      ownedFacilityIds ?? world.facilities.map((f) => f.id).toSet(),
    );
  }
  final ZooWorld world;
  final Random _random;
  List<AnimalWalker> animals = const [];
  Set<String> ownedFacilities = const {};
  final sceneryRevision = ValueNotifier(0);

  void synchronizeOwnership(Set<String> animalIds, Set<String> facilityIds) {
    final currentIds = animals.map((a) => a.definition.id).toSet();
    if (setEquals(currentIds, animalIds) &&
        setEquals(ownedFacilities, facilityIds)) {
      return;
    }
    final existing = {
      for (final animal in animals) animal.definition.id: animal,
    };
    animals = List.unmodifiable([
      for (final definition in world.animals)
        if (animalIds.contains(definition.id))
          existing[definition.id] ??
              AnimalWalker(
                instanceId: '${definition.id}-1',
                definition: definition,
                random: _random,
              ),
    ]);
    ownedFacilities = Set.unmodifiable(facilityIds);
    sceneryRevision.value++;
    notifyListeners();
  }

  void advance(double seconds) {
    if (!seconds.isFinite || seconds <= 0) return;
    final step = min(seconds, 0.1);
    for (final animal in animals) {
      animal.advance(step);
    }
    notifyListeners();
  }

  @override
  void dispose() {
    sceneryRevision.dispose();
    super.dispose();
  }
}
