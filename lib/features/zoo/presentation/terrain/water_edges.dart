import '../../../../core/ui/sprites/zoo_extra_part.dart';

class WaterEdge {
  const WaterEdge(this.part, this.quarterTurns);
  final ZooExtraPart part;
  final int quarterTurns;
}

/// The supplied quarter has water in the SE; the half has water in the south.
/// Shore pixels stay inside the facility footprint. Interior cells use full water.
WaterEdge? waterEdgeAt(
  int x,
  int y, {
  required int left,
  required int top,
  required int width,
  required int height,
}) {
  if (width < 2 ||
      height < 2 ||
      x < left ||
      y < top ||
      x >= left + width ||
      y >= top + height) {
    return null;
  }
  final west = x == left, east = x == left + width - 1;
  final north = y == top, south = y == top + height - 1;
  if (north && west) return const WaterEdge(ZooExtraPart.grassWaterQuarter, 0);
  if (north && east) return const WaterEdge(ZooExtraPart.grassWaterQuarter, 1);
  if (south && east) return const WaterEdge(ZooExtraPart.grassWaterQuarter, 2);
  if (south && west) return const WaterEdge(ZooExtraPart.grassWaterQuarter, 3);
  if (north) return const WaterEdge(ZooExtraPart.grassWaterHalf, 0);
  if (east) return const WaterEdge(ZooExtraPart.grassWaterHalf, 1);
  if (south) return const WaterEdge(ZooExtraPart.grassWaterHalf, 2);
  if (west) return const WaterEdge(ZooExtraPart.grassWaterHalf, 3);
  return null;
}
