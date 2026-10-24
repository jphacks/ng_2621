import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:zoo_study/features/game/data/mock_game_repository.dart';
import 'package:zoo_study/features/game/domain/game_repository.dart';
import 'package:zoo_study/features/game/domain/game_snapshot.dart';
import 'package:zoo_study/features/game/presentation/game_session.dart';
import 'package:zoo_study/features/shop/domain/shop_catalog.dart';
import 'package:zoo_study/features/shop/domain/shop_repository.dart';
import 'package:zoo_study/features/shop/presentation/shop_purchase_controller.dart';

ShopItem rabbit() => ShopItem(
  id: 'rabbit',
  name: 'ウサギ',
  kind: ShopItemKind.animal,
  targetId: 'rabbit',
  price: 100,
);
GameSnapshot owned() {
  final data = MockGameRepository.snapshotFor(
    DemoScenario.approved,
    revision: 5,
  ).toJson();
  data['coins'] = 0;
  data['ownedAnimalIds'] = ['rabbit'];
  return GameSnapshot.fromJson(data);
}

(_Repository, GameSession, ShopPurchaseController) setup({
  Duration timeout = const Duration(seconds: 20),
}) {
  final repository = _Repository();
  final session = GameSession(repository);
  final purchases = ShopPurchaseController(session, purchaseTimeout: timeout);
  repository.events.add(MockGameRepository.snapshotFor(DemoScenario.approved));
  addTearDown(() async {
    purchases.dispose();
    session.dispose();
    await repository.events.close();
  });
  return (repository, session, purchases);
}

void main() {
  test(
    'busy prevents duplicate commands and receipt waits for owned snapshot',
    () async {
      final (repository, session, purchases) = setup();
      final completion = Completer<PurchaseReceipt>();
      repository.handler = (_) => completion.future;
      final pending = purchases.buy(rabbit());
      await purchases.buy(rabbit());
      expect(repository.calls, hasLength(1));
      expect(purchases.busy, isTrue);
      expect(session.snapshot!.coins, 100);
      final request = repository.calls.single;
      completion.complete(
        PurchaseReceipt(
          requestId: request.requestId,
          itemId: 'rabbit',
          price: 100,
          revision: 5,
        ),
      );
      await pending;
      expect(purchases.awaitingSnapshot, isTrue);
      expect(session.snapshot!.coins, 100);
      await purchases.buy(rabbit());
      expect(repository.calls, hasLength(1));
      repository.events.add(owned());
      expect(purchases.awaitingSnapshot, isFalse);
      expect(session.snapshot!.coins, 0);
    },
  );

  test(
    'ambiguous outcomes retain key and block a fresh purchase until resolved',
    () async {
      final (repository, session, purchases) = setup();
      repository.handler = (_) async => throw StateError('connection lost');
      await purchases.buy(rabbit());
      expect(purchases.uncertain, isTrue);
      await purchases.buy(rabbit());
      expect(repository.calls, hasLength(1));
      repository.handler = (request) async => PurchaseReceipt(
        requestId: request.requestId,
        itemId: 'rabbit',
        price: 100,
        revision: 5,
      );
      await purchases.retry();
      expect(repository.calls, hasLength(2));
      expect(repository.calls.first.requestId, repository.calls.last.requestId);
      expect(purchases.status, PurchaseStatus.success);
      expect(session.snapshot!.coins, 100); // UI never mutates confirmed state.
    },
  );

  test(
    'timeout becomes uncertain and a late reply cannot consume the retry key',
    () async {
      final (repository, _, purchases) = setup(
        timeout: const Duration(milliseconds: 1),
      );
      final completion = Completer<PurchaseReceipt>();
      repository.handler = (_) => completion.future;
      await purchases.buy(rabbit());
      expect(purchases.uncertain, isTrue);
      final key = repository.calls.single.requestId;
      completion.complete(
        PurchaseReceipt(
          requestId: key,
          itemId: 'rabbit',
          price: 100,
          revision: 5,
        ),
      );
      await Future<void>.delayed(Duration.zero);
      expect(purchases.uncertain, isTrue);
      repository.handler = (request) async => PurchaseReceipt(
        requestId: request.requestId,
        itemId: 'rabbit',
        price: 100,
        revision: 5,
      );
      await purchases.retry();
      expect(repository.calls.last.requestId, key);
      expect(purchases.status, PurchaseStatus.success);
    },
  );

  test('definitive rejection can start a new attempt with a new key', () async {
    final (repository, _, purchases) = setup();
    repository.handler = (_) async =>
        throw const PurchaseFailure(PurchaseFailureCode.insufficientCoins);
    await purchases.buy(rabbit());
    await purchases.buy(rabbit());
    expect(purchases.status, PurchaseStatus.rejected);
    expect(repository.calls, hasLength(2));
    expect(
      repository.calls.first.requestId,
      isNot(repository.calls.last.requestId),
    );
  });

  test(
    'fresh balance and ownership are rechecked after confirmation',
    () async {
      final (repository, _, purchases) = setup();
      final changed = owned().toJson()..['ownedAnimalIds'] = <String>[];
      repository.events.add(GameSnapshot.fromJson(changed));
      await purchases.buy(rabbit());
      expect(repository.calls, isEmpty);
      expect(purchases.message, contains('コインが足りません'));
    },
  );

  test('mismatched server receipt is uncertain and keeps retry key', () async {
    final (repository, _, purchases) = setup();
    repository.handler = (_) async => const PurchaseReceipt(
      requestId: 'wrong',
      itemId: 'rabbit',
      price: 100,
      revision: 5,
    );
    await purchases.buy(rabbit());
    expect(purchases.status, PurchaseStatus.uncertain);
    await purchases.retry();
    expect(repository.calls.first.requestId, repository.calls.last.requestId);
  });
}

class _Repository implements GameRepository, ShopRepository {
  final events = StreamController<GameSnapshot>.broadcast(sync: true);
  final calls = <PurchaseRequest>[];
  late Future<PurchaseReceipt> Function(PurchaseRequest) handler;
  @override
  GameConnection get connection => GameConnection.demo;
  @override
  Stream<GameSnapshot> watchGameState() => events.stream;
  @override
  Future<ShopCatalog> loadCatalog() async => ShopCatalog([rabbit()]);
  @override
  Future<PurchaseReceipt> purchase(PurchaseRequest request) {
    calls.add(request);
    return handler(request);
  }
}
