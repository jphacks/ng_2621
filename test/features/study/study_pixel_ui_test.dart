import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zoo_study/app.dart';
import 'package:zoo_study/core/ui/zoo_font.dart';
import 'package:zoo_study/core/ui/zoo_ui.dart';
import 'package:zoo_study/features/game/data/mock_game_repository.dart';
import 'package:zoo_study/features/study/presentation/study_chrome.dart';

void main() {
  for (final scale in [1.0, 2.0]) {
    testWidgets(
      'study routes retain font, patterned background and usable navigation at text scale $scale',
      (tester) async {
        tester.view.physicalSize = const Size(320, 568);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final repository = MockGameRepository();
        addTearDown(repository.dispose);
        await tester.runAsync(() async {
          await rootBundle.loadString('assets/zoo/world.json');
          await repository.loadCatalog();
          await tester.pumpWidget(
            MediaQuery(
              data: MediaQueryData.fromView(tester.view)
                  .copyWith(textScaler: TextScaler.linear(scale)),
              child: ZooStudyApp(gameRepository: repository),
            ),
          );
          expect(
            Theme.of(tester.element(find.text('生徒はこちら')))
                .textTheme
                .bodyMedium!
                .fontFamily,
            ZooFont.family,
          );
          await tester.ensureVisible(find.text('生徒はこちら'));
          await tester.tap(find.text('生徒はこちら'));
          await tester.pump();
          await tester.ensureVisible(find.text('確定'));
          await tester.tap(find.text('確定'));
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 400));
        });
        await tester.pump();
        await tester.tap(find.text('学習'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 400));
        expect(find.byType(SpriteTile), findsWidgets);
        await tester.ensureVisible(find.text('学習記録'));
        await tester.pump();
        await tester.tap(find.text('学習記録'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 400));
        await tester.pump(const Duration(milliseconds: 400));
        expect(find.byType(StudyAppBar), findsOneWidget);
        expect(find.byType(TerrainTexture), findsWidgets);
        final back = find.byType(BackButton).hitTestable();
        expect(back, findsOneWidget);
        expect(
          find.descendant(
            of: back,
            matching: find.byWidgetPredicate(
              (w) => w is ZooUiSprite && w.part == ZooUiPart.back,
            ),
          ),
          findsOneWidget,
        );
        await tester.scrollUntilVisible(find.text('学習記録はまだありません'), 180);
        expect(
          Theme.of(tester.element(find.text('学習記録はまだありません')))
              .textTheme
              .bodyMedium!
              .fontFamily,
          ZooFont.family,
        );
        await tester.tap(back);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 400));
        await tester.pump(const Duration(milliseconds: 400));
        expect(find.text('学習'), findsOneWidget);
        expect(find.byType(StudyAppBar), findsNothing);
        expect(find.text('学習メニュー'), findsOneWidget);
        expect(
          find.byKey(const ValueKey('main-tab-home')).hitTestable(),
          findsOneWidget,
        );
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
      },
    );
  }
}
