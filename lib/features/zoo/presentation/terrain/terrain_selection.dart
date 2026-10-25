import '../../../../core/ui/sprites/terrain_part.dart';

class TerrainSelection {
  const TerrainSelection(this.part, [this.quarterTurns = 0]);
  final TerrainPart part;
  final int quarterTurns;
}

const _directions = [(0, -1), (1, 0), (0, 1), (-1, 0)];

int? _dirtSide(String Function(int, int) at, int x, int y) {
  final sides = [
    for (var i = 0; i < 4; i++)
      if (at(x + _directions[i].$1, y + _directions[i].$2) == '=') i,
  ];
  return sides.length == 1 ? sides.single : null;
}

/// Stone ends one cell before the continuous half-dirt shoulder.
int? _pathCap(String Function(int, int) at, int x, int y) {
  if (at(x, y) != '#' || _dirtSide(at, x, y) != null) return null;
  for (var i = 0; i < 4; i++) {
    final dx = _directions[i].$1, dy = _directions[i].$2;
    if (at(x + dx, y + dy) == '#' && _dirtSide(at, x + dx, y + dy) == i) {
      return (i + 2) % 4;
    }
  }
  return null;
}

TerrainSelection _half(String surface, int direction) => TerrainSelection(
  surface == '=' ? TerrainPart.grassHalfDirt : TerrainPart.grassHalfStone,
  (direction - (surface == '=' ? 2 : 3) + 4) % 4,
);

/// Keep supplied half/quarter edges around path junctions as a grass buffer.
TerrainSelection selectTerrain(String Function(int, int) at, int x, int y) {
  final type = at(x, y);
  if (type == '=') return const TerrainSelection(TerrainPart.dirt);
  if (type == '#') {
    final shoulder = _dirtSide(at, x, y);
    if (shoulder != null) return _half('=', shoulder);
    final cap = _pathCap(at, x, y);
    return cap == null
        ? const TerrainSelection(TerrainPart.stone)
        : _half('#', cap);
  }
  if (type == '~') return const TerrainSelection(TerrainPart.water);
  const cardinal = [(0, -1), (1, 0), (0, 1), (-1, 0)]; // N E S W, clockwise.
  const diagonal = [(1, -1), (1, 1), (-1, 1), (-1, -1)]; // NE SE SW NW.
  final dirt = _dirtSide(at, x, y);
  if (dirt != null) return _half('=', dirt);
  // Neighbors of a half-ended path need matching quarter corners, rather
  // than extending a full half-material stripe toward the crossing.
  for (var side = 0; side < 4; side++) {
    final neighbor = cardinal[side];
    final cap = _pathCap(at, x + neighbor.$1, y + neighbor.$2);
    if (cap == null || cap % 2 == side % 2) continue;
    final surface = at(x + neighbor.$1, y + neighbor.$2);
    final direction = cardinal[cap];
    final corner = diagonal.indexOf((
      neighbor.$1 + direction.$1,
      neighbor.$2 + direction.$2,
    ));
    return TerrainSelection(
      surface == '='
          ? TerrainPart.grassQuarterDirt
          : TerrainPart.grassQuarterStone,
      (corner - (surface == '=' ? 1 : 2) + 4) % 4,
    );
  }
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
