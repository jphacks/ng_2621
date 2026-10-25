import 'package:zoo_study/features/game/domain/zoo_layout.dart';

import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zoo_study/core/ui/zoo_ui.dart';
import 'package:zoo_study/features/game/data/mock_game_repository.dart';
import 'package:zoo_study/features/game/domain/game_repository.dart';
import 'package:zoo_study/features/game/domain/game_snapshot.dart';
import 'package:zoo_study/features/game/presentation/game_session.dart';
import 'package:zoo_study/features/shop/domain/shop_catalog.dart';
import 'package:zoo_study/features/shop/domain/shop_repository.dart';
import 'package:zoo_study/features/shop/presentation/shop_screen.dart';

import '../../support/shop_actions.dart';

import 'package:zoo_study/main.dart';

ShopCatalog fixture() => ShopCatalog.fromJson(
  jsonDecode(File('assets/zoo/shop_catalog.json').readAsStringSync())
      as Map<String, dynamic>,
);
Future<void> transition(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 500));
  await tester.pump(const Duration(milliseconds: 300));
}

Future<void> menu(WidgetTester tester, String name) async {
  await tester.tap(find.byKey(const ValueKey('main-tab-home')));
  await transition(tester);
  if (name == 'ショップ') {
    await tester.tap(find.byKey(const ValueKey('home-section-1')));
  } else {
    await tester.tap(find.byKey(const ValueKey('main-tab-more')));
    await transition(tester);
    await tester.tap(find.text(name));
  }
  await transition(tester);
}

void main() {
  testWidgets(
    'confirmed submission then approval buys rabbit and shows it in zoo',
    (tester) async {
      final repository = MockGameRepository(
        catalogLoader: () async => fixture(),
        bonusCoins: 80,
      );
      addTearDown(repository.dispose);
      await tester.runAsync(() async {
        await rootBundle.loadString('assets/zoo/world.json');
        await repository.loadCatalog();
        await repository.purchase(
          const PurchaseRequest(
            requestId: 'fixture_pen',
            itemId: 'zoo_layout',
            layoutEdit: LayoutEdit(
              kind: LayoutEditKind.enclosure,
              id: 'flow_pen',
              left: 0,
              top: 0,
              width: 4,
              height: 4,
            ),
          ),
        );
        await tester.pumpWidget(ZooStudyApp(gameRepository: repository));
        await tester.ensureVisible(find.text('生徒はこちら'));
        await tester.tap(find.text('生徒はこちら'));
        await tester.pump();
        await tester.ensureVisible(find.text('確定'));
        await tester.tap(find.text('確定'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 400));
        await precacheImage(
          const AssetImage(ZooUiSprite.assetPath),
          tester.element(find.byType(ZooStudyApp)),
        );
      });
      await tester.pump();
      expect(find.byKey(const ValueKey('rabbit-1')), findsNothing);
      await menu(tester, '連携デモ');
      await tester.tap(find.text('初回提出の確定結果を受信'));
      await transition(tester);
      await tester.tap(find.byKey(const ValueKey('main-tab-home')));
      await transition(tester);
      expect(find.text('30'), findsOneWidget);
      await tester.tap(find.byTooltip('通知を閉じる'));
      await tester.pump();
      await menu(tester, 'ショップ');
      await openShopItem(tester, 'rabbit');
      expect(
        tester
            .widget<FilledButton>(find.byKey(const ValueKey('buy-rabbit')))
            .onPressed,
        isNull,
      );
      await tester.tap(find.byTooltip('商品一覧へ戻る'));
      await transition(tester);
      await tester.tap(find.byKey(const ValueKey('main-tab-home')));
      await transition(tester);
      await menu(tester, '連携デモ');
      await tester.tap(find.text('承認の確定結果を受信'));
      await transition(tester);
      await tester.tap(find.byKey(const ValueKey('main-tab-home')));
      await transition(tester);
      expect(find.text('100'), findsOneWidget);
      await tester.tap(find.byTooltip('通知を閉じる'));
      await tester.pump();
      await menu(tester, 'ショップ');
      await openShopItem(tester, 'rabbit');
      await tester.tap(find.byKey(const ValueKey('buy-rabbit')));
      await transition(tester);
      await tester.tap(find.byKey(const ValueKey('confirm-purchase')));
      await transition(tester);
      expect(find.text('ウサギを購入しました').hitTestable(), findsOneWidget);
      expect(find.text('仲間が増えました！'), findsOneWidget);
      expect(find.text('0 コイン'), findsOneWidget);
      expect(
        tester
            .widget<FilledButton>(find.byKey(const ValueKey('buy-rabbit')))
            .onPressed,
        isNull,
      );
      await tester.tap(find.text('動物園を見る'));
      await transition(tester);
      expect(find.byKey(const ValueKey('rabbit-1')), findsNothing);
      await tester.tap(find.byTooltip('動物一覧'));
      await transition(tester);
      await tester.tap(find.byKey(const ValueKey('encyclopedia-rabbit')));
      await transition(tester);
      await tester.tap(find.text('囲いに配置する'));
      await transition(tester);
      await tester.tap(find.byKey(const ValueKey('assign-flow_pen')));
      await transition(tester);
      expect(
        repository.currentSnapshot.layout.animalEnclosures,
        containsPair('rabbit', 'flow_pen'),
      );
      expect(find.byKey(const ValueKey('rabbit-1')), findsOneWidget);
      expect(find.byKey(const ValueKey('fox-1')), findsNothing);
      expect(find.text('1匹'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('rabbit-1')));
      await transition(tester);
      expect(find.text('うさぎ'), findsOneWidget);
      expect(find.text('動物園で暮らしています'), findsOneWidget);
      expect(find.text('解放済み'), findsOneWidget);
      await tester.tap(find.byTooltip('閉じる'));
      await transition(tester);
      await tester.pump(const Duration(seconds: 2));
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets('ambiguous failure retries the same purchase request id', (
    tester,
  ) async {
    final repository = _RetryRepository();
    final session = GameSession(repository);
    addTearDown(session.dispose);
    await tester.pumpWidget(MaterialApp(home: ShopScreen(session: session)));
    await tester.pump();
    await openShopItem(tester, 'rabbit');
    await tester.tap(find.byKey(const ValueKey('buy-rabbit')));
    await transition(tester);
    await tester.tap(find.byKey(const ValueKey('confirm-purchase')));
    await transition(tester);
    expect(find.byKey(const ValueKey('retry-purchase')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('retry-purchase')));
    await transition(tester);
    expect(repository.ids, hasLength(2));
    expect(repository.ids.first, repository.ids.last);
    expect(find.text('ウサギを購入しました'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}

class _RetryRepository implements GameRepository, ShopRepository {
  final ids = <String>[];
  @override
  GameConnection get connection => GameConnection.demo;
  @override
  Stream<GameSnapshot> watchGameState() =>
      Stream.value(MockGameRepository.snapshotFor(DemoScenario.approved));
  @override
  Future<ShopCatalog> loadCatalog() async => fixture();
  @override
  Future<PurchaseReceipt> purchase(PurchaseRequest request) async {
    ids.add(request.requestId);
    if (ids.length == 1) throw StateError('lost response');
    return PurchaseReceipt(
      requestId: request.requestId,
      itemId: request.itemId,
      price: 100,
      revision: 5,
    );
  }
}
