import 'package:flutter/material.dart';

import '../../../core/ui/zoo_ui.dart';
import '../../game/domain/game_snapshot.dart';
import '../domain/shop_catalog.dart';
import 'shop_item_art.dart';

/// A browsing tile, intentionally without purchase controls or unlock prose.
/// Locked and owned products remain inspectable in the detail route.
class ShopItemCard extends StatelessWidget {
  const ShopItemCard({
    super.key,
    required this.item,
    required this.snapshot,
    required this.available,
    required this.onTap,
    this.highlighted = false,
  });
  final ShopItem item;
  final GameSnapshot? snapshot;
  final bool available;
  final VoidCallback onTap;
  final bool highlighted;

  @override
  Widget build(BuildContext context) {
    final state = snapshot;
    final owned = state != null && item.isOwned(state);
    final unlocked = state != null && item.isUnlocked(state);
    final status = owned
        ? '購入済み'
        : !available || state == null
        ? '未接続'
        : !unlocked
        ? '未解放'
        : state.coins < item.minimumPrice
        ? 'コイン不足'
        : '購入可';
    return TutorialHighlight(
      active: highlighted,
      child: Semantics(
        button: true,
        label: '${item.name}、${item.price}コイン、$status',
        excludeSemantics: true,
        child: SpritePanel(
          child: PixelTextOutline(
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                key: ValueKey('shop-item-${item.id}'),
                onTap: onTap,
                child: Padding(
                  padding: const EdgeInsets.all(8),
                  child: Tooltip(
                    message: '${item.name}・${item.priceLabel}・$status',
                    excludeFromSemantics: true,
                    child: Stack(
                      children: [
                        Positioned.fill(
                          child: FittedBox(child: ShopItemArt(item: item)),
                        ),
                        if (owned || !unlocked)
                          Positioned(
                            right: 0,
                            bottom: 0,
                            child: ZooUiSprite(
                              part: owned ? ZooUiPart.check : ZooUiPart.lock,
                              scale: 1,
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
