import 'dart:ui';

import '../../../core/ui/sprites/zoo_building_sprite.dart';

/// Display-only furnishing for a clearly labelled presentation scene.
class MapDecoration {
  const MapDecoration(this.part, this.bounds);
  final ZooBuildingPart part;
  final Rect bounds;
}
