import 'zoo_world.dart';

/// A facility type's location, separate from its footprint and artwork.
/// The current inventory owns one instance per type; no extra purchase occurs.
class FacilityPlacement {
  const FacilityPlacement({
    required this.facilityId,
    required this.left,
    required this.top,
  });
  final String facilityId;
  final int left, top;

  bool contains(int x, int y, FacilityDefinition definition) =>
      x >= left &&
      x < left + definition.width &&
      y >= top &&
      y < top + definition.height;

  Map<String, dynamic> toJson() => {
    'facilityId': facilityId,
    'left': left,
    'top': top,
  };
  factory FacilityPlacement.fromJson(Map<String, dynamic> json) =>
      FacilityPlacement(
        facilityId: json['facilityId'] as String,
        left: json['left'] as int,
        top: json['top'] as int,
      );

  @override
  bool operator ==(Object other) =>
      other is FacilityPlacement &&
      facilityId == other.facilityId &&
      left == other.left &&
      top == other.top;
  @override
  int get hashCode => Object.hash(facilityId, left, top);
}

enum PlacementIssue {
  notOwned('購入済みの施設を選んでください'),
  unknownFacility('施設の定義がありません'),
  outsideMap('施設全体がマップに入る場所を選んでください'),
  blockedTerrain('通路や元からある水辺には設置できません'),
  overlapsFacility('他の施設の配置・予約エリアと重なっています'),
  animalArea('動物のエリアと重なっています');

  const PlacementIssue(this.message);
  final String message;
}

/// Shared placement rules, independent of Flutter, navigation and persistence.
PlacementIssue? validateFacilityPlacement({
  required ZooWorld world,
  required FacilityPlacement placement,
  required Set<String> ownedFacilityIds,
  required Map<String, FacilityPlacement> placements,
}) {
  final definition = world.facilities
      .where((f) => f.id == placement.facilityId)
      .firstOrNull;
  if (definition == null) return PlacementIssue.unknownFacility;
  if (!ownedFacilityIds.contains(placement.facilityId)) {
    return PlacementIssue.notOwned;
  }
  final left = placement.left, top = placement.top;
  final right = left + definition.width, bottom = top + definition.height;
  if (left < 0 || top < 0 || right > world.columns || bottom > world.rows) {
    return PlacementIssue.outsideMap;
  }
  for (var y = top; y < bottom; y++) {
    for (var x = left; x < right; x++) {
      // Water reserved by a movable facility is underlying grass, even after moving it.
      final reservedWater = world.facilities.any(
        (f) => f.tile == 'water' && f.contains(x, y),
      );
      final terrain = world.tiles[y][x];
      if (terrain == '=' ||
          terrain == '#' ||
          (terrain == '~' && !reservedWater)) {
        return PlacementIssue.blockedTerrain;
      }
    }
  }
  for (final other in world.facilities) {
    // Reserve default footprints too, so a later purchase cannot overlap an edited layout.
    if (other.id == definition.id) {
      continue;
    }
    final position =
        placements[other.id] ??
        FacilityPlacement(
          facilityId: other.id,
          left: other.left,
          top: other.top,
        );
    if (left < position.left + other.width &&
        right > position.left &&
        top < position.top + other.height &&
        bottom > position.top) {
      return PlacementIssue.overlapsFacility;
    }
  }
  // Forest is intentionally compatible with animal areas. Water is not.
  if (definition.blocksAnimalAreas) {
    for (final animal in world.animals) {
      final area = animal.area;
      if (left < area.right + 0.5 &&
          right > area.left - 0.5 &&
          top < area.bottom + 0.5 &&
          bottom > area.top - 0.5) {
        return PlacementIssue.animalArea;
      }
    }
  }
  return null;
}
