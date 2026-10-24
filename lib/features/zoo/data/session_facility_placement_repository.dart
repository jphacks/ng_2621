import '../domain/facility_placement.dart';
import '../domain/facility_placement_repository.dart';
import '../../game/domain/zoo_layout.dart';
import '../../game/presentation/layout_transactions.dart';

/// Reuses the confirmed game transaction gateway; no separate coin authority.
class SessionFacilityPlacementRepository
    implements FacilityPlacementRepository {
  SessionFacilityPlacementRepository(this.transactions);
  final LayoutTransactions transactions;
  @override
  Future<Map<String, FacilityPlacement>> load() async =>
      transactions.session.snapshot?.layout.facilities ?? {};
  @override
  Future<void> save(FacilityPlacement placement) async {
    final ok = await transactions.submit(
      LayoutEdit(
        kind: LayoutEditKind.facility,
        id: placement.facilityId,
        left: placement.left,
        top: placement.top,
      ),
    );
    if (!ok) {
      throw StateError(
        transactions.message ?? 'Placement awaiting confirmation',
      );
    }
  }
}
