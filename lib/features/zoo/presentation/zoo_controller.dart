import 'dart:math';

import 'package:flutter/foundation.dart';

import '../domain/animal_walker.dart';
import '../domain/zoo_world.dart';
import '../domain/facility_placement.dart';
import '../../game/domain/zoo_layout.dart';

class ZooController extends ChangeNotifier {
  ZooController(
    this.world, {
    Random? random,
    Set<String>? ownedAnimalIds,
    Set<String>? ownedFacilityIds,
    Map<String, FacilityPlacement> initialPlacements = const {},
    ZooLayout? layout,
  }) : _random = random ?? Random(),
       _layout = layout ?? ZooLayout() {
    final restoredPlacements = {..._layout.facilities, ...initialPlacements};
    for (final entry in restoredPlacements.entries) {
      if (entry.key != entry.value.facilityId ||
          validateFacilityPlacement(
                world: world,
                placement: entry.value,
                ownedFacilityIds: world.facilities.map((f) => f.id).toSet(),
                placements: restoredPlacements,
                animalAreas: const [],
              ) !=
              null) {
        throw FormatException('Invalid saved facility placement: ${entry.key}');
      }
    }
    _placements.addAll(restoredPlacements);
    synchronizeOwnership(
      ownedAnimalIds ?? world.animals.map((a) => a.id).toSet(),
      ownedFacilityIds ?? world.facilities.map((f) => f.id).toSet(),
    );
  }
  final ZooWorld world;
  final Random _random;
  List<AnimalWalker> animals = const [];
  Set<String> ownedFacilities = const {};
  Set<String> ownedAnimals = const {};
  ZooLayout _layout;
  ZooLayout get layout => ZooLayout(
    enclosures: _layout.enclosures,
    animalEnclosures: _layout.animalEnclosures,
    facilities: placements,
  );
  void synchronizeLayout(
    ZooLayout next, {
    bool preserveFacilityPlacements = false,
  }) {
    _layout = next;
    if (!preserveFacilityPlacements) {
      _placements
        ..clear()
        ..addAll(next.facilities);
    }
    _rebuildAnimals();
    sceneryRevision.value++;
    notifyListeners();
  }

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

  PlacementIssue? placementIssue(FacilityPlacement placement) {
    final issue = validateFacilityPlacement(
      world: world,
      placement: placement,
      ownedFacilityIds: ownedFacilities,
      placements: placements,
      animalAreas: const [],
    );
    if (issue != null) return issue;
    final definition = world.facilities.firstWhere(
      (f) => f.id == placement.facilityId,
    );
    if (definition.blocksAnimalAreas &&
        layout.enclosures.values.any(
          (p) =>
              placement.left < p.left + p.width &&
              placement.left + definition.width > p.left &&
              placement.top < p.top + p.height &&
              placement.top + definition.height > p.top,
        )) {
      return PlacementIssue.animalArea;
    }
    return null;
  }

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
    if (setEquals(ownedAnimals, animalIds) &&
        setEquals(ownedFacilities, facilityIds)) {
      return;
    }
    ownedAnimals = Set.unmodifiable(animalIds);
    _rebuildAnimals();
    ownedFacilities = Set.unmodifiable(facilityIds);
    sceneryRevision.value++;
    notifyListeners();
  }

  void _rebuildAnimals() {
    final existing = {
      for (final animal in animals) animal.definition.id: animal,
    };
    animals = List.unmodifiable([
      for (final definition in world.animals)
        if (ownedAnimals.contains(definition.id) &&
            _layout.enclosures.containsKey(
              _layout.animalEnclosures[definition.id],
            ))
          existing[definition.id] ??
              AnimalWalker(
                instanceId: '${definition.id}-1',
                definition: definition,
                random: _random,
                area: _layout
                    .enclosures[_layout.animalEnclosures[definition.id]]!
                    .movementArea,
              ),
    ]);
    for (final animal in animals) {
      animal.setMovementArea(
        _layout
            .enclosures[_layout.animalEnclosures[animal.definition.id]]!
            .movementArea,
      );
    }
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
