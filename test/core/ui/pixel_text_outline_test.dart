import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zoo_study/core/ui/zoo_ui.dart';

void main() {
  testWidgets(
    'wood headings and action labels inherit crisp contrast outlines',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: PixelUiTheme(
            child: Scaffold(
              body: Column(
                children: [
                  const WoodPanel(child: Text('木枠')),
                  const WoodPanel(originalSheet: true, child: Text('旧木枠')),
                  ColorActionPanel(
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(onTap: () {}, child: const Text('カード')),
                    ),
                  ),
                  FilledButton(onPressed: () {}, child: const Text('購入')),
                  FilledButton(
                    style: PixelUiTheme.colorfulButtonStyle(ButtonPalette.blue),
                    onPressed: () {},
                    child: const Text('青ボタン'),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      for (final label in ['木枠', '旧木枠', 'カード', '購入', '青ボタン']) {
        final rich = tester.widget<RichText>(
          find.descendant(
            of: find.text(label),
            matching: find.byType(RichText),
          ),
        );
        final style = rich.text.style!;
        expect(style.shadows, hasLength(8), reason: label);
        expect(style.shadows!.every((s) => s.blurRadius == 0), isTrue);
        expect(
          style.shadows!.first.color,
          label == '青ボタン' ? const Color(0xFF101810) : Colors.white,
          reason: label,
        );
        if (label == '青ボタン') expect(style.color, Colors.white);
        // Outline is inherited, so each label has just one text/semantics tree.
        expect(find.text(label), findsOneWidget);
      }
    },
  );
}
