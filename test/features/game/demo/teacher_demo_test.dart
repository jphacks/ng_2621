import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zoo_study/features/game/demo/presentation_scenario.dart';
import 'package:zoo_study/features/game/demo/teacher_demo_screen.dart';
import 'package:zoo_study/features/study/teacher_assignments_screen.dart';
import 'package:zoo_study/features/study/assignment_detail_screen.dart';
import 'package:zoo_study/features/study/study_detector/study_records_screen.dart';

void main() {
  for (final scale in [1.0, 2.0]) {
    testWidgets(
      'teacher demo uses existing creation, approval and advice screens at scale $scale',
      (tester) async {
        tester.view.physicalSize = const Size(320, 568);
        tester.view.devicePixelRatio = 1;
        tester.platformDispatcher.textScaleFactorTestValue = scale;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
        await tester.pumpWidget(const MaterialApp(home: TeacherDemoScreen()));
        Future<void> frame() async {
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 400));
          await tester.pump(const Duration(milliseconds: 400));
        }

        Future<void> tap(String text) async {
          FocusManager.instance.primaryFocus?.unfocus();
          await frame();
          if (find.text(text).evaluate().isEmpty) {
            final scroll = find
                .descendant(
                  of: find.byType(ListView).last,
                  matching: find.byType(Scrollable),
                )
                .first;
            tester.state<ScrollableState>(scroll).position.jumpTo(0);
            await frame();
            await tester.scrollUntilVisible(
              find.text(text),
              160,
              scrollable: find
                  .descendant(
                    of: find.byType(ListView).last,
                    matching: find.byType(Scrollable),
                  )
                  .first,
            );
            await frame();
          }
          for (var attempt = 0; attempt < 2; attempt++) {
            await tester.ensureVisible(find.text(text).last);
            await frame();
          }
          await tester.tap(find.text(text).hitTestable().last);
          await frame();
        }

        await tap('課題');
        expect(find.byType(TeacherAssignmentsScreen), findsOneWidget);
        await tap('課題を作成');
        expect(find.text(PresentationScenario.title), findsOneWidget);

        await tap('課題を配布する');

        await tap('提出内容を確認');
        expect(find.byType(AssignmentDetailScreen), findsOneWidget);
        if (find
            .widgetWithText(SelectableText, PresentationScenario.answer)
            .evaluate()
            .isEmpty) {
          await tester.scrollUntilVisible(
            find.widgetWithText(SelectableText, PresentationScenario.answer),
            150,
            scrollable: find
                .descendant(
                  of: find.byType(ListView).last,
                  matching: find.byType(Scrollable),
                )
                .first,
          );
          await frame();
        }
        expect(
          find.widgetWithText(SelectableText, PresentationScenario.answer),
          findsOneWidget,
        );
        await tap('内容を確認して承認');
        final store = tester
            .widget<AssignmentDetailScreen>(find.byType(AssignmentDetailScreen))
            .store;
        expect(store.coins, 100);
        await tester.tap(find.byType(BackButton).hitTestable().last);
        await frame();
        await tap('課題');
        await tap('生徒の学習記録');
        expect(find.byType(StudyRecordsScreen), findsOneWidget);
        await tap('アドバイス案を作成');
        expect(find.text(PresentationScenario.advice), findsOneWidget);
        await tap('確認して生徒へ送る');
        final advice = await store.loadStudyAdvice(teacher: false);
        expect(advice.single.message, PresentationScenario.advice);
        expect(advice.single.published, isTrue);
        expect((await store.loadStudyRecords()).single.studentName, 'デモ生徒');
        await tester.tap(find.byType(BackButton).hitTestable().last);
        await frame();
        expect(find.text('先生の発表デモ・完了'), findsOneWidget);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
      },
    );
  }
}
