import 'facility_placement.dart';

/// Location storage only. Ownership and coin authority remain with GameRepository.
/// A production adapter can replace the in-memory demo without changing the editor.
abstract interface class FacilityPlacementRepository {
  Future<Map<String, FacilityPlacement>> load();
  Future<void> save(FacilityPlacement placement);
}
