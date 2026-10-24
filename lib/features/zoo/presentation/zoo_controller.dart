import 'dart:math';

import 'package:flutter/foundation.dart';

import '../domain/animal_walker.dart';
import '../domain/zoo_world.dart';

class ZooController extends ChangeNotifier {
  ZooController(this.world, {Random? random}) {
    final source = random ?? Random();
    animals = List.unmodifiable([
      for (final definition in world.animals)
        AnimalWalker(
          instanceId: '${definition.id}-1',
          definition: definition,
          random: source,
        ),
    ]);
  }

  final ZooWorld world;
  late final List<AnimalWalker> animals;

  void advance(double seconds) {
    if (!seconds.isFinite || seconds <= 0) return;
    // Avoid teleporting after dropped frames or resuming the app.
    final step = min(seconds, 0.1);
    for (final animal in animals) {
      animal.advance(step);
    }
    notifyListeners();
  }
}
