import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zoo_study/core/ui/zoo_ui.dart';
import 'package:zoo_study/features/game/data/mock_game_repository.dart';
import 'package:zoo_study/features/shop/domain/shop_catalog.dart';
import 'package:zoo_study/features/shop/domain/shop_repository.dart';
import 'package:zoo_study/features/zoo/domain/zoo_world.dart';
import 'package:zoo_study/features/zoo/presentation/zoo_screen.dart';

import '../../support/shop_actions.dart';

Future<void> frames(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
  await tester.pump(const Duration(milliseconds: 300));
}

Future<void> tapVisible(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.pump();
  await tester.tap(finder);
  await frames(tester);
}

void main() {
  testWidgets(
    'buy enclosure through shop, assign an animal and expand at incremental cost',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final repository = MockGameRepository(
        bonusCoins: 1000,
        worldLoader: () async => ZooWorld.fromJson(
          jsonDecode(File('assets/zoo/world.json').readAsStringSync())
              as Map<String, dynamic>,
        ),
        catalogLoader: () async => ShopCatalog.fromJson(
          jsonDecode(File('assets/zoo/shop_catalog.json').readAsStringSync())
              as Map<String, dynamic>,
        ),
      );
      addTearDown(repository.dispose);
      await tester.runAsync(() async {
        await repository.purchase(
          const PurchaseRequest(requestId: 'rabbit', itemId: 'rabbit'),
        );
        await rootBundle.loadString('assets/zoo/world.json');
        await tester.pumpWidget(
          MaterialApp(home: ZooScreen(gameRepository: repository)),
        );
        for (final path in [
          TerrainSprite.assetPath,
          ZooUiSprite.assetPath,
          ZooExtraSprite.assetPath,
        ]) {
          await precacheImage(
            AssetImage(path),
            tester.element(find.byType(ZooScreen)),
          );
        }
      });
      await frames(tester);
      expect(find.byKey(const ValueKey('rabbit-1')), findsNothing);
      await tapVisible(tester, find.text('その他'));
      await tapVisible(tester, find.text('ショップ'));
      await tapVisible(tester, find.byKey(const ValueKey('shop-filter-施設')));
      await openShopItem(tester, 'enclosure');
      await tapVisible(tester, find.byKey(const ValueKey('buy-enclosure')));
      await tapVisible(tester, find.byKey(const ValueKey('buy-enclosure')));
      await tapVisible(
        tester,
        find.byKey(const ValueKey('confirm-enclosure-charge')),
      );
      expect(repository.currentSnapshot.coins, 820);
      final id = repository.currentSnapshot.layout.enclosures.keys.single;
      await tapVisible(tester, find.byTooltip('閉じる'));
      await tapVisible(tester, find.byTooltip('動物一覧'));
      await tapVisible(tester, find.text('うさぎ'));
      await tapVisible(tester, find.text('囲いに配置する'));
      await tapVisible(tester, find.byKey(ValueKey('assign-$id')));
      expect(find.byKey(const ValueKey('rabbit-1')), findsOneWidget);
      expect(repository.currentSnapshot.layout.animalEnclosures['rabbit'], id);
      await tapVisible(tester, find.text('その他'));
      await tapVisible(tester, find.text('囲いの購入・拡張'));
      await tapVisible(tester, find.text('囲い 1'));
      await tapVisible(tester, find.byTooltip('幅を増やす'));
      expect(find.textContaining('追加料金 20 コイン'), findsOneWidget);
      await tapVisible(tester, find.byKey(const ValueKey('buy-enclosure')));
      await tapVisible(
        tester,
        find.byKey(const ValueKey('confirm-enclosure-charge')),
      );
      expect(repository.currentSnapshot.coins, 800);
      expect(repository.currentSnapshot.layout.enclosures[id]!.width, 5);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
}
