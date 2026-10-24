import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zoo_study/features/game/data/mock_game_repository.dart';
import 'package:zoo_study/features/game/domain/game_repository.dart';
import 'package:zoo_study/features/game/presentation/game_session.dart';
import 'package:zoo_study/features/game/presentation/game_status.dart';

void main() {
  testWidgets(
    'assignment sheet updates from external mock without submit controls',
    (tester) async {
      final repository = MockGameRepository();
      final session = GameSession(repository);
      addTearDown(() async {
        session.dispose();
        await repository.dispose();
      });
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: GameStatus(session: session)),
        ),
      );
      await tester.pump();
      expect(find.text('未提出'), findsOneWidget);
      expect(find.text('提出で+30 / 承認で+70'), findsOneWidget);
      expect(find.byType(TextField), findsNothing);
      repository.receiveConfirmedSnapshot(
        MockGameRepository.snapshotFor(DemoScenario.submitted),
      );
      await tester.pump();
      expect(find.text('確認待ち'), findsOneWidget);
      expect(find.text('先生の確認でさらに +70コイン'), findsOneWidget);
      expect(find.textContaining('課題クリア'), findsNothing);
      repository.receiveConfirmedSnapshot(
        MockGameRepository.snapshotFor(DemoScenario.needsRevision),
      );
      await tester.pump();
      expect(find.text('再提出待ち'), findsOneWidget);
      expect(find.text('先生から：途中の計算も書いてみよう。'), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets('wallet shows confirmed receipt reasons and marks mock data', (
    tester,
  ) async {
    final repository = MockGameRepository(scenario: DemoScenario.approved);
    final session = GameSession(repository);
    addTearDown(() async {
      session.dispose();
      await repository.dispose();
    });
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: GameStatus(session: session, walletOnly: true)),
      ),
    );
    await tester.pump();
    expect(find.text('100 コイン'), findsOneWidget);
    expect(find.text('提出で+30'), findsOneWidget);
    expect(find.text('承認で+70'), findsOneWidget);
    expect(find.textContaining('デモデータ'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('offline sheet states that integration is unavailable', (
    tester,
  ) async {
    final session = GameSession(const DisconnectedGameRepository());
    addTearDown(session.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: GameStatus(session: session)),
      ),
    );
    await tester.pump();
    expect(find.textContaining('未接続'), findsOneWidget);
    expect(find.textContaining('コイン獲得済み'), findsNothing);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
