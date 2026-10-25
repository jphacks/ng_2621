import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:zoo_study/core/ui/zoo_ui.dart';
import 'package:zoo_study/features/shop/presentation/shop_item_card.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zoo_study/features/game/data/mock_game_repository.dart';
import 'package:zoo_study/features/game/domain/game_snapshot.dart';
import 'package:zoo_study/features/game/presentation/game_session.dart';
import 'package:zoo_study/features/shop/data/shop_catalog_loader.dart';
import 'package:zoo_study/features/shop/domain/shop_catalog.dart';
import 'package:zoo_study/features/shop/presentation/shop_catalog_filter.dart';
import 'package:zoo_study/features/shop/presentation/shop_screen.dart';

import '../../support/shop_actions.dart';

void main() {
  test(
    'catalog filters combine names, kind, ownership, funds and unlocks',
    () async {
      final catalog = await loadShopCatalog();
      final json = MockGameRepository.snapshotFor(DemoScenario.approved)
          .toJson();
      json['coins'] = 300;
      json['ownedAnimalIds'] = ['rabbit'];
      final state = GameSnapshot.fromJson(json);
      List<String> ids(ShopCatalogFilter filter, {bool connected = true}) =>
          filter
              .apply(catalog, state, connected: connected)
              .map((item) => item.id)
              .toList();
      expect(
        ids(const ShopCatalogFilter(kind: ShopItemKind.animal, query: ' キツネ ')),
        ['fox', 'evolved_fox'],
      );
      expect(
        ids(
          const ShopCatalogFilter(
            kind: ShopItemKind.animal,
            purchasableOnly: true,
          ),
        ),
        ['fox'],
      );
      expect(
        ids(
          const ShopCatalogFilter(kind: ShopItemKind.animal, hideOwned: true),
        ),
        ['fox', 'deer', 'evolved_fox'],
      );
      expect(
        ids(
          const ShopCatalogFilter(
            kind: ShopItemKind.facility,
            purchasableOnly: true,
          ),
        ),
        ['pond', 'enclosure', 'bench', 'topiary', 'fountain', 'flowerArch'],
      );
      expect(
        ids(
          const ShopCatalogFilter(
            kind: ShopItemKind.animal,
            purchasableOnly: true,
          ),
          connected: false,
        ),
        isEmpty,
      );
      expect(state.toJson(), json);
    },
  );

  testWidgets(
    'search and category state survive product detail; empty search can reset',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final repository = MockGameRepository(bonusCoins: 1000);
      final session = GameSession(repository);
      addTearDown(() {
        session.dispose();
        repository.dispose();
      });
      await tester.runAsync(() async {
        await repository.loadCatalog();
      });
      await tester.pumpWidget(MaterialApp(home: ShopScreen(session: session)));
      await tester.pump();
      expect(find.byKey(const ValueKey('shop-filter-すべて')), findsNothing);
      final card = find.byType(ShopItemCard).first;
      final frame = tester.widget<SpritePanel>(
        find.descendant(of: card, matching: find.byType(SpritePanel)),
      );
      expect(frame.style, SpritePanelStyle.cream);
      expect(
        find.descendant(of: card, matching: find.byType(ColorActionPanel)),
        findsNothing,
      );
      await tester.enterText(find.byKey(const ValueKey('shop-search')), 'キツネ');
      await tester.pump();
      tester.testTextInput.hide();
      expect(find.text('2件'), findsOneWidget);
      await openShopItem(tester, 'fox');
      expect(find.text('解放条件'), findsOneWidget);
      await tester.tap(find.byTooltip('商品一覧へ戻る'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pumpAndSettle();
      expect(find.text('2件'), findsOneWidget);
      expect(
        tester
            .widget<TextField>(find.byKey(const ValueKey('shop-search')))
            .controller!
            .text,
        'キツネ',
      );
      await tester.tap(find.byKey(const ValueKey('shop-filter-施設')));
      await tester.pump();
      expect(find.text('条件に合う商品はありません'), findsOneWidget);
      await tester.tap(find.text('検索・絞り込みをリセット'));
      await tester.pump();
      expect(find.text('8件'), findsOneWidget);
      expect(find.byKey(const ValueKey('shop-item-pond')), findsOneWidget);
      expect(find.byKey(const ValueKey('shop-item-fox')), findsNothing);
      expect(repository.currentSnapshot.coins, 1000);
      expect(repository.currentSnapshot.ownedAnimalIds, isEmpty);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
  testWidgets(
    'large catalog stays lazy and search locates a late item directly',
    (tester) async {
      final catalog = ShopCatalog(
        List.generate(
          120,
          (i) => ShopItem(
            id: 'animal$i',
            name: '動物$i',
            kind: ShopItemKind.animal,
            targetId: 'animal$i',
            price: 100,
          ),
        ),
      );
      final repository = MockGameRepository(catalogLoader: () async => catalog);
      final session = GameSession(repository);
      addTearDown(() {
        session.dispose();
        repository.dispose();
      });
      await tester.pumpWidget(MaterialApp(home: ShopScreen(session: session)));
      await tester.pump();
      expect(find.byType(ShopItemCard).evaluate().length, lessThan(30));
      expect(find.text('120件'), findsOneWidget);
      await tester.enterText(
        find.byKey(const ValueKey('shop-search')),
        '動物119',
      );
      await tester.pump();
      expect(find.text('1件'), findsOneWidget);
      expect(find.byKey(const ValueKey('shop-item-animal119')), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets('bundled pixel font fits a compact shop with 2x text', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final loader = FontLoader('DotGothic16')
      ..addFont(rootBundle.load('assets/fonts/DotGothic16-Regular.ttf'));
    await tester.runAsync(loader.load);
    final repository = MockGameRepository(bonusCoins: 1000);
    final session = GameSession(repository);
    addTearDown(() {
      session.dispose();
      repository.dispose();
    });
    await tester.runAsync(() async {
      await repository.loadCatalog();
    });
    await tester.pumpWidget(
      MediaQuery(
        data: MediaQueryData.fromView(tester.view)
            .copyWith(textScaler: TextScaler.linear(2)),
        child: MaterialApp(home: ShopScreen(session: session)),
      ),
    );
    await tester.pump();
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('shop-item-rabbit')),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pump();
    final grid = tester.widget<SliverGrid>(find.byType(SliverGrid));
    expect(
      (grid.gridDelegate as SliverGridDelegateWithFixedCrossAxisCount)
          .crossAxisCount,
      1,
    );
    await openShopItem(tester, 'rabbit');
    await tester.ensureVisible(find.byKey(const ValueKey('buy-rabbit')));
    await tester.pump();
    expect(
      find.byKey(const ValueKey('buy-rabbit')).hitTestable(),
      findsOneWidget,
    );
    expect(
      Theme.of(tester.element(find.byKey(const ValueKey('buy-rabbit'))))
          .textTheme
          .bodyMedium!
          .fontFamily,
      'DotGothic16',
    );
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
