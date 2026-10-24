import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zoo_study/features/auth/presentation/role_selection_screen.dart';

void main() {
  for (final role in ['先生', '生徒']) {
    testWidgets('$role remains selected until a fresh app session', (
      tester,
    ) async {
      Widget app() => MaterialApp(
        home: RoleSelectionScreen(
          teacherPageBuilder: (_) => const Scaffold(body: Text('先生のホーム')),
          studentPageBuilder: (_) => const Scaffold(body: Text('生徒のホーム')),
        ),
      );
      await tester.pumpWidget(app());
      await tester.tap(find.text('$roleはこちら'));
      await tester.pump();
      await tester.tap(find.text('確定'));
      await tester.pumpAndSettle();
      final context = tester.element(find.text('$roleのホーム'));
      expect(Navigator.of(context).canPop(), isFalse);
      expect(find.byType(RoleSelectionScreen), findsNothing);
      await Navigator.of(context).maybePop();
      await tester.pumpAndSettle();
      expect(find.text('$roleのホーム'), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpWidget(app());
      expect(find.text('先生はこちら'), findsOneWidget);
      expect(find.text('生徒はこちら'), findsOneWidget);
      expect(
        tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
        isNull,
      );
    });
  }
}
