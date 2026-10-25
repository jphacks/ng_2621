import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zoo_study/core/ui/zoo_ui.dart';
import 'package:zoo_study/features/animals/presentation/animal_art.dart';

void main() {
  test('new animal IDs have art while people remain separate', () {
    for (final part in ZooCharacterPart.values) {
      expect(AnimalArt.hasArt(part.id), !part.isPerson, reason: part.id);
    }
    expect(AnimalArt.hasArt('fox'), isTrue);
    expect(AnimalArt.hasArt('evolved_fox'), isTrue);
    expect(AnimalArt.hasArt('unknown'), isFalse);
  });

  testWidgets('panda placeholder uses new art without replacing existing fox', (
    tester,
  ) async {
    await tester.pumpWidget(
      const Directionality(
        textDirection: TextDirection.ltr,
        child: Column(
          children: [
            AnimalArt(animalId: 'panda'),
            AnimalArt(animalId: 'fox'),
          ],
        ),
      ),
    );
    expect(
      tester.widget<ZooCharacterSprite>(find.byType(ZooCharacterSprite)).part,
      ZooCharacterPart.panda,
    );
    expect(
      tester.widget<ZooArtSprite>(find.byType(ZooArtSprite)).part,
      ZooArtPart.fox,
    );
  });
}
