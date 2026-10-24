import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zoo_study/core/ui/zoo_ui.dart';
import 'package:zoo_study/main.dart';

void main() {
  testWidgets(
    'debug entry opens interactive study demo with no fixture rewards',
    (tester) async {
      await tester.runAsync(() async {
        await rootBundle.loadString('assets/zoo/world.json');
        await tester.pumpWidget(const ZooStudyApp());
        await tester.ensureVisible(find.text('生徒はこちら'));
        await tester.tap(find.text('生徒はこちら'));
        await tester.pump();
        await tester.ensureVisible(find.text('確定'));
        await tester.tap(find.text('確定'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 400));
        await precacheImage(
          const AssetImage(ZooUiSprite.assetPath),
          tester.element(find.byType(ZooStudyApp)),
        );
      });
      await tester.pump();
      expect(find.text('コイン・デモ'), findsOneWidget);
      expect(find.text('0'), findsOneWidget);
      await tester.tap(find.text('課題'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.text('自分の課題'), findsOneWidget);
      expect(find.text('追加された課題はありません'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
}
