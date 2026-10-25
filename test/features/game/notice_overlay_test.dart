import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zoo_study/app.dart';
import 'package:zoo_study/features/game/data/mock_game_repository.dart';
import 'package:zoo_study/features/game/domain/game_snapshot.dart';
import 'package:zoo_study/features/game/presentation/notice_transition.dart';
import 'package:zoo_study/features/zoo/presentation/zoo_viewport.dart';

import '../../widget_test.dart' show loadZoo;

void main() {
  testWidgets(
    'reward notice overlays without shrinking the page, expires, and replay stays silent',
    (tester) async {
      await loadZoo(tester);
      final repo =
          tester.widget<ZooStudyApp>(find.byType(ZooStudyApp)).gameRepository!
              as MockGameRepository;
      final before = tester.getRect(find.byType(ZooViewport));
      final data = repo.currentSnapshot.toJson();
      final reward =
          Map<String, dynamic>.from((data['rewards'] as List).first as Map)
            ..['assignmentId'] = 'overlay_assignment'
            ..['id'] = 'overlay_assignment_${data['studentId']}_submit'
            ..['kind'] = 'submit'
            ..['amount'] = 30;
      final assignment = Map<String, dynamic>.from(
        (data['assignments'] as List).first as Map,
      )..['id'] = 'overlay_assignment';
      data['assignments'] = [...data['assignments'] as List, assignment];
      data['rewards'] = [...data['rewards'] as List, reward];
      data['coins'] = repo.currentSnapshot.coins + 30;
      data['revision'] = repo.currentSnapshot.revision + 1;
      final confirmed = GameSnapshot.fromJson(data);
      repo.receiveConfirmedSnapshot(confirmed);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 250));
      expect(find.byType(NoticeTransition), findsOneWidget);
      expect(tester.getRect(find.byType(ZooViewport)), before);
      expect(
        find.byKey(const ValueKey('home-section-1')).hitTestable(),
        findsOneWidget,
      );
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 2600)),
      );
      await tester.pump(const Duration(seconds: 3));
      await tester.pump();
      expect(find.byType(NoticeTransition), findsNothing);
      expect(repo.currentSnapshot.coins, confirmed.coins);
      repo.receiveConfirmedSnapshot(confirmed);
      await tester.pump();
      expect(find.byType(NoticeTransition), findsNothing);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
}
