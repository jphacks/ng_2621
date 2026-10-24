import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zoo_study/core/ui/zoo_ui.dart';
import 'package:zoo_study/features/zoo/presentation/zoo_map.dart';
import 'package:zoo_study/main.dart';
import 'package:zoo_study/features/game/data/mock_game_repository.dart';

Future<void> loadZoo(WidgetTester tester, {double textScale = 1}) async {
  final repository = MockGameRepository(scenario: DemoScenario.approved);
  addTearDown(repository.dispose);
  await tester.runAsync(() async {
    await rootBundle.loadString('assets/zoo/world.json');
    await repository.loadCatalog();
    await tester.pumpWidget(
      MediaQuery(
        data: MediaQueryData.fromView(tester.view)
            .copyWith(textScaler: TextScaler.linear(textScale)),
        child: ZooStudyApp(gameRepository: repository),
      ),
    );
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
  await tester.pump(const Duration(milliseconds: 100));
}

Future<void> closeSheet(WidgetTester tester) async {
  await tester.tap(find.byTooltip('閉じる'));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
}

void main() {
  testWidgets(
    'sketch layout keeps status above zoo and three actions below it',
    (tester) async {
      await loadZoo(tester);
      expect(find.text('ZooっとStudy'), findsOneWidget);
      expect(find.text('ゲスト'), findsOneWidget);
      expect(find.text('Lv.1'), findsOneWidget);
      expect(find.text('100'), findsOneWidget);
      expect(find.byType(ZooMap), findsOneWidget);
      for (final id in ['rabbit-1', 'fox-1', 'panda-1']) {
        expect(find.byKey(ValueKey(id)), findsNothing);
      }
      final viewport = tester.getRect(find.byType(InteractiveViewer));
      expect(tester.getBottomLeft(find.text('ゲスト')).dy, lessThan(viewport.top));
      for (final label in ['ホーム', '課題', 'その他']) {
        expect(
          tester.getTopLeft(find.text(label)).dy,
          greaterThan(viewport.bottom),
        );
      }
      expect(find.text('ショップ'), findsNothing);
      await tester.pump(const Duration(seconds: 3));
      expect(tester.takeException(), isNull);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      await tester.pump(const Duration(seconds: 10));
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump();
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets('profile wallet study and more open dismissible detail sheets', (
    tester,
  ) async {
    await loadZoo(tester);
    await tester.tap(find.byTooltip('プロフィール'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('プロフィール'), findsOneWidget);
    expect(find.text('レベル 1'), findsOneWidget);
    await closeSheet(tester);

    await tester.tap(find.byTooltip('所持金の詳細'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('100 コイン'), findsOneWidget);
    await closeSheet(tester);

    await tester.tap(find.text('課題'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('数学プリント No.3'), findsOneWidget);
    expect(find.text('承認済み'), findsOneWidget);
    await closeSheet(tester);

    await tester.tap(find.text('その他'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await tester.tap(find.text('ショップ'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.byKey(const ValueKey('buy-rabbit')), findsOneWidget);
    await closeSheet(tester);
    await tester.tap(find.byTooltip('動物一覧'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('まだ動物はいません。ショップから仲間を迎えましょう。'), findsOneWidget);
    await closeSheet(tester);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('map zoom is bounded, dragging works and home resets view', (
    tester,
  ) async {
    await loadZoo(tester);
    final camera = tester
        .widget<InteractiveViewer>(find.byType(InteractiveViewer))
        .transformationController!;
    for (var i = 0; i < 4; i++) {
      await tester.tap(find.byTooltip('拡大'));
      await tester.pump();
    }
    expect(camera.value.getMaxScaleOnAxis(), 4);
    await tester.drag(find.byType(InteractiveViewer), const Offset(30, 30));
    await tester.pump(const Duration(milliseconds: 100));
    expect(camera.value.getTranslation().length, greaterThan(0));
    await tester.tap(find.text('ホーム'));
    await tester.pump();
    expect(camera.value, Matrix4.identity());
    await tester.tap(find.byTooltip('拡大'));
    await tester.pump();
    await tester.tap(find.byTooltip('全体を表示'));
    await tester.pump();
    expect(camera.value, Matrix4.identity());
    await tester.tap(find.byTooltip('縮小'));
    await tester.pump();
    expect(camera.value.getMaxScaleOnAxis(), 1);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  for (final size in [const Size(320, 568), const Size(568, 320)]) {
    testWidgets('layout fits $size without overflow', (tester) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await loadZoo(tester);
      expect(find.byType(ZooMap), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }

  testWidgets(
    'large text on a compact phone keeps navigation and sheets usable',
    (tester) async {
      tester.view.physicalSize = const Size(320, 568);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await loadZoo(tester, textScale: 2);
      expect(
        MediaQuery.textScalerOf(tester.element(find.byType(ZooMap))).scale(10),
        20,
      );
      expect(tester.takeException(), isNull);
      await tester.tap(find.text('その他'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.text('ショップ').hitTestable(), findsOneWidget);
      expect(tester.takeException(), isNull);
      await closeSheet(tester);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
}
