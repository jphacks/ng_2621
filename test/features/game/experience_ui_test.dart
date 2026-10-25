import 'package:zoo_study/features/study/demo_assignment_store.dart';

import '../study/study_reward_test.dart' show earned;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zoo_study/app.dart';
import 'package:zoo_study/features/game/data/mock_game_repository.dart';
import 'package:zoo_study/features/game/domain/game_snapshot.dart';
import 'package:zoo_study/features/game/experience/experience_widgets.dart';

import '../../widget_test.dart' show loadZoo, closeSheet;

Future<void> frames(WidgetTester tester) async {
  await tester.runAsync(() => Future<void>.delayed(Duration.zero));
  await tester.pump();
  await tester.runAsync(() => Future<void>.delayed(Duration.zero));
  await tester.pump(const Duration(milliseconds: 400));
  await tester.pump(const Duration(milliseconds: 400));
}

void main() {
  testWidgets(
    'phase 3: saved study records feed the game on return without double rewards',
    (tester) async {
      final store = DemoAssignmentStore();
      await tester.runAsync(() async {
        await store.loadCatalog();
        await tester.pumpWidget(
          ZooStudyApp(studyRepository: store, gameRepository: store),
        );
        await tester.tap(find.text('生徒はこちら'));
        await tester.pump();
        await tester.ensureVisible(find.text('確定'));
        await tester.tap(find.text('確定'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 400));
      });
      await frames(tester);
      await tester.tap(find.text('学習'));
      await frames(tester);
      await tester.tap(find.text('学習記録'));
      await frames(tester);
      await tester.runAsync(
        () => store.saveStudyRecord(earned('study_game_bridge', 240)),
      );
      await frames(tester);
      await tester.tap(find.byType(BackButton).hitTestable());
      await frames(tester);
      await tester.tap(find.byKey(const ValueKey('main-tab-home')));
      await frames(tester);
      expect(find.byType(RewardCelebration), findsOneWidget);
      expect(find.text('自習のごほうび +2コイン'), findsOneWidget);
      expect(store.coins, 2);
      await tester.tap(find.widgetWithText(OutlinedButton, '閉じる'));
      await frames(tester);
      await tester.tap(find.text('学習'));
      await frames(tester);
      await tester.tap(find.text('学習記録'));
      await frames(tester);
      await tester.tap(find.byType(BackButton).hitTestable());
      await frames(tester);
      await tester.tap(find.byKey(const ValueKey('main-tab-home')));
      await frames(tester);
      expect(find.byType(RewardCelebration), findsNothing);
      expect(store.coins, 2);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets(
    'phase 2: encyclopedia selects a goal and confirmed balance drives progress',
    (tester) async {
      await loadZoo(tester);
      await tester.tap(find.byTooltip('動物一覧'));
      await frames(tester);
      await tester.tap(find.byTooltip('目標の動物を選ぶ'));
      await frames(tester);
      await tester.tap(find.text('キツネ'));
      await frames(tester);
      expect(find.byType(GoalBanner), findsOneWidget);
      expect(find.text('あと150コイン'), findsOneWidget);
      final repository =
          tester.widget<ZooStudyApp>(find.byType(ZooStudyApp)).gameRepository!
              as MockGameRepository;
      final data = repository.currentSnapshot.toJson();
      data['coins'] = 250;
      data['revision'] = repository.currentSnapshot.revision + 1;
      repository.receiveConfirmedSnapshot(GameSnapshot.fromJson(data));
      await frames(tester);
      expect(find.text('あと0コイン'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
  testWidgets(
    'phase 3: new confirmed rewards welcome animals once without granting extra coins',
    (tester) async {
      await loadZoo(tester);
      final repository =
          tester.widget<ZooStudyApp>(find.byType(ZooStudyApp)).gameRepository!
              as MockGameRepository;
      // Existing approved history is a baseline, not a fresh reward.
      expect(find.byType(RewardCelebration), findsNothing);
      final data = repository.currentSnapshot.toJson();
      final receipt = Map<String, dynamic>.from(
        (data['rewards'] as List).first as Map,
      );
      receipt['assignmentId'] = 'new_assignment';
      receipt['id'] = 'new_assignment_${data['studentId']}_submit';
      receipt['kind'] = 'submit';
      receipt['amount'] = 30;
      final assignment = Map<String, dynamic>.from(
        (data['assignments'] as List).first as Map,
      )..['id'] = 'new_assignment';
      data['assignments'] = [...data['assignments'] as List, assignment];
      data['rewards'] = [...data['rewards'] as List, receipt];
      data['coins'] = 130;
      data['revision'] = repository.currentSnapshot.revision + 1;
      final confirmed = GameSnapshot.fromJson(data);
      repository.receiveConfirmedSnapshot(confirmed);
      await frames(tester);
      expect(find.byType(RewardCelebration), findsOneWidget);
      expect(repository.currentSnapshot.coins, 130);
      await tester.tap(find.widgetWithText(OutlinedButton, '閉じる'));
      await frames(tester);
      repository.receiveConfirmedSnapshot(confirmed);
      await frames(tester);
      expect(find.byType(RewardCelebration), findsNothing);
      expect(repository.currentSnapshot.coins, 130);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets('phase 5: an unowned laboratory only offers its shop entry', (
    tester,
  ) async {
    await loadZoo(tester);
    final repository =
        tester.widget<ZooStudyApp>(find.byType(ZooStudyApp)).gameRepository!
            as MockGameRepository;
    await tester.tap(find.byKey(const ValueKey('home-section-2')));
    await frames(tester);
    await tester.ensureVisible(find.text('研究所'));
    await tester.tap(find.text('研究所'));
    await frames(tester);
    expect(find.text('研究所を購入・配置すると利用できます'), findsOneWidget);
    expect(find.text('購入する'), findsNothing);
    expect(repository.currentSnapshot.coins, 100);
    expect(repository.currentSnapshot.ownedAnimalIds, isEmpty);
    await tester.pumpWidget(const SizedBox.shrink());
  });
  for (final (targetId, name, cost) in [
    ('evolved_fox', '進化キツネ', 800),
    ('fire_fox', '炎狐', 500),
  ]) {
    testWidgets(
      'placed laboratory unlocks $name and retains the original fox',
      (tester) async {
        await loadZoo(tester);
        final repository =
            tester.widget<ZooStudyApp>(find.byType(ZooStudyApp)).gameRepository!
                as MockGameRepository;
        final data = repository.currentSnapshot.toJson();
        data['ownedAnimalIds'] = ['fox'];
        data['ownedFacilityIds'] = ['laboratory'];
        data['coins'] = 1000;
        data['revision'] = repository.currentSnapshot.revision + 1;
        data['layout'] = {
          'schemaVersion': 1,
          'enclosures': [],
          'animalEnclosures': <String, String>{},
          'facilities': [
            {'facilityId': 'laboratory', 'left': 11, 'top': 0},
          ],
        };
        repository.receiveConfirmedSnapshot(GameSnapshot.fromJson(data));
        await frames(tester);
        await tester.tap(find.byKey(const ValueKey('home-section-2')));
        await frames(tester);
        await tester.ensureVisible(find.text('研究所'));
        await tester.tap(find.text('研究所'));
        await frames(tester);
        await tester.tap(find.text(name));
        await frames(tester);
        await tester.ensureVisible(find.text('進化する'));
        await tester.tap(find.text('進化する'));
        await frames(tester);
        await tester.ensureVisible(
          find.byKey(const ValueKey('confirm-purchase')),
        );
        await tester.tap(find.byKey(const ValueKey('confirm-purchase')));
        await frames(tester);
        expect(
          repository.currentSnapshot.ownedAnimalIds,
          containsAll(['fox', targetId]),
        );
        expect(repository.currentSnapshot.coins, 1000 - cost);
        await closeSheet(tester);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
      },
    );
  }
}
