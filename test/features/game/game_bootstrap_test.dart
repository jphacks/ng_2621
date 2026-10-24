import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zoo_study/core/ui/zoo_ui.dart';
import 'package:zoo_study/features/game/data/mock_game_repository.dart';
import 'package:zoo_study/main.dart';
import 'package:zoo_study/features/game/presentation/game_status.dart';

void main() {
  testWidgets('real entry point opts into mock only with explicit demo flag', (
    tester,
  ) async {
    await tester.runAsync(() async {
      await rootBundle.loadString('assets/zoo/world.json');
      await tester.pumpWidget(const ZooStudyApp());
      await precacheImage(
        const AssetImage(ZooUiSprite.assetPath),
        tester.element(find.byType(ZooStudyApp)),
      );
    });
    await tester.pump();
    const demoEnabled = bool.fromEnvironment('ZOOSTUDY_DEMO');
    if (demoEnabled) {
      const name = String.fromEnvironment(
        'ZOOSTUDY_DEMO_SCENARIO',
        defaultValue: 'assigned',
      );
      final snapshot = MockGameRepository.snapshotFor(
        DemoScenario.values.byName(name),
      );
      expect(find.text('コイン・デモ'), findsOneWidget);
      const bonus = int.fromEnvironment(
        'ZOOSTUDY_DEMO_BONUS_COINS',
        defaultValue: 1000,
      );
      final displayed = (snapshot.coins + bonus).toString().replaceAllMapped(
        RegExp(r'(\d)(?=(\d{3})+(?!\d))'),
        (match) => '${match[1]},',
      );
      expect(find.text(displayed), findsOneWidget);
    } else {
      expect(find.text('コイン・未接続'), findsOneWidget);
      expect(find.text('—'), findsOneWidget);
    }
    await tester.tap(find.text('課題'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(
      find.descendant(
        of: find.byType(GameStatus),
        matching: find.textContaining(demoEnabled ? 'デモデータ' : '未接続'),
      ),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
