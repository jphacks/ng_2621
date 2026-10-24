import '../domain/game_snapshot.dart';
import '../domain/zoo_layout.dart';
import '../domain/layout_rules.dart';
import '../../zoo/domain/facility_placement.dart';
import '../../zoo/domain/zoo_world.dart';
import '../../shop/domain/shop_repository.dart';

class LayoutMutation {
  const LayoutMutation(this.layout, this.price);
  final ZooLayout layout;
  final int price;
}

LayoutMutation applyLayoutEdit(
  GameSnapshot state,
  ZooWorld world,
  LayoutEdit edit,
) {
  final pens = {...state.layout.enclosures};
  final animals = {...state.layout.animalEnclosures};
  final facilities = {...state.layout.facilities};
  var price = 0;
  switch (edit.kind) {
    case LayoutEditKind.enclosure:
      final next = Enclosure(
        id: edit.id,
        left: edit.left,
        top: edit.top,
        width: edit.width,
        height: edit.height,
      );
      if (validateEnclosure(
            world,
            state.layout,
            next,
            state.ownedFacilityIds,
          ) !=
          null) {
        throw const PurchaseFailure(PurchaseFailureCode.invalidRequest);
      }
      price = enclosureEditPrice(next, pens[edit.id]);
      pens[edit.id] = next;
    case LayoutEditKind.assignAnimal:
      if (!state.ownedAnimalIds.contains(edit.id) ||
          !pens.containsKey(edit.enclosureId)) {
        throw const PurchaseFailure(PurchaseFailureCode.invalidRequest);
      }
      animals[edit.id] = edit.enclosureId!;
    case LayoutEditKind.facility:
      final next = FacilityPlacement(
        facilityId: edit.id,
        left: edit.left,
        top: edit.top,
      );
      if (validateFacilityPlacement(
            world: world,
            placement: next,
            ownedFacilityIds: state.ownedFacilityIds,
            placements: facilities,
            animalAreas: const [],
          ) !=
          null) {
        throw const PurchaseFailure(PurchaseFailureCode.invalidRequest);
      }
      final definition = world.facilities.firstWhere((f) => f.id == edit.id);
      if (definition.blocksAnimalAreas &&
          pens.values.any(
            (p) =>
                next.left < p.left + p.width &&
                next.left + definition.width > p.left &&
                next.top < p.top + p.height &&
                next.top + definition.height > p.top,
          )) {
        throw const PurchaseFailure(PurchaseFailureCode.invalidRequest);
      }
      facilities[edit.id] = next;
  }
  if (price < 0) {
    throw const PurchaseFailure(PurchaseFailureCode.invalidRequest);
  }
  if (state.coins < price) {
    throw const PurchaseFailure(PurchaseFailureCode.insufficientCoins);
  }
  return LayoutMutation(
    ZooLayout(
      enclosures: pens,
      animalEnclosures: animals,
      facilities: facilities,
    ),
    price,
  );
}
