import 'package:flutter_test/flutter_test.dart';
import 'package:zoo_study/core/ui/zoo_ui.dart';
import 'package:zoo_study/features/zoo/presentation/terrain/terrain_selection.dart';

void main() {
  test('full tiles use supplied grass dirt stone and water', () {
    for (final entry in {
      '.': TerrainPart.grass,
      '=': TerrainPart.dirt,
      '#': TerrainPart.stone,
      '~': TerrainPart.water,
    }.entries) {
      final result = selectTerrain(
        (x, y) => x == 0 && y == 0 ? entry.key : '.',
        0,
        0,
      );
      expect(result.part, entry.value);
    }
  });
  test('half tiles rotate from their different native material directions', () {
    const directions = [(0, -1), (1, 0), (0, 1), (-1, 0)];
    for (final material in ['=', '#']) {
      for (var side = 0; side < 4; side++) {
        final offset = directions[side];
        final result = selectTerrain(
          (x, y) => (x, y) == offset ? material : '.',
          0,
          0,
        );
        expect(
          result.part,
          material == '='
              ? TerrainPart.grassHalfDirt
              : TerrainPart.grassHalfStone,
        );
        expect(result.quarterTurns, (side - (material == '=' ? 2 : 3) + 4) % 4);
      }
    }
  });
  test('quarter tiles align all four corners without rotating the map', () {
    const corners = [(1, -1), (1, 1), (-1, 1), (-1, -1)];
    for (final material in ['=', '#']) {
      for (var corner = 0; corner < 4; corner++) {
        final offset = corners[corner];
        final result = selectTerrain(
          (x, y) => (x, y) == offset ? material : '.',
          0,
          0,
        );
        expect(
          result.part,
          material == '='
              ? TerrainPart.grassQuarterDirt
              : TerrainPart.grassQuarterStone,
        );
        expect(
          result.quarterTurns,
          (corner - (material == '=' ? 1 : 2) + 4) % 4,
        );
      }
    }
  });
  test(
    'missing inner corners use an existing full tile instead of new artwork',
    () {
      final result = selectTerrain(
        (x, y) => (x, y) == (1, 0) || (x, y) == (0, 1) ? '=' : '.',
        0,
        0,
      );
      expect(result.part, TerrainPart.dirt);
    },
  );
  test('forest and unavailable neighbor cells remain grass', () {
    expect(
      selectTerrain((x, y) => x == 0 && y == 0 ? '^' : '.', 0, 0).part,
      TerrainPart.grass,
    );
  });
}
