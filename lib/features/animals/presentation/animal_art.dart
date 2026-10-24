import 'package:flutter/material.dart';

import '../../../core/ui/zoo_ui.dart';

/// Presentation-only ID mapping. Adding artwork does not unlock or sell animals.
class AnimalArt extends StatelessWidget {
  const AnimalArt({
    super.key,
    required this.animalId,
    this.size = 32,
    this.fallback,
  });
  final String animalId;
  final double size;
  final Widget? fallback;

  static const _parts = <String, ZooArtPart>{
    'rabbit': ZooArtPart.rabbit,
    'deer': ZooArtPart.deer,
    'fox': ZooArtPart.fox,
    'evolved_fox': ZooArtPart.evolvedFox,
    'penguin': ZooArtPart.penguin,
    'monkey': ZooArtPart.monkey,
    'rhino': ZooArtPart.rhino,
    'giraffe': ZooArtPart.giraffe,
    'elephant': ZooArtPart.elephant,
    'bird1': ZooArtPart.bird1,
    'bird2': ZooArtPart.bird2,
    'bird3': ZooArtPart.bird3,
    'bird4': ZooArtPart.bird4,
    'bird5': ZooArtPart.bird5,
    'bird6': ZooArtPart.bird6,
  };

  static bool hasArt(String id) => _parts.containsKey(id);

  @override
  Widget build(BuildContext context) {
    final part = _parts[animalId];
    return SizedBox.square(
      dimension: size,
      child: part == null
          ? fallback ?? const Icon(Icons.pets)
          : FittedBox(
              fit: BoxFit.contain,
              child: ZooArtSprite(part: part, scale: 1),
            ),
    );
  }
}
