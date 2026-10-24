import '../../game/domain/game_snapshot.dart';
import '../domain/shop_catalog.dart';

/// View-only filtering; catalog order, prices and purchase rules stay intact.
class ShopCatalogFilter {
  const ShopCatalogFilter({
    required this.kind,
    this.query = '',
    this.purchasableOnly = false,
    this.hideOwned = false,
  });
  final ShopItemKind kind;
  final String query;
  final bool purchasableOnly, hideOwned;

  List<ShopItem> apply(
    ShopCatalog catalog,
    GameSnapshot? snapshot, {
    required bool connected,
  }) {
    final term = query.trim().toLowerCase();
    return catalog.items
        .where((item) {
          if (item.kind != kind || !item.name.toLowerCase().contains(term)) {
            return false;
          }
          final owned = snapshot != null && item.isOwned(snapshot);
          if (hideOwned && owned) return false;
          if (purchasableOnly &&
              (!connected ||
                  snapshot == null ||
                  owned ||
                  !item.isUnlocked(snapshot) ||
                  snapshot.coins < item.minimumPrice)) {
            return false;
          }
          return true;
        })
        .toList(growable: false);
  }
}
