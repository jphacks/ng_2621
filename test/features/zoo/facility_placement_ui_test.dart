import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zoo_study/core/ui/zoo_ui.dart';
import 'package:zoo_study/features/zoo/domain/facility_placement.dart';
import 'package:zoo_study/features/zoo/presentation/facility_placement_screen.dart';
import 'package:zoo_study/features/zoo/presentation/zoo_controller.dart';

import 'facility_placement_test.dart' show placementWorld;

Future<void> frames(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
  await tester.pump(const Duration(milliseconds: 300));
}

Future<ZooController> openEditor(
  WidgetTester tester, {
  required Future<void> Function(FacilityPlacement) save,
}) async {
  final world = placementWorld();
  final controller = ZooController(
    world,
    ownedAnimalIds: {},
    ownedFacilityIds: {'pond', 'forest'},
  );
  addTearDown(controller.dispose);
  await tester.pumpWidget(
    MaterialApp(
      home: Builder(
        builder: (context) => Scaffold(
          body: TextButton(
            onPressed: () => Navigator.push<void>(
              context,
              MaterialPageRoute(
                builder: (_) => FacilityPlacementScreen(
                  controller: controller,
                  definition: world.facilities.first,
                  name: '池',
                  onSave: (position) async {
                    await save(position);
                    if (!controller.placeFacility(position)) {
                      throw StateError('invalid');
                    }
                  },
                ),
              ),
            ),
            child: const Text('配置開始'),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('配置開始'));
  await frames(tester);
  await tester.runAsync(() async {
    for (final path in [
      ZooUiSprite.assetPath,
      TerrainSprite.assetPath,
      ZooExtraSprite.assetPath,
    ]) {
      await precacheImage(
        AssetImage(path),
        tester.element(find.byType(FacilityPlacementScreen)),
      );
    }
  });
  await tester.pump();
  return controller;
}

void main() {
  testWidgets('tap selects a tile and cancel leaves layout untouched', (
    tester,
  ) async {
    final saves = <FacilityPlacement>[];
    final controller = await openEditor(
      tester,
      save: (p) async => saves.add(p),
    );
    final terrain = tester.renderObject<RenderBox>(
      find.byKey(const ValueKey('zoo-terrain')),
    );
    await tester.tapAt(terrain.localToGlobal(const Offset(5 * 16 + 8, 16 + 8)));
    await tester.pump();
    expect(find.text('位置：列 6 ／ 行 2'), findsOneWidget);
    final center = terrain.localToGlobal(const Offset(80, 80));
    final first = await tester.startGesture(
      center - const Offset(30, 0),
      pointer: 1,
    );
    final second = await tester.startGesture(
      center + const Offset(30, 0),
      pointer: 2,
    );
    await first.moveTo(center - const Offset(65, 0));
    await second.moveTo(center + const Offset(65, 0));
    await tester.pump();
    await first.up();
    await second.up();
    await tester.pump();
    await tester.tapAt(
      terrain.localToGlobal(const Offset(5 * 16 + 8, 2 * 16 + 8)),
    );
    await tester.pump();
    expect(find.text('位置：列 6 ／ 行 3'), findsOneWidget);

    expect(controller.positionOf(controller.world.facilities.first).left, 1);
    await tester.ensureVisible(find.text('キャンセル'));
    await tester.pump();
    await tester.tap(find.text('キャンセル'));
    await frames(tester);
    expect(saves, isEmpty);
    expect(controller.placements, isEmpty);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets(
    'invalid area disables confirm; failed save preserves draft for retry',
    (tester) async {
      var attempts = 0;
      final controller = await openEditor(
        tester,
        save: (_) async {
          if (++attempts == 1) throw StateError('offline');
        },
      );
      await tester.tap(find.byTooltip('下へ1マス'));
      await tester.pump();
      await tester.tap(find.byTooltip('下へ1マス'));
      await tester.pump();
      expect(
        tester
            .widget<FilledButton>(
              find.byKey(const ValueKey('confirm-placement')),
            )
            .onPressed,
        isNull,
      );
      await tester.tap(find.byTooltip('上へ1マス'));
      await tester.pump();
      await tester.ensureVisible(
        find.byKey(const ValueKey('confirm-placement')),
      );
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('confirm-placement')));
      await tester.pump();
      expect(find.text('配置を保存できませんでした。もう一度お試しください。'), findsOneWidget);
      expect(controller.placements, isEmpty);
      await tester.ensureVisible(
        find.byKey(const ValueKey('confirm-placement')),
      );
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('confirm-placement')));
      await frames(tester);
      expect(attempts, 2);
      expect(controller.positionOf(controller.world.facilities.first).top, 2);
      expect(find.byType(FacilityPlacementScreen), findsNothing);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets('pending save blocks duplicate submission and back navigation', (
    tester,
  ) async {
    final pending = Completer<void>();
    var calls = 0;
    final controller = await openEditor(
      tester,
      save: (_) async {
        calls++;
        await pending.future;
      },
    );
    await tester.ensureVisible(find.byKey(const ValueKey('confirm-placement')));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('confirm-placement')));
    await tester.pump();
    expect(calls, 1);
    expect(controller.placements, isEmpty);
    expect(
      tester
          .widget<FilledButton>(find.byKey(const ValueKey('confirm-placement')))
          .onPressed,
      isNull,
    );
    await tester.binding.handlePopRoute();
    await tester.pump();
    expect(find.byType(FacilityPlacementScreen), findsOneWidget);
    pending.complete();
    await frames(tester);
    expect(calls, 1);
    expect(controller.placements.containsKey('pond'), isTrue);
    expect(find.byType(FacilityPlacementScreen), findsNothing);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  for (final size in [const Size(320, 568), const Size(568, 320)]) {
    testWidgets('editor fits $size with 2x text', (tester) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final world = placementWorld();
      final controller = ZooController(world, ownedFacilityIds: {'pond'});
      addTearDown(controller.dispose);
      await tester.pumpWidget(
        MediaQuery(
          data: MediaQueryData.fromView(tester.view)
              .copyWith(textScaler: TextScaler.linear(2)),
          child: MaterialApp(
            home: FacilityPlacementScreen(
              controller: controller,
              definition: world.facilities.first,
              name: '池',
              onSave: (_) async {},
            ),
          ),
        ),
      );
      await tester.ensureVisible(
        find.byKey(const ValueKey('confirm-placement')),
      );
      await tester.pump();
      expect(
        find.byKey(const ValueKey('confirm-placement')).hitTestable(),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }
}
