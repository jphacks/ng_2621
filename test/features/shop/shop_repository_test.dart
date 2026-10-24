import '../../support/layout_fixtures.dart';

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:zoo_study/features/game/data/mock_game_repository.dart';
import 'package:zoo_study/features/game/domain/game_snapshot.dart';
import 'package:zoo_study/features/game/presentation/game_session.dart';
import 'package:zoo_study/features/shop/domain/shop_catalog.dart';
import 'package:zoo_study/features/shop/domain/shop_repository.dart';
import 'package:zoo_study/features/zoo/domain/zoo_world.dart';
import 'package:zoo_study/features/zoo/presentation/zoo_controller.dart';

ShopCatalog catalog() => ShopCatalog.fromJson(
  jsonDecode(File('assets/zoo/shop_catalog.json').readAsStringSync())
      as Map<String, dynamic>,
);
ZooWorld world() => ZooWorld.fromJson(
  jsonDecode(File('assets/zoo/world.json').readAsStringSync())
      as Map<String, dynamic>,
);

Future<(MockGameRepository, GameSession)> setup(int coins) async {
  final repository = MockGameRepository(
    scenario: DemoScenario.approved,
    catalogLoader: () async => catalog(),
  );
  // Explicit test fixture funding; not an application API to grant coins.
  final data = MockGameRepository.snapshotFor(
    DemoScenario.approved,
    revision: 10,
  ).toJson()..['coins'] = coins;
  repository.receiveConfirmedSnapshot(GameSnapshot.fromJson(data));
  final session = GameSession(repository);
  await Future<void>.delayed(Duration.zero);
  addTearDown(() async {
    session.dispose();
    await repository.dispose();
  });
  return (repository, session);
}

Matcher failure(PurchaseFailureCode code) =>
    isA<PurchaseFailure>().having((error) => error.code, 'code', code);

