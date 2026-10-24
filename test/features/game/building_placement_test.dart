import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:zoo_study/core/ui/zoo_ui.dart';
import 'package:zoo_study/features/game/data/mock_game_repository.dart';
import 'package:zoo_study/features/game/domain/game_snapshot.dart';
import 'package:zoo_study/features/game/domain/zoo_layout.dart';
import 'package:zoo_study/features/shop/domain/shop_catalog.dart';
import 'package:zoo_study/features/shop/domain/shop_repository.dart';
import 'package:zoo_study/features/zoo/domain/zoo_world.dart';

void main() {
  test('each building can be purchased, placed, moved and restored without extra charges', () async {
    final world = ZooWorld.fromJson(
      jsonDecode(File('assets/zoo/world.json').readAsStringSync())
          as Map<String, dynamic>,
    );
    final catalog = ShopCatalog.fromJson(
      jsonDecode(File('assets/zoo/shop_catalog.json').readAsStringSync())
          as Map<String, dynamic>,
    );
    for (final definition in world.facilities.where(
      (f) => f.tile == 'sprite',
    )) {
      expect(ZooBuildingPart.forId(definition.spriteId), isNotNull);
      final repository = MockGameRepository(
        bonusCoins: 2000,
        catalogLoader: () async => catalog,
        worldLoader: () async => world,
      );
      addTearDown(repository.dispose);
      final item = catalog.items.singleWhere(
        (i) => i.targetId == definition.id,
      );
      final purchase = PurchaseRequest(requestId: 'buy', itemId: item.id);
      await repository.purchase(purchase);
      await repository.purchase(purchase);
      expect(repository.currentSnapshot.coins, 2000 - item.price);
      expect(
        repository.currentSnapshot.ownedFacilityIds,
        contains(definition.id),
      );
      expect(repository.currentSnapshot.layout.facilities, isEmpty);
      PurchaseRequest place(String key, int x, int y) => PurchaseRequest(
        requestId: key,
        itemId: 'zoo_layout',
        layoutEdit: LayoutEdit(
          kind: LayoutEditKind.facility,
          id: definition.id,
          left: x,
          top: y,
        ),
      );
      await repository.purchase(place('place', 11, 0));
      await repository.purchase(place('move', 15, 5));
      expect(repository.currentSnapshot.coins, 2000 - item.price);
      final restored = GameSnapshot.fromJson(
        repository.currentSnapshot.toJson(),
      );
      expect(restored.layout.facilities[definition.id]!.left, 15);
      expect(restored.layout.facilities[definition.id]!.top, 5);
      await expectLater(
        repository.purchase(place('road', 9, 8)),
        throwsA(isA<PurchaseFailure>()),
      );
      expect(
        repository.currentSnapshot.layout.facilities[definition.id]!.left,
        15,
      );
      // A placed building occupies land and cannot be covered by a new enclosure.
      await expectLater(
        repository.purchase(
          const PurchaseRequest(
            requestId: 'overlap',
            itemId: 'zoo_layout',
            layoutEdit: LayoutEdit(
              kind: LayoutEditKind.enclosure,
              id: 'p',
              left: 14,
              top: 4,
              width: 4,
              height: 3,
            ),
          ),
        ),
        throwsA(isA<PurchaseFailure>()),
      );
      expect(repository.currentSnapshot.coins, 2000 - item.price);
    }
  });
}
