import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zoo_study/features/game/data/mock_game_repository.dart';
import 'package:zoo_study/features/game/domain/game_repository.dart';
import 'package:zoo_study/features/game/domain/game_snapshot.dart';
import 'package:zoo_study/features/game/presentation/game_session.dart';
import 'package:zoo_study/features/shop/domain/shop_catalog.dart';
import 'package:zoo_study/features/shop/domain/shop_repository.dart';
import 'package:zoo_study/features/shop/presentation/shop_panel.dart';
import 'package:zoo_study/features/shop/presentation/shop_purchase_controller.dart';

Future<void> frames(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
  await tester.pump(const Duration(milliseconds: 300));
}

void main() {
  testWidgets(
    'purchase cancellation sends no command and a later confirmation works',
    (tester) async {
      final repository = _Repository();
      final session = GameSession(repository);
      addTearDown(session.dispose);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(child: ShopPanel(session: session)),
          ),
        ),
      );
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('buy-rabbit')));
      await frames(tester);
      expect(find.text('ウサギを購入しますか？'), findsOneWidget);
      expect(find.text('購入後 0 コイン（見込み）'), findsOneWidget);
      await tester.tap(find.text('やめる'));
      await frames(tester);
      expect(repository.calls, isEmpty);
      await tester.tap(find.byKey(const ValueKey('buy-rabbit')));
      await frames(tester);
      await tester.tap(find.byKey(const ValueKey('confirm-purchase')));
      await frames(tester);
      expect(repository.calls, hasLength(1));
      expect(find.byKey(const ValueKey('retry-purchase')), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets(
    'closing and reopening shop preserves unresolved request and retry id',
    (tester) async {
      final repository = _Repository();
      final session = GameSession(repository);
      final purchases = ShopPurchaseController(session);
      addTearDown(() {
        purchases.dispose();
        session.dispose();
      });
      Widget panel() => MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: ShopPanel(session: session, purchases: purchases),
          ),
        ),
      );
      await tester.pumpWidget(panel());
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('buy-rabbit')));
      await frames(tester);
      await tester.tap(find.byKey(const ValueKey('confirm-purchase')));
      await frames(tester);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpWidget(panel());
      await tester.pump();
      expect(find.byKey(const ValueKey('retry-purchase')), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('retry-purchase')));
      await frames(tester);
      expect(repository.calls, hasLength(2));
      expect(repository.calls.first.requestId, repository.calls.last.requestId);
      expect(find.text('ウサギを購入しました'), findsOneWidget);
      expect(find.text('確定データの反映を待っています。'), findsOneWidget);
      expect(
        tester.widget<Text>(find.byKey(const ValueKey('shop-balance'))).data,
        '100 コイン',
      );
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets(
    'result recovery becomes visible after buying a lower catalog item',
    (tester) async {
      final repository = _Repository()
        ..catalogItems = List.generate(
          8,
          (i) => ShopItem(
            id: 'item$i',
            name: '動物$i',
            kind: ShopItemKind.animal,
            targetId: 'item$i',
            price: 100,
          ),
        );
      final session = GameSession(repository);
      addTearDown(session.dispose);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(child: ShopPanel(session: session)),
          ),
        ),
      );
      await tester.pump();
      await tester.ensureVisible(find.byKey(const ValueKey('buy-item7')));
      await tester.tap(find.byKey(const ValueKey('buy-item7')));
      await frames(tester);
      await tester.tap(find.byKey(const ValueKey('confirm-purchase')));
      await frames(tester);
      expect(
        find.byKey(const ValueKey('retry-purchase')).hitTestable(),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets('catalog errors have a working reload action', (tester) async {
    final repository = _Repository()..failCatalog = true;
    final session = GameSession(repository);
    addTearDown(session.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: ShopPanel(session: session)),
      ),
    );
    await tester.pump();
    expect(find.text('商品を読み込めませんでした'), findsOneWidget);
    await tester.tap(find.text('再読み込み'));
    await tester.pump();
    expect(find.byKey(const ValueKey('buy-rabbit')), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('confirmation fits a compact phone with large text', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final session = GameSession(_Repository());
    addTearDown(session.dispose);
    await tester.pumpWidget(
      MediaQuery(
        data: MediaQueryData.fromView(tester.view)
            .copyWith(textScaler: TextScaler.linear(2)),
        child: MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(child: ShopPanel(session: session)),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.ensureVisible(find.byKey(const ValueKey('buy-rabbit')));
    await tester.tap(find.byKey(const ValueKey('buy-rabbit')));
    await frames(tester);
    expect(
      find.byKey(const ValueKey('confirm-purchase')).hitTestable(),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
    await tester.tap(find.text('やめる'));
    await frames(tester);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}

class _Repository implements GameRepository, ShopRepository {
  final calls = <PurchaseRequest>[];
  bool failCatalog = false;
  List<ShopItem>? catalogItems;
  @override
  GameConnection get connection => GameConnection.demo;
  @override
  Stream<GameSnapshot> watchGameState() =>
      Stream.value(MockGameRepository.snapshotFor(DemoScenario.approved));
  @override
  Future<ShopCatalog> loadCatalog() async {
    if (failCatalog) {
      failCatalog = false;
      throw StateError('offline');
    }
    return ShopCatalog(
      catalogItems ??
          [
            ShopItem(
              id: 'rabbit',
              name: 'ウサギ',
              kind: ShopItemKind.animal,
              targetId: 'rabbit',
              price: 100,
            ),
          ],
    );
  }

  @override
  Future<PurchaseReceipt> purchase(PurchaseRequest request) async {
    calls.add(request);
    if (calls.length == 1) throw StateError('lost response');
    return PurchaseReceipt(
      requestId: request.requestId,
      itemId: request.itemId,
      price: 100,
      revision: 5,
    );
  }
}
