import '../../game/domain/game_snapshot.dart';

enum ShopItemKind { animal, facility }

enum ShopPricing { fixed, area }

class ShopItem {
  ShopItem({
    required this.id,
    required this.name,
    required this.kind,
    required this.targetId,
    required this.price,
    Iterable<String> requiredAnimalIds = const [],
    this.minimumAnimalSpecies = 0,
    this.pricing = ShopPricing.fixed,
  }) : requiredAnimalIds = Set.unmodifiable(requiredAnimalIds) {
    if (id.isEmpty ||
        name.isEmpty ||
        targetId.isEmpty ||
        price <= 0 ||
        minimumAnimalSpecies < 0) {
      throw const FormatException('Invalid shop item');
    }
  }
  final String id;
  final String name;
  final ShopItemKind kind;
  final String targetId;
  final int price;
  final ShopPricing pricing;
  int get minimumPrice => pricing == ShopPricing.area ? price * 9 : price;
  String get priceLabel =>
      pricing == ShopPricing.area ? '1マス $price コイン' : '$price コイン';
  final Set<String> requiredAnimalIds;
  final int minimumAnimalSpecies;

  bool isOwned(GameSnapshot snapshot) =>
      pricing == ShopPricing.fixed &&
      (kind == ShopItemKind.animal
              ? snapshot.ownedAnimalIds
              : snapshot.ownedFacilityIds)
          .contains(targetId);
  bool isUnlocked(GameSnapshot snapshot) =>
      snapshot.ownedAnimalIds.containsAll(requiredAnimalIds) &&
      snapshot.ownedAnimalIds.length >= minimumAnimalSpecies;

  factory ShopItem.fromJson(Map<String, dynamic> json) => ShopItem(
    id: json['id'] as String,
    name: json['name'] as String,
    kind: ShopItemKind.values.byName(json['kind'] as String),
    targetId: json['targetId'] as String,
    price: json['price'] as int,
    requiredAnimalIds: List<String>.from(
      json['requiredAnimalIds'] as List? ?? [],
    ),
    minimumAnimalSpecies: json['minimumAnimalSpecies'] as int? ?? 0,
    pricing: ShopPricing.values.byName(json['pricing'] as String? ?? 'fixed'),
  );
}

class ShopCatalog {
  ShopCatalog(Iterable<ShopItem> items) : items = List.unmodifiable(items) {
    if (this.items.map((i) => i.id).toSet().length != this.items.length ||
        this.items.map((i) => '${i.kind.name}:${i.targetId}').toSet().length !=
            this.items.length) {
      throw const FormatException('Duplicate shop item');
    }
    final animals = this.items
        .where((i) => i.kind == ShopItemKind.animal)
        .map((i) => i.targetId)
        .toSet();
    if (this.items.any(
      (i) =>
          !animals.containsAll(i.requiredAnimalIds) ||
          i.requiredAnimalIds.contains(i.targetId),
    )) {
      throw const FormatException('Invalid unlock requirements');
    }
  }
  final List<ShopItem> items;

  factory ShopCatalog.fromJson(Map<String, dynamic> json) {
    if (json['schemaVersion'] != 1) {
      throw const FormatException('Unsupported shop schema');
    }
    return ShopCatalog(
      (json['items'] as List).map(
        (i) => ShopItem.fromJson(i as Map<String, dynamic>),
      ),
    );
  }
}
