import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:zoo_study/features/game/data/mock_game_repository.dart';
import 'package:zoo_study/features/game/domain/game_repository.dart';
import 'package:zoo_study/features/game/domain/game_snapshot.dart';
import 'package:zoo_study/features/game/domain/zoo_layout.dart';
import 'package:zoo_study/features/game/presentation/game_session.dart';
import 'package:zoo_study/features/game/presentation/layout_transactions.dart';
import 'package:zoo_study/features/shop/domain/shop_catalog.dart';
import 'package:zoo_study/features/shop/domain/shop_repository.dart';
import 'package:zoo_study/features/zoo/domain/zoo_world.dart';

class LostReply implements GameRepository, ShopRepository {
  final inner = MockGameRepository(
    bonusCoins: 1000,
    worldLoader: () async => ZooWorld.fromJson(
      jsonDecode(File('assets/zoo/world.json').readAsStringSync())
          as Map<String, dynamic>,
    ),
  );
  final calls = <PurchaseRequest>[];
  @override
  GameConnection get connection => GameConnection.demo;
  @override
  Stream<GameSnapshot> watchGameState() => inner.watchGameState();
  @override
  Future<ShopCatalog> loadCatalog() => inner.loadCatalog();
  @override
  Future<PurchaseReceipt> purchase(PurchaseRequest request) async {
    calls.add(request);
    final receipt = await inner.purchase(request);
    if (calls.length == 1) throw StateError('reply lost after commit');
    return receipt;
  }
}

void main() {
  test(
    'lost layout reply retries the same payload without charging twice',
    () async {
      final repository = LostReply();
      final session = GameSession(repository);
      final transactions = LayoutTransactions(session);
      addTearDown(() async {
        transactions.dispose();
        session.dispose();
        await repository.inner.dispose();
      });
      await Future<void>.delayed(Duration.zero);
      expect(
        await transactions.submit(
          const LayoutEdit(
            kind: LayoutEditKind.enclosure,
            id: 'p',
            width: 4,
            height: 4,
          ),
        ),
        isFalse,
      );
      expect(transactions.uncertain, isTrue);
      expect(repository.inner.currentSnapshot.coins, 920);
      expect(await transactions.retry(), isTrue);
      expect(repository.calls, hasLength(2));
      expect(repository.calls.first.requestId, repository.calls.last.requestId);
      expect(
        repository.calls.first.layoutEdit,
        repository.calls.last.layoutEdit,
      );
      expect(repository.inner.currentSnapshot.coins, 920);
    },
  );
}
