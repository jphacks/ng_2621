import 'package:flutter/material.dart';

import '../../../core/ui/zoo_ui.dart';
import '../../animals/presentation/animal_art.dart';
import '../domain/shop_catalog.dart';

/// Artwork mapping lives outside the catalog layout and purchase logic.
class ShopItemArt extends StatelessWidget {
  const ShopItemArt({super.key, required this.item, this.size = 48});
  final ShopItem item;
  final double size;

  @override
  Widget build(BuildContext context) {
    if (item.kind == ShopItemKind.animal) {
      return AnimalArt(animalId: item.targetId, size: size);
    }
    final building = ZooBuildingPart.forId(item.targetId);
    if (building != null) {
      return SizedBox.square(
        dimension: size,
        child: FittedBox(child: ZooBuildingSprite(part: building, scale: 1)),
      );
    }
    return SizedBox.square(
      dimension: size,
      child: Center(
        child: switch (item.targetId) {
          'enclosure' => const TerrainSprite(part: TerrainPart.fence, scale: 3),
          'pond' => const ZooArtSprite(part: ZooArtPart.pond, scale: 3),
          'forest' => const ZooArtSprite(part: ZooArtPart.tree, scale: 3),
          _ => const ZooUiSprite(part: ZooUiPart.lock, scale: 3),
        },
      ),
    );
  }
}
