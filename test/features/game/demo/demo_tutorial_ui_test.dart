import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zoo_study/features/game/demo/demo_tutorial_screen.dart';
import 'package:zoo_study/features/game/demo/demo_tutorial_controller.dart';
import 'package:zoo_study/features/game/demo/presentation_repository.dart';
import 'package:zoo_study/features/zoo/presentation/zoo_screen.dart';

import '../../../support/shop_actions.dart';

Future<void> frames(WidgetTester tester) async {
  await tester.runAsync(() => Future<void>.delayed(Duration.zero));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
  await tester.pump(const Duration(milliseconds: 400));
}

Future<void> tap(WidgetTester tester, String key) async {
  final target = find.byKey(ValueKey(key));
  await tester.ensureVisible(target);
  await tester.pump();
  await tester.tap(target);
  await frames(tester);
}

Future<void> buy(WidgetTester tester, String id) async {
  await openShopItem(tester, id);
  await tap(tester, 'buy-$id');
  await tap(tester, 'confirm-purchase');
}

Future<void> start(WidgetTester tester, Size size) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.runAsync(() async {
    await rootBundle.loadString('assets/zoo/world.json');
    await rootBundle.loadString('assets/zoo/shop_catalog.json');
    await tester.pumpWidget(const PresentationDemoApp());
  });
  await tap(tester, 'demo-start');
  await frames(tester);
}

DemoTutorialController tour(WidgetTester tester) =>
    tester.widget<ZooScreen>(find.byType(ZooScreen)).presentation!;

void main() {
  testWidgets(
    'visitor can finish every real operation and see the grown zoo, then restart',
    (tester) async {
      await start(tester, const Size(390, 844));
      expect(tour(tester).step, DemoStep.assign);
      await tap(tester, 'demo-next');
      expect(tour(tester).step, DemoStep.submit);
      await tap(tester, 'demo-next');
      await tap(tester, 'demo-submit');
      expect(tour(tester).repository.coins, 30);
      await tap(tester, 'demo-next');
      await tap(tester, 'demo-approve');
      expect(tour(tester).repository.coins, 100);
      await tap(tester, 'demo-next');
      await buy(tester, 'rabbit');
      expect(tour(tester).step, DemoStep.placeRabbit);
      await tap(tester, 'demo-next');
      await tap(tester, 'assign-${PresentationRepository.starterPen}');
      expect(tour(tester).step, DemoStep.expand);
      await tap(tester, 'demo-next');
      await tap(tester, 'demo-budget');
      await tap(tester, 'demo-next');
      await buy(tester, 'pond');
      await tap(tester, 'demo-next');
      await tap(tester, 'confirm-placement');
      expect(tour(tester).step, DemoStep.research);
      await tap(tester, 'demo-next');
      await buy(tester, 'fox');
      await tap(tester, 'demo-next');
      await buy(tester, 'laboratory');
      await tap(tester, 'demo-next');
      await tap(tester, 'confirm-placement');
      expect(tour(tester).step, DemoStep.evolve);
      await tap(tester, 'demo-next');
      await tester.ensureVisible(find.text('炎狐'));
      await tester.tap(find.text('炎狐'));
      await frames(tester);
      await tap(tester, 'buy-fire_fox');
      await tap(tester, 'confirm-purchase');
      await tester.tap(find.byTooltip('閉じる').hitTestable().last);
      await frames(tester);
      await tap(tester, 'demo-next');
      await tap(tester, 'assign-${PresentationRepository.starterPen}');
      expect(tour(tester).step, DemoStep.collection);
      await tap(tester, 'demo-next');
      expect(find.text('動物一覧'), findsOneWidget);
      await tester.tap(find.byTooltip('閉じる').hitTestable().last);
      await frames(tester);
      await tap(tester, 'demo-next');
      expect(tour(tester).step, DemoStep.complete);
      expect(tour(tester).repository.snapshot.ownedAnimalIds, hasLength(27));
      expect(find.byKey(const ValueKey('demo-finale')), findsOneWidget);
      await tap(tester, 'demo-finale-restart');
      expect(find.byKey(const ValueKey('demo-start')), findsOneWidget);
      await tap(tester, 'demo-start');
      expect(tour(tester).step, DemoStep.assign);
      expect(tour(tester).repository.coins, 0);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  for (final scale in [1.0, 2.0]) {
    testWidgets('compact phone supports cancellation at text scale $scale', (
      tester,
    ) async {
      tester.platformDispatcher.textScaleFactorTestValue = scale;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      await start(tester, const Size(320, 568));
      expect(
        find.byKey(const ValueKey('demo-next')).hitTestable(),
        findsOneWidget,
      );
      await tap(tester, 'demo-next');
      await tap(tester, 'demo-next');
      await tester.tap(find.text('あとで'));
      await frames(tester);
      expect(tour(tester).step, DemoStep.submit);
      await tap(tester, 'demo-next');
      await tap(tester, 'demo-submit');
      expect(tour(tester).repository.coins, 30);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }
}