void main() {
  test(
    'debug bonus survives rewards, purchases and repeated result reception',
    () async {
      final repository = MockGameRepository(
        bonusCoins: 1000,
        catalogLoader: () async => catalog(),
      );
      final session = GameSession(repository);
      addTearDown(() async {
        session.dispose();
        await repository.dispose();
      });
      await Future<void>.delayed(Duration.zero);
      expect(session.snapshot!.coins, 1000);
      expect(session.snapshot!.rewards, isEmpty);
      repository.receiveDemoScenario(DemoScenario.submitted);
      expect(session.snapshot!.coins, 1030);
      repository.receiveDemoScenario(DemoScenario.approved);
      expect(session.snapshot!.coins, 1100);
      await repository.purchase(
        const PurchaseRequest(requestId: 'bonus-rabbit', itemId: 'rabbit'),
      );
      repository.receiveDemoScenario(DemoScenario.approved);
      expect(session.snapshot!.coins, 1000);
      expect(session.snapshot!.ownedAnimalIds, {'rabbit'});
      expect(session.snapshot!.rewards, hasLength(2));
    },
  );

  test(
    'catalog uses specified prices and every target has a valid map definition',
    () {
      final data = catalog();
      expect(
        {for (final item in data.items) item.id: item.price},
        {
          'rabbit': 100,
          'fox': 250,
          'deer': 400,
          'pond': 200,
          'forest': 500,
          'evolved_fox': 800,
          'enclosure': 5,
        },
      );
      final map = world();
      for (final item in data.items) {
        expect(
          item.pricing == ShopPricing.area ||
              (item.kind == ShopItemKind.animal
                  ? map.animals.any((a) => a.id == item.targetId)
                  : map.facilities.any((f) => f.id == item.targetId)),
          isTrue,
        );
      }
    },
  );

  test(
    'confirmed 100 coins buys rabbit and publishes zero balance with ownership',
    () async {
      final (repository, session) = await setup(100);
      final receipt = await repository.purchase(
        const PurchaseRequest(requestId: 'purchase-1', itemId: 'rabbit'),
      );
      expect(receipt.price, 100);
      expect(receipt.revision, session.snapshot!.revision);
      expect(session.snapshot!.coins, 0);
      expect(session.snapshot!.ownedAnimalIds, {'rabbit'});
    },
  );

  test('insufficient coins, unknown item and invalid request leave state unchanged', () async {
    final (repository, session) = await setup(30);
    final before = session.snapshot!.toJson();
    await expectLater(
      repository.purchase(
        const PurchaseRequest(requestId: 'short', itemId: 'rabbit'),
      ),
      throwsA(failure(PurchaseFailureCode.insufficientCoins)),
    );
    await expectLater(
      repository.purchase(
        const PurchaseRequest(requestId: 'missing', itemId: 'missing'),
      ),
      throwsA(failure(PurchaseFailureCode.unknownItem)),
    );
    await expectLater(
      repository.purchase(
        const PurchaseRequest(requestId: '', itemId: 'rabbit'),
      ),
      throwsA(failure(PurchaseFailureCode.invalidRequest)),
    );
    expect(session.snapshot!.toJson(), before);
  });

  test(
    'prerequisite and species gates are enforced before coins are spent',
    () async {
      final (repository, session) = await setup(2000);
      await expectLater(
        repository.purchase(
          const PurchaseRequest(requestId: 'locked-deer', itemId: 'deer'),
        ),
        throwsA(failure(PurchaseFailureCode.locked)),
      );
      await expectLater(
        repository.purchase(
          const PurchaseRequest(requestId: 'locked-forest', itemId: 'forest'),
        ),
        throwsA(failure(PurchaseFailureCode.locked)),
      );
      expect(session.snapshot!.coins, 2000);
      for (final id in ['rabbit', 'fox', 'deer', 'forest']) {
        await repository.purchase(
          PurchaseRequest(requestId: 'buy-$id', itemId: id),
        );
      }
      expect(session.snapshot!.coins, 750);
      expect(session.snapshot!.ownedAnimalIds, {'rabbit', 'fox', 'deer'});
      expect(session.snapshot!.ownedFacilityIds, {'forest'});
    },
  );

  test(
    'concurrent same-key retries return original receipt exactly once',
    () async {
      final (repository, session) = await setup(100);
      const request = PurchaseRequest(requestId: 'replay', itemId: 'rabbit');
      final results = await Future.wait([
        repository.purchase(request),
        repository.purchase(request),
      ]);
      expect(identical(results.first, results.last), isTrue);
      expect(session.snapshot!.coins, 0);
      expect(session.snapshot!.revision, 11);
      expect(session.snapshot!.ownedAnimalIds, {'rabbit'});
      await expectLater(
        repository.purchase(
          const PurchaseRequest(requestId: 'replay', itemId: 'fox'),
        ),
        throwsA(failure(PurchaseFailureCode.requestConflict)),
      );
    },
  );

  test(
    'different concurrent requests cannot purchase the same animal twice',
    () async {
      final (repository, session) = await setup(100);
      final results = await Future.wait<Object>([
        for (final key in ['a', 'b'])
          repository
              .purchase(PurchaseRequest(requestId: key, itemId: 'rabbit'))
              .then<Object>(
                (receipt) => receipt,
                onError: (Object error) => error,
              ),
      ]);
      expect(results.whereType<PurchaseReceipt>(), hasLength(1));
      expect(
        results.whereType<PurchaseFailure>().single.code,
        PurchaseFailureCode.alreadyOwned,
      );
      expect(session.snapshot!.coins, 0);
    },
  );

  test(
    'evolution unlock adds a new species without consuming original fox',
    () async {
      final (repository, session) = await setup(1100);
      await repository.purchase(
        const PurchaseRequest(requestId: 'fox', itemId: 'fox'),
      );
      await repository.purchase(
        const PurchaseRequest(requestId: 'evolve', itemId: 'evolved_fox'),
      );
      expect(session.snapshot!.ownedAnimalIds, {'fox', 'evolved_fox'});
      expect(session.snapshot!.coins, 50);
    },
  );

  test('facility purchase and reward-result replays preserve spending and ownership', () async {
    final (repository, session) = await setup(300);
    await repository.purchase(
      const PurchaseRequest(requestId: 'pond', itemId: 'pond'),
    );
    await repository.purchase(
      const PurchaseRequest(requestId: 'rabbit', itemId: 'rabbit'),
    );
    repository.receiveDemoScenario(DemoScenario.approved);
    repository.receiveDemoScenario(DemoScenario.approved);
    expect(session.snapshot!.coins, 0);
    expect(session.snapshot!.ownedAnimalIds, {'rabbit'});
    expect(session.snapshot!.ownedFacilityIds, {'pond'});
  });

  test(
    'map synchronizes owned animals and facilities without resetting walkers',
    () {
      final controller = ZooController(
        world(),
        layout: testLayout(['fox', 'evolved_fox']),
        ownedAnimalIds: {},
        ownedFacilityIds: {},
      );
      addTearDown(controller.dispose);
      expect(controller.animals, isEmpty);
      controller.synchronizeOwnership({'fox'}, {'pond'});
      final fox = controller.animals.single;
      for (var i = 0; i < 40; i++) {
        controller.advance(0.1);
      }
      final position = fox.position;
      controller.synchronizeOwnership(
        {'fox', 'evolved_fox'},
        {'pond', 'forest'},
      );
      expect(
        identical(
          controller.animals.firstWhere((a) => a.definition.id == 'fox'),
          fox,
        ),
        isTrue,
      );
      expect(fox.position, position);
      expect(controller.ownedFacilities, {'pond', 'forest'});
    },
  );
}
