import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zoo_study/features/zoo/presentation/zoo_map.dart';
import 'package:zoo_study/main.dart';

void main() {
  testWidgets('loads bundled zoo, renders animals and placeholder controls', (
    tester,
  ) async {
    // Warm the real asset cache outside the fake frame clock.
    await tester.runAsync(() async {
      await rootBundle.loadString('assets/zoo/world.json');
      await tester.pumpWidget(const ZooStudyApp());
    });
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('ZooっとStudy'), findsOneWidget);
    expect(find.byType(ZooMap), findsOneWidget);
    expect(find.text('1,000 コイン（仮）'), findsOneWidget);
    expect(find.byKey(const ValueKey('rabbit-1')), findsOneWidget);
    expect(find.byKey(const ValueKey('fox-1')), findsOneWidget);
    expect(find.byKey(const ValueKey('panda-1')), findsOneWidget);
    await tester.pump(const Duration(seconds: 3));
    expect(tester.takeException(), isNull);

    await tester.tap(find.text('ショップ'));
    await tester.pump();
    expect(find.text('ショップは準備中です'), findsOneWidget);
    await tester.tap(find.text('動物一覧'));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('動物一覧は準備中です'), findsOneWidget);

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await tester.pump(const Duration(seconds: 10));
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('map and controls fit a compact Android viewport', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.runAsync(() async {
      await rootBundle.loadString('assets/zoo/world.json');
      await tester.pumpWidget(const ZooStudyApp());
    });
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.byType(ZooMap), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
