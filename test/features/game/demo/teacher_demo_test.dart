import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zoo_study/features/game/demo/demo_tutorial_screen.dart';
import 'package:zoo_study/features/game/demo/presentation_scenario.dart';
import 'package:zoo_study/features/game/demo/teacher_demo_screen.dart';

void main() {
  for (final scale in [1.0, 2.0]) {
    testWidgets(
      'teacher phone completes distribution, approval, advice and reset at scale $scale',
      (tester) async {
        tester.view.physicalSize = const Size(320, 568);
        tester.view.devicePixelRatio = 1;
        tester.platformDispatcher.textScaleFactorTestValue = scale;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
        await tester.pumpWidget(const PresentationDemoApp());
        Future<void> tap(String key) async {
          FocusManager.instance.primaryFocus?.unfocus();
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 400));
          final target = find.byKey(ValueKey(key));
          for (var attempt = 0; attempt < 3; attempt++) {
            await tester.ensureVisible(target);
            await tester.pump();
            await tester.pump(const Duration(milliseconds: 400));
          }
          await tester.tap(target);
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 400));
        }

        await tap('demo-start-teacher');
        expect(find.byType(TeacherDemoScreen), findsOneWidget);
        expect(find.text(PresentationScenario.title), findsOneWidget);
        await tester.enterText(
          find.byKey(const ValueKey('teacher-task-title')),
          '',
        );
        tester.testTextInput.hide();
        await tap('teacher-create');
        expect(find.text('課題名を入力してください'), findsOneWidget);
        await tester.enterText(
          find.byKey(const ValueKey('teacher-task-title')),
          PresentationScenario.title,
        );
        tester.testTextInput.hide();
        await tap('teacher-create');
        expect(find.text('状態：作成済み・未配布'), findsOneWidget);
        await tap('teacher-distribute');
        expect(find.text('状態：配布済み'), findsOneWidget);
        expect(find.text('デモ生徒：未提出'), findsOneWidget);
        await tap('teacher-refresh-submission');
        expect(find.text(PresentationScenario.answer), findsOneWidget);
        expect(find.text('デモ生徒：確認待ち'), findsOneWidget);
        await tap('teacher-approve');
        expect(find.text('デモ生徒：承認済み ＋70コイン'), findsOneWidget);
        await tap('teacher-send-advice');
        expect(find.text(PresentationScenario.advice), findsOneWidget);
        expect(
          find.byKey(const ValueKey('teacher-advice-sent')),
          findsOneWidget,
        );
        await tester.tap(find.byTooltip('デモを初期化'));
        await tester.pump();
        expect(find.byKey(const ValueKey('teacher-create')), findsOneWidget);
        expect(find.byKey(const ValueKey('teacher-advice-sent')), findsNothing);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
      },
    );
  }
}
