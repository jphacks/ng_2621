import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:zoo_study/features/game/data/mock_game_repository.dart';
import 'package:zoo_study/features/game/domain/zoo_layout.dart';
import 'package:zoo_study/features/shop/domain/shop_catalog.dart';
import 'package:zoo_study/features/shop/domain/shop_repository.dart';
import 'package:zoo_study/features/zoo/domain/zoo_world.dart';
import 'package:zoo_study/features/zoo/presentation/zoo_controller.dart';

MockGameRepository repo({int coins = 1000}) => MockGameRepository(
  bonusCoins: coins,
  catalogLoader: () async => ShopCatalog.fromJson(
    jsonDecode(File('assets/zoo/shop_catalog.json').readAsStringSync())
        as Map<String, dynamic>,
  ),
  worldLoader: () async => world(),
);
ZooWorld world() => ZooWorld.fromJson(
  jsonDecode(File('assets/zoo/world.json').readAsStringSync())
      as Map<String, dynamic>,
);
PurchaseRequest edit(
  String key,
  String id, {
  int left = 0,
  int top = 0,
  int width = 4,
  int height = 4,
}) => PurchaseRequest(
  requestId: key,
  itemId: 'zoo_layout',
  layoutEdit: LayoutEdit(
    kind: LayoutEditKind.enclosure,
    id: id,
    left: left,
    top: top,
    width: width,
    height: height,
  ),
);

void main() {
  test('area pricing, incremental expansion and free move are atomic and idempotent', () async {
    final repository = repo();
    addTearDown(repository.dispose);
    final first = edit('create', 'pen1');
    expect((await repository.purchase(first)).price, 80);
    expect(repository.currentSnapshot.coins, 920);
    await repository.purchase(first);
    expect(repository.currentSnapshot.coins, 920);
    expect(
      (await repository.purchase(edit('expand', 'pen1', width: 5))).price,
      20,
    );
    expect(repository.currentSnapshot.coins, 900);
    expect(
      (await repository.purchase(
        edit('move', 'pen1', left: 1, top: 1, width: 5),
      )).price,
      0,
    );
    expect(repository.currentSnapshot.coins, 900);
    repository.receiveDemoScenario(DemoScenario.submitted);
    expect(repository.currentSnapshot.coins, 930);
    expect(repository.currentSnapshot.layout.enclosures['pen1']!.left, 1);
    await repository.purchase(first);
    expect(repository.currentSnapshot.coins, 930);
    expect(
      () => repository.purchase(edit('create', 'pen1', left: 2)),
      throwsA(isA<PurchaseFailure>()),
    );
  });

  test('multiple purchased animals share or change enclosures and stay inside after expansion', () async {
    final repository = repo();
    addTearDown(repository.dispose);
    await repository.purchase(edit('p1', 'pen1'));
    await repository.purchase(edit('p2', 'pen2', left: 11));
    await repository.purchase(
      const PurchaseRequest(requestId: 'rabbit', itemId: 'rabbit'),
    );
    await repository.purchase(
      const PurchaseRequest(requestId: 'fox', itemId: 'fox'),
    );
    for (final animal in ['rabbit', 'fox']) {
      expect(
        (await repository.purchase(
          PurchaseRequest(
            requestId: 'assign-$animal',
            itemId: 'zoo_layout',
            layoutEdit: LayoutEdit(
              kind: LayoutEditKind.assignAnimal,
              id: animal,
              enclosureId: 'pen1',
            ),
          ),
        )).price,
        0,
      );
    }
    final state = repository.currentSnapshot;
    final controller = ZooController(
      world(),
      random: Random(1),
      layout: state.layout,
      ownedAnimalIds: state.ownedAnimalIds,
      ownedFacilityIds: state.ownedFacilityIds,
    );
    addTearDown(controller.dispose);
    expect(controller.animals, hasLength(2));
    final rabbit = controller.animals.first;
    await repository.purchase(edit('expand', 'pen1', width: 5));
    controller.synchronizeLayout(repository.currentSnapshot.layout);
    expect(controller.animals.first, same(rabbit));
    for (var i = 0; i < 1000; i++) {
      controller.advance(0.1);
      for (final animal in controller.animals) {
        expect(animal.movementArea.contains(animal.position), isTrue);
      }
    }
    await repository.purchase(
      const PurchaseRequest(
        requestId: 'reassign',
        itemId: 'zoo_layout',
        layoutEdit: LayoutEdit(
          kind: LayoutEditKind.assignAnimal,
          id: 'fox',
          enclosureId: 'pen2',
        ),
      ),
    );
    controller.synchronizeLayout(repository.currentSnapshot.layout);
    expect(
      controller.animals.firstWhere((a) => a.definition.id == 'fox').position.x,
      greaterThanOrEqualTo(12.5),
    );
  });

  test(
    'invalid edits and insufficient funds never debit or change the layout',
    () async {
      final poor = repo(coins: 20);
      addTearDown(poor.dispose);
      await expectLater(
        poor.purchase(edit('poor', 'p')),
        throwsA(isA<PurchaseFailure>()),
      );
      expect(poor.currentSnapshot.coins, 20);
      expect(poor.currentSnapshot.layout.enclosures, isEmpty);
      final repository = repo();
      addTearDown(repository.dispose);
      await repository.purchase(edit('one', 'p'));
      for (final request in [
        edit('overlap', 'other', left: 1),
        edit('road', 'other', left: 8),
        edit('outside', 'other', left: -1),
        edit('shrink', 'p', width: 3),
      ]) {
        await expectLater(
          repository.purchase(request),
          throwsA(isA<PurchaseFailure>()),
        );
      }
      await expectLater(
        repository.purchase(
          const PurchaseRequest(
            requestId: 'invalid_assignment',
            itemId: 'zoo_layout',
            layoutEdit: LayoutEdit(
              kind: LayoutEditKind.assignAnimal,
              id: 'rabbit',
              enclosureId: 'p',
            ),
          ),
        ),
        throwsA(isA<PurchaseFailure>()),
      );
      expect(repository.currentSnapshot.coins, 920);
      expect(repository.currentSnapshot.layout.enclosures, hasLength(1));
      await expectLater(
        repository.purchase(
          const PurchaseRequest(requestId: 'not_fixed', itemId: 'enclosure'),
        ),
        throwsA(isA<PurchaseFailure>()),
      );
    },
  );

  test('pool cannot be moved over a purchased enclosure', () async {
    final repository = repo();
    addTearDown(repository.dispose);
    await repository.purchase(
      const PurchaseRequest(requestId: 'pond', itemId: 'pond'),
    );
    await repository.purchase(edit('pen', 'p', left: 11));
    await expectLater(
      repository.purchase(
        const PurchaseRequest(
          requestId: 'move_pool',
          itemId: 'zoo_layout',
          layoutEdit: LayoutEdit(
            kind: LayoutEditKind.facility,
            id: 'pond',
            left: 11,
            top: 0,
          ),
        ),
      ),
      throwsA(isA<PurchaseFailure>()),
    );
    expect(repository.currentSnapshot.layout.facilities, isEmpty);
  });
}
