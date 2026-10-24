import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zoo_study/core/ui/zoo_ui.dart';
import 'package:zoo_study/features/study/demo_assignment_store.dart';
import 'package:zoo_study/features/study/teacher_assignments_screen.dart';
import 'package:zoo_study/main.dart';

void main() {
  testWidgets(
    'role switching shares submitted assignments, approval and zoo balance',
    (tester) async {
      Future<void> frame() async {
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 400));
        await tester.pump();
      }

      Future<void> tap(String text) async {
        tester.testTextInput.hide();
        await frame();
        await tester.ensureVisible(find.text(text));
        await frame();
        await tester.tap(find.text(text));
        await frame();
      }

      Future<void> switchRole(String label) async {
        await tap('その他');
        await tap('先生・生徒を選び直す');
        await tap(label);
        await tap('確定');
      }

      await tester.runAsync(() async {
        await rootBundle.loadString('assets/zoo/world.json');
        await tester.pumpWidget(const ZooStudyApp());
        await precacheImage(
          const AssetImage(ZooUiSprite.assetPath),
          tester.element(find.byType(ZooStudyApp)),
        );
      });
      await tap('先生はこちら');
      await tap('確定');
      await tap('課題');
      final store = tester
          .widget<TeacherAssignmentsScreen>(
            find.byType(TeacherAssignmentsScreen),
          )
          .store;
      store.publish(
        DemoAssignment(
          subject: AssignmentSubject.science,
          title: '理科の復習',
          description: '実験結果をまとめてください',
          dueAt: DateTime.now().add(const Duration(days: 1)),
        ),
      );
      await frame();
      await tester.tap(find.byType(BackButton).hitTestable().last);
      await frame();
      await switchRole('生徒はこちら');
      await tap('課題');
      expect(find.text('理科の復習'), findsOneWidget);
      await tap('詳細・回答する');
      await tester.enterText(find.byType(TextFormField), '実験結果をまとめました');
      await tap('課題を提出する');
      expect(store.coins, 30);
      await tester.tap(find.byType(BackButton).hitTestable().last);
      await frame();
      await tester.tap(find.byType(BackButton).hitTestable().last);
      await frame();
      await switchRole('先生はこちら');
      await tap('課題');
      expect(find.text('状態：確認待ち'), findsOneWidget);
      await tap('提出内容を確認');
      expect(
        find.widgetWithText(SelectableText, '実験結果をまとめました'),
        findsOneWidget,
      );
      await tap('内容を確認して承認');
      expect(store.coins, 100);
      await tester.tap(find.byType(BackButton).hitTestable().last);
      await frame();
      await tester.tap(find.byType(BackButton).hitTestable().last);
      await frame();
      await switchRole('生徒はこちら');
      expect(find.text('100'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
}
