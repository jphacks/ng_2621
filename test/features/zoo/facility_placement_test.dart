import '../../support/layout_fixtures.dart';

import 'package:flutter_test/flutter_test.dart';
import 'package:zoo_study/features/zoo/domain/facility_placement.dart';
import 'package:zoo_study/features/zoo/domain/zoo_world.dart';
import 'package:zoo_study/features/zoo/presentation/zoo_controller.dart';
import 'package:zoo_study/features/zoo/data/memory_facility_placement_repository.dart';

ZooWorld placementWorld() => ZooWorld(
  columns: 10,
  rows: 10,
  tileSize: 16,
  tiles: List.generate(10, (y) => y == 4 ? '==========' : '..........'),
  animals: const [
    AnimalDefinition(
      id: 'test',
      name: '動物',
      imagePath: null,
      speed: 1,
      area: MovementArea(1.5, 6.5, 3.5, 8.5),
      placeholderColor: 0xFFFFFFFF,
    ),
  ],
  facilities: const [
    FacilityDefinition(
      id: 'pond',
      name: '池',
      tile: 'water',
      left: 1,
      top: 1,
      width: 2,
      height: 2,
    ),
    FacilityDefinition(
      id: 'forest',
      name: '森',
      tile: 'forest',
      left: 6,
      top: 6,
      width: 2,
      height: 2,
    ),
  ],
);

void main() {
  test('placement rules reject invalid ownership, bounds, roads, facilities and animal areas', () {
    final world = placementWorld();
    PlacementIssue? issue(
      int x,
      int y, {
      Set<String> owned = const {'pond', 'forest'},
      String id = 'pond',
    }) => validateFacilityPlacement(
      world: world,
      placement: FacilityPlacement(facilityId: id, left: x, top: y),
      ownedFacilityIds: owned,
      placements: const {},
    );
    expect(issue(1, 1), isNull);
    expect(issue(1, 1, owned: {}), PlacementIssue.notOwned);
    expect(issue(1, 1, id: 'missing'), PlacementIssue.unknownFacility);
    expect(issue(-1, 1), PlacementIssue.outsideMap);
    expect(issue(9, 9), PlacementIssue.outsideMap);
    expect(issue(1, 3), PlacementIssue.blockedTerrain);
    expect(issue(6, 6), PlacementIssue.overlapsFacility);
    expect(issue(6, 6, owned: {'pond'}), PlacementIssue.overlapsFacility);
    expect(
      issue(2, 7),
      isNull,
    ); // Legacy animal definition areas no longer reserve map space.
    expect(issue(0, 0), isNull);
  });

  test('confirmed locations round trip and do not reset walkers on ownership refresh', () async {
    final world = placementWorld();
    final store = MemoryFacilityPlacementRepository();
    final controller = ZooController(
      world,
      ownedAnimalIds: {'test'},
      layout: testLayout(['test']),
      ownedFacilityIds: {'pond'},
    );
    addTearDown(controller.dispose);
    final walker = controller.animals.single;
    const position = FacilityPlacement(facilityId: 'pond', left: 5, top: 1);
    expect(FacilityPlacement.fromJson(position.toJson()), position);
    expect(await store.load(), isEmpty);
    await store.save(position);
    expect(controller.placeFacility(position), isTrue);
    controller.synchronizeOwnership({'test'}, {'pond', 'forest'});
    expect(controller.animals.single, same(walker));
    expect(controller.positionOf(world.facilities.first), position);
    final restored = ZooController(
      world,
      initialPlacements: await store.load(),
      ownedFacilityIds: {'pond'},
    );
    addTearDown(restored.dispose);
    expect(restored.positionOf(world.facilities.first), position);
    expect(
      controller.placeFacility(
        const FacilityPlacement(facilityId: 'pond', left: -1, top: 0),
      ),
      isFalse,
    );
    expect(controller.positionOf(world.facilities.first), position);
  });
  test('invalid stored layouts are rejected before rendering', () {
    expect(
      () => ZooController(
        placementWorld(),
        initialPlacements: const {
          'pond': FacilityPlacement(facilityId: 'pond', left: 9, top: 9),
        },
      ),
      throwsFormatException,
    );
  });
}
