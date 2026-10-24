import 'dart:math';

import 'package:flutter/foundation.dart';

import '../domain/animal_walker.dart';
import '../domain/zoo_world.dart';
import '../domain/facility_placement.dart';

class ZooController extends ChangeNotifier {
  ZooController(
    this.world, {
    Random? random,
    Set<String>? ownedAnimalIds,
    Set<String>? ownedFacilityIds,
    Map<String, FacilityPlacement> initialPlacements = const {},
  }) : _random = random ?? Random() {
    for (final entry in initialPlacements.entries) {
      if (entry.key != entry.value.facilityId ||
          validateFacilityPlacement(
                world: world,
                placement: entry.value,
                ownedFacilityIds: world.facilities.map((f) => f.id).toSet(),
                placements: initialPlacements,
              ) !=
              null) {
        throw FormatException('Invalid saved facility placement: ${entry.key}');
      }
    }
    _placements.addAll(initialPlacements);
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
  final _placements = <String, FacilityPlacement>{};
  Map<String, FacilityPlacement> get placements =>
      Map.unmodifiable(_placements);

  FacilityPlacement positionOf(FacilityDefinition definition) =>
      _placements[definition.id] ??
      FacilityPlacement(
        facilityId: definition.id,
        left: definition.left,
        top: definition.top,
      );

  PlacementIssue? placementIssue(FacilityPlacement placement) =>
      validateFacilityPlacement(
        world: world,
        placement: placement,
        ownedFacilityIds: ownedFacilities,
        placements: placements,
      );

  /// Called only after the repository accepted a placement. Never changes inventory.
  bool placeFacility(FacilityPlacement placement) {
    if (placementIssue(placement) != null) return false;
    if (_placements[placement.facilityId] == placement) return true;
    _placements[placement.facilityId] = placement;
    sceneryRevision.value++;
    notifyListeners();
    return true;
  }

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
