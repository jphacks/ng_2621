import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zoo_study/core/ui/zoo_ui.dart';
import 'package:zoo_study/features/animals/presentation/animal_art.dart';
import 'package:zoo_study/features/animals/presentation/animal_encyclopedia.dart';
import 'package:zoo_study/features/zoo/domain/zoo_world.dart';

void main() {
  for (final size in [const Size(320, 568), const Size(568, 320)]) {
    testWidgets(
      'square numbered entries use fixed pages and overlaid locks at $size',
      (tester) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final animals = List.generate(
          30,
          (i) => AnimalDefinition(
            id: 'animal$i',
            name: '名前$i',
            imagePath: null,
            speed: 1,
            area: const MovementArea(1, 1, 2, 2),
            placeholderColor: 0xFFFFFFFF,
          ),
        );
        String? selected;
        await tester.pumpWidget(
          MaterialApp(
            home: AnimalEncyclopedia(
              animals: animals,
              ownedIds: const {'animal0'},
              onSelect: (a) => selected = a.id,
            ),
          ),
        );
        final first = find.byKey(const ValueKey('encyclopedia-animal0'));
        final locked = find.byKey(const ValueKey('encyclopedia-animal1'));
        expect(tester.getSize(first).width, tester.getSize(first).height);
        expect(find.text('名前0'), findsNothing);
        expect(find.text('ロック中'), findsNothing);
        final lock = find.descendant(
          of: locked,
          matching: find.byWidgetPredicate(
            (w) => w is ZooUiSprite && w.part == ZooUiPart.lock,
          ),
        );
        expect(
          tester.getCenter(lock),
          tester.getCenter(
            find.descendant(of: locked, matching: find.byType(AnimalArt)),
          ),
        );
        await tester.tap(locked);
        expect(selected, isNull);
        await tester.tap(first);
        expect(selected, 'animal0');
        await tester.drag(first, const Offset(0, -100));
        await tester.pump();
        expect(find.text('No.01'), findsOneWidget);
        await tester.tap(find.byTooltip('次のページ'));
        await tester.pump();
        expect(find.text('No.01'), findsNothing);
        await tester.tap(find.byTooltip('前のページ'));
        await tester.pump();
        expect(find.text('No.01'), findsOneWidget);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
      },
    );
  }
}
