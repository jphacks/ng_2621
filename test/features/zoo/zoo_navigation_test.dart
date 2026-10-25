import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zoo_study/core/ui/zoo_ui.dart';
import 'package:zoo_study/features/zoo/presentation/zoo_screen.dart';
import 'package:zoo_study/features/zoo/presentation/zoo_chrome.dart';

import '../../widget_test.dart' show loadZoo;
import '../../support/shop_actions.dart' show openShopItem;

Future<void> frames(WidgetTester tester) async {
  await tester.runAsync(() => Future<void>.delayed(Duration.zero));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
  await tester.pump(const Duration(milliseconds: 400));
}

void expectNavigation(WidgetTester tester, ZooMainTab selected) {
  expect(
    tester.widget<ZooBottomBar>(find.byType(ZooBottomBar)).selectedTab,
    selected,
  );
  if (selected == ZooMainTab.home) {
    expect(find.byType(ZooHeader).hitTestable(), findsOneWidget);
  }
  for (final tab in ['home', 'study', 'more']) {
    expect(find.byKey(ValueKey('main-tab-$tab')).hitTestable(), findsOneWidget);
  }
}

void main() {
  testWidgets(
    'keyboard resizes the shell once and keeps search plus bottom navigation usable',
    (tester) async {
      tester.view.physicalSize = const Size(320, 568);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetViewInsets);
      await loadZoo(tester);
      await tester.tap(find.byKey(const ValueKey('home-section-1')));
      await frames(tester);
      await tester.tap(find.byKey(const ValueKey('shop-search')));
      tester.view.viewInsets = const FakeViewPadding(bottom: 280);
      await frames(tester);
      await tester.enterText(find.byKey(const ValueKey('shop-search')), 'キツネ');
      await frames(tester);
      expectNavigation(tester, ZooMainTab.home);
      expect(
        tester.getSize(find.byKey(const ValueKey('shop-search'))).height,
        greaterThan(40),
      );
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets(
    'shop detail and learning share bottom navigation; shop query survives switching',
    (tester) async {
      await loadZoo(tester);
      await tester.tap(find.byKey(const ValueKey('home-section-1')));
      await frames(tester);
      expectNavigation(tester, ZooMainTab.home);
      await tester.enterText(find.byKey(const ValueKey('shop-search')), 'キツネ');
      tester.testTextInput.hide();
      await frames(tester);
      await openShopItem(tester, 'fox');
      expectNavigation(tester, ZooMainTab.home);
      await tester.tap(find.byKey(const ValueKey('main-tab-study')));
      await frames(tester);
      expect(find.text('学習メニュー'), findsOneWidget);
      expectNavigation(tester, ZooMainTab.study);
      await tester.tap(find.text('学習記録'));
      await frames(tester);
      expect(find.text('学習記録はまだありません'), findsOneWidget);
      expectNavigation(tester, ZooMainTab.study);
      await tester.tap(find.byKey(const ValueKey('main-tab-home')));
      await frames(tester);
      await tester.tap(find.byKey(const ValueKey('home-section-1')));
      await frames(tester);
      expect(
        tester
            .widget<TextField>(find.byKey(const ValueKey('shop-search')))
            .controller!
            .text,
        'キツネ',
      );
      expect(find.text('1件'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
  testWidgets(
    'construction is a direct home destination; extra filters open on demand',
    (tester) async {
      await loadZoo(tester);
      await tester.tap(find.byKey(const ValueKey('home-section-2')));
      await frames(tester);
      expect(find.text('囲いの購入・拡張').hitTestable(), findsOneWidget);
      expect(find.byType(ZooHeader).hitTestable(), findsOneWidget);
      final menus = tester.widgetList<SpriteTile>(find.byType(SpriteTile));
      expect(menus, isNotEmpty);
      expect(
        menus.every((tile) => tile.panelStyle == SpritePanelStyle.cream),
        isTrue,
      );
      expect(find.text('施設を購入').hitTestable(), findsOneWidget);
      await tester.tap(find.text('施設を購入'));
      await frames(tester);
      expect(find.byKey(const ValueKey('shop-item-pond')), findsOneWidget);
      expect(find.byKey(const ValueKey('shop-purchasable')), findsNothing);
      await tester.tap(find.byKey(const ValueKey('shop-open-filters')));
      await frames(tester);
      expect(find.byKey(const ValueKey('shop-purchasable')), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('shop-hide-owned')));
      await tester.tap(find.text('一覧に戻る'));
      await frames(tester);
      expect(find.text('絞り込み（1）'), findsOneWidget);
      expectNavigation(tester, ZooMainTab.home);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
  testWidgets(
    'tab changes respect a central route PopScope and never force-dismiss saving',
    (tester) async {
      await loadZoo(tester);
      final navigator = tester.state<NavigatorState>(
        find.descendant(
          of: find.byType(ZooScreen),
          matching: find.byType(Navigator),
        ),
      );
      var blocked = 0;
      navigator.push(
        MaterialPageRoute<void>(
          builder: (_) => PopScope(
            canPop: false,
            onPopInvokedWithResult: (didPop, _) {
              if (!didPop) blocked++;
            },
            child: const Scaffold(body: Text('保存中の画面')),
          ),
        ),
      );
      await frames(tester);
      await tester.tap(find.byKey(const ValueKey('main-tab-home')));
      await frames(tester);
      expect(blocked, 1);
      expect(find.text('保存中の画面'), findsOneWidget);
      expectNavigation(tester, ZooMainTab.home);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
}
