import '../domain/facility_placement.dart';
import '../domain/facility_placement_repository.dart';

/// Session-only demo storage, matching the existing demo inventory lifetime.
class MemoryFacilityPlacementRepository implements FacilityPlacementRepository {
  final _placements = <String, FacilityPlacement>{};
  @override
  Future<Map<String, FacilityPlacement>> load() async =>
      Map.unmodifiable(_placements);
  @override
  Future<void> save(FacilityPlacement placement) async {
    _placements[placement.facilityId] = placement;
  }
}
