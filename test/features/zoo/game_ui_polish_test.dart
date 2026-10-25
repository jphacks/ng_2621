import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zoo_study/core/ui/zoo_ui.dart';
import 'package:zoo_study/features/game/data/mock_game_repository.dart';
import 'package:zoo_study/features/game/domain/game_snapshot.dart';
import 'package:zoo_study/features/shop/domain/shop_catalog.dart';
import 'package:zoo_study/features/zoo/presentation/zoo_screen.dart';

import '../../support/shop_actions.dart';

Future<MockGameRepository> openGame(WidgetTester tester) async {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  final repository = MockGameRepository(
    catalogLoader: () async => ShopCatalog.fromJson(
      jsonDecode(File('assets/zoo/shop_catalog.json').readAsStringSync())
          as Map<String, dynamic>,
    ),
  );
  addTearDown(repository.dispose);
  await tester.runAsync(() async {
    await rootBundle.loadString('assets/zoo/world.json');
    await repository.loadCatalog();
    await tester.pumpWidget(
      MaterialApp(home: ZooScreen(gameRepository: repository)),
    );
    for (final path in [
      ZooUiSprite.assetPath,
      ZooArtSprite.assetPath,
      TerrainSprite.assetPath,
    ]) {
      await precacheImage(
        AssetImage(path),
        tester.element(find.byType(ZooScreen)),
      );
    }
  });
  await tester.pump();
  return repository;
}

Future<void> frames(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
}

void main() {
  testWidgets('empty zoo gives a shop route without changing coins', (
    tester,
  ) async {
    final repository = await openGame(tester);
    expect(find.text('最初の仲間を迎えよう'), findsOneWidget);
    await tester.tap(find.text('ショップへ'));
    await frames(tester);
    expect(find.text('ショップ'), findsOneWidget);
    await openShopItem(tester, 'rabbit');
    expect(
      tester
          .widget<FilledButton>(find.byKey(const ValueKey('buy-rabbit')))
          .onPressed,
      isNull,
    );
    expect(repository.currentSnapshot.coins, 0);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets(
    'shop categories filter views without touching inventory or balance',
    (tester) async {
      final repository = await openGame(tester);
      await tester.tap(find.text('ショップへ'));
      await frames(tester);
      final before = repository.currentSnapshot.toJson();
      await tester.tap(find.byKey(const ValueKey('shop-filter-施設')));
      await tester.pump();
      expect(find.byKey(const ValueKey('shop-item-rabbit')), findsNothing);
      expect(find.byKey(const ValueKey('shop-item-pond')), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('shop-filter-動物')));
      await tester.pump();
      expect(find.byKey(const ValueKey('shop-item-rabbit')), findsOneWidget);
      expect(find.byKey(const ValueKey('shop-item-pond')), findsNothing);
      expect(repository.currentSnapshot.toJson(), before);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets('home and shop navigation stay visible when catalog scrolls', (
    tester,
  ) async {
    await openGame(tester);
    await tester.tap(find.text('ショップへ'));
    await frames(tester);
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('shop-item-evolved_fox')),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pump();
    expect(
      find.byKey(const ValueKey('main-tab-home')).hitTestable(),
      findsOneWidget,
    );
    expect(find.text('ショップ').hitTestable(), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('zoom readout and empty guidance follow actual map state', (
    tester,
  ) async {
    final repository = await openGame(tester);
    expect(find.text('1.0×'), findsOneWidget);
    await tester.tap(find.byTooltip('拡大'));
    await tester.pump();
    expect(find.text('2.0×'), findsOneWidget);
    await tester.tap(find.byTooltip('全体を表示'));
    await tester.pump();
    expect(find.text('1.0×'), findsOneWidget);
    final data = repository.currentSnapshot.toJson();
    data['revision'] = 1;
    data['ownedAnimalIds'] = ['rabbit'];
    repository.receiveConfirmedSnapshot(GameSnapshot.fromJson(data));
    await tester.pump();
    expect(find.text('最初の仲間を迎えよう'), findsNothing);
    expect(find.text('0匹'), findsOneWidget);
    expect(find.text('動物を囲いに配置しよう'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  for (final reduce in [false, true]) {
    testWidgets('wood action remains tappable with reduced motion=$reduce', (
      tester,
    ) async {
      var calls = 0;
      await tester.pumpWidget(
        MediaQuery(
          data: MediaQueryData.fromView(tester.view)
              .copyWith(disableAnimations: reduce),
          child: MaterialApp(
            home: Scaffold(
              body: Center(
                child: SizedBox(
                  width: 110,
                  child: WoodButton(
                    onPressed: () => calls++,
                    child: const Text('課題'),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      final gesture = await tester.startGesture(
        tester.getCenter(find.byType(WoodButton)),
      );
      await tester.pump(const Duration(milliseconds: 150));
      final scale = tester.widget<AnimatedScale>(find.byType(AnimatedScale));
      expect(scale.scale, reduce ? 1 : 0.98);
      await gesture.up();
      await tester.pump(const Duration(milliseconds: 150));
      expect(calls, 1);
      expect(
        tester.getSize(find.byType(WoodButton)).height,
        greaterThanOrEqualTo(48),
      );
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }
}
