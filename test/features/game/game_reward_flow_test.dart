import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zoo_study/core/ui/zoo_ui.dart';
import 'package:zoo_study/features/game/data/mock_game_repository.dart';
import 'package:zoo_study/main.dart';

Future<void> openDemo(WidgetTester tester) async {
  await tester.tap(find.text('その他'));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
  await tester.tap(find.text('連携デモ'));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 500));
}

Future<void> receive(WidgetTester tester, String label) async {
  await tester.tap(find.text(label));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
  await tester.tap(find.byKey(const ValueKey('main-tab-home')));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
  await tester.pump(const Duration(milliseconds: 400));
}

void main() {
  testWidgets('mock confirmed submit then approve produces 30 and 70 once', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final repository = MockGameRepository();
    addTearDown(repository.dispose);
    await tester.runAsync(() async {
      await rootBundle.loadString('assets/zoo/world.json');
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
    expect(find.text('0'), findsOneWidget);
    expect(find.byTooltip('通知を閉じる'), findsNothing);
    await openDemo(tester);
    await receive(tester, '初回提出の確定結果を受信');
    expect(find.text('30'), findsOneWidget);
    expect(find.text('課題を提出！ +30コイン'), findsOneWidget);
    await tester.ensureVisible(find.byTooltip('通知を閉じる'));
    await tester.pump();
    await tester.tap(find.byTooltip('通知を閉じる'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));
    await openDemo(tester);
    await receive(tester, '同じ確定結果を再受信');
    expect(find.byTooltip('通知を閉じる'), findsNothing);
    expect(find.text('30'), findsOneWidget);
    await openDemo(tester);
    await receive(tester, '承認の確定結果を受信');
    expect(find.text('100'), findsOneWidget);
    expect(find.text('先生が確認！ +70コイン'), findsOneWidget);
    await tester.tap(find.text('先生が確認！ +70コイン'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('提出で+30'), findsOneWidget);
    expect(find.text('承認で+70'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('large text with a queued reward fits a compact phone', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final repository = MockGameRepository();
    addTearDown(repository.dispose);
    await tester.runAsync(() async {
      await rootBundle.loadString('assets/zoo/world.json');
      await tester.pumpWidget(
        MediaQuery(
          data: MediaQueryData.fromView(tester.view)
              .copyWith(textScaler: TextScaler.linear(2)),
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
    repository.receiveConfirmedSnapshot(
      MockGameRepository.snapshotFor(DemoScenario.approved),
    );
    await tester.pump();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));
    expect(find.text('ほか1件'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.ensureVisible(find.byTooltip('通知を閉じる'));
    await tester.pump();
    await tester.tap(find.byTooltip('通知を閉じる'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));
    expect(find.text('先生が確認！ +70コイン'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('revision and resubmission keep 30 until confirmed approval', (
    tester,
  ) async {
    final repository = MockGameRepository(scenario: DemoScenario.submitted);
    addTearDown(repository.dispose);
    await tester.runAsync(() async {
      await rootBundle.loadString('assets/zoo/world.json');
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
    await openDemo(tester);
    await receive(tester, '再提出依頼を受信');
    expect(find.text('30'), findsOneWidget);
    expect(find.text('もう一度チャレンジ！ 前回の30コインはそのまま'), findsOneWidget);
    await tester.ensureVisible(find.byTooltip('通知を閉じる'));
    await tester.pump();
    await tester.tap(find.byTooltip('通知を閉じる'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));
    await openDemo(tester);
    await receive(tester, '再提出の確定結果を受信');
    expect(find.text('30'), findsOneWidget);
    expect(find.byTooltip('通知を閉じる'), findsNothing);
    await openDemo(tester);
    await receive(tester, '承認の確定結果を受信');
    expect(find.text('100'), findsOneWidget);
    expect(find.text('先生が確認！ +70コイン'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
