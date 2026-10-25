import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zoo_study/app_bootstrap.dart';

void main() {
  testWidgets(
    'explicit presentation launch works before Firebase and preferences',
    (tester) async {
      await tester.pumpWidget(const AppBootstrap());
      await tester.pump();
      expect(find.byKey(const ValueKey('demo-start')), findsOneWidget);
      expect(find.text('保存先を開けませんでした'), findsNothing);
      expect(tester.takeException(), isNull);
    },
    skip: !const bool.fromEnvironment('ZOOSTUDY_PRESENTATION'),
  );
}
