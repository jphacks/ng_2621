import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zoo_study/app_bootstrap.dart';

void main() {
  testWidgets(
    'explicit presentation launch works before Firebase and preferences',
    (tester) async {
      await tester.pumpWidget(const AppBootstrap());
      await tester.pump();
      final teacher =
          const String.fromEnvironment('ZOOSTUDY_PRESENTATION_ROLE') ==
          'teacher';
      await tester.tap(find.text(teacher ? '先生はこちら' : '生徒はこちら'));
      await tester.pump();
      await tester.ensureVisible(find.text('確定'));
      await tester.tap(find.text('確定'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      if (teacher) {
        expect(find.text('課題を作成'), findsOneWidget);
      } else {
        expect(find.byKey(const ValueKey('demo-start')), findsOneWidget);
        expect(find.byKey(const ValueKey('demo-start-teacher')), findsNothing);
      }
      expect(find.text('保存先を開けませんでした'), findsNothing);
      expect(tester.takeException(), isNull);
    },
    skip: !const bool.fromEnvironment('ZOOSTUDY_PRESENTATION'),
  );
}
