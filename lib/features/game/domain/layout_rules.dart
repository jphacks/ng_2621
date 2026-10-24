import 'zoo_layout.dart';
import '../../zoo/domain/zoo_world.dart';
import '../../zoo/domain/facility_placement.dart';

const enclosureCoinPerTile = 5;

String? validateEnclosure(
  ZooWorld world,
  ZooLayout layout,
  Enclosure candidate,
  Set<String> ownedFacilities,
) {
  if (candidate.id.isEmpty || candidate.width < 3 || candidate.height < 3) {
    return '幅・高さは3マス以上にしてください';
  }
  if (candidate.left < 0 ||
      candidate.top < 0 ||
      candidate.left + candidate.width > world.columns ||
      candidate.top + candidate.height > world.rows) {
    return '囲い全体がマップに入る場所を選んでください';
  }
  final previous = layout.enclosures[candidate.id];
  if (previous != null &&
      (candidate.width < previous.width || candidate.height < previous.height)) {
    return '囲いは縮小できません';
  }
  bool overlaps(int left, int top, int width, int height) =>
      candidate.left < left + width &&
      candidate.left + candidate.width > left &&
      candidate.top < top + height &&
      candidate.top + candidate.height > top;
  for (final other in layout.enclosures.values) {
    if (other.id != candidate.id &&
        overlaps(other.left, other.top, other.width, other.height)) {
      return '他の囲いと重なっています';
    }
  }
  for (var y = candidate.top; y < candidate.top + candidate.height; y++) {
    for (var x = candidate.left; x < candidate.left + candidate.width; x++) {
      var tile = world.tiles[y][x];
      if (world.facilities.any((f) => f.tile == 'water' && f.contains(x, y))) {
        tile = '.';
      }
      if (tile != '.') return '通路や水辺には設置できません';
    }
  }
  for (final facility in world.facilities) {
    if (facility.tile == 'forest') continue;
    final position =
        layout.facilities[facility.id] ??
        FacilityPlacement(
          facilityId: facility.id,
          left: facility.left,
          top: facility.top,
        );
    if (overlaps(position.left, position.top, facility.width, facility.height)) {
      return '施設と重なっています';
    }
  }
  return null;
}

int enclosureEditPrice(Enclosure candidate, Enclosure? previous) =>
    (candidate.area - (previous?.area ?? 0)) * enclosureCoinPerTile;
