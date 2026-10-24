import '../../../../core/ui/sprites/terrain_part.dart';

class TerrainSelection {
  const TerrainSelection(this.part, [this.quarterTurns = 0]);
  final TerrainPart part;
  final int quarterTurns;
}

/// Select existing artwork only; never synthesize a missing vertical fence.
TerrainSelection selectTerrain(String Function(int, int) at, int x, int y) {
  final type = at(x, y);
  if (type == '=') return const TerrainSelection(TerrainPart.dirt);
  if (type == '#') return const TerrainSelection(TerrainPart.stone);
  if (type == '~') return const TerrainSelection(TerrainPart.water);
  const cardinal = [(0, -1), (1, 0), (0, 1), (-1, 0)]; // N E S W, clockwise.
  const diagonal = [(1, -1), (1, 1), (-1, 1), (-1, -1)]; // NE SE SW NW.
  for (final surface in ['=', '#']) {
    final sides = [
      for (var i = 0; i < 4; i++)
        if (at(x + cardinal[i].$1, y + cardinal[i].$2) == surface) i,
    ];
    if (sides.length == 1) {
      final native = surface == '='
          ? 2
          : 3; // Dirt points south; stone points west.
      return TerrainSelection(
        surface == '=' ? TerrainPart.grassHalfDirt : TerrainPart.grassHalfStone,
        (sides.single - native + 4) % 4,
      );
    }
    if (sides.length > 1) {
      // No 3/4 or inner-corner artwork is supplied. Use a full material tile.
      return TerrainSelection(
        surface == '=' ? TerrainPart.dirt : TerrainPart.stone,
      );
    }
    final corners = [
      for (var i = 0; i < 4; i++)
        if (at(x + diagonal[i].$1, y + diagonal[i].$2) == surface) i,
    ];
    if (corners.length == 1) {
      final native = surface == '=' ? 1 : 2; // Native dirt SE, stone SW.
      return TerrainSelection(
        surface == '='
            ? TerrainPart.grassQuarterDirt
            : TerrainPart.grassQuarterStone,
        (corners.single - native + 4) % 4,
      );
    }
  }
  return const TerrainSelection(TerrainPart.grass);
}
