import 'package:flutter_test/flutter_test.dart';
import 'package:zoo_study/core/ui/zoo_ui.dart';
import 'package:zoo_study/features/zoo/presentation/terrain/water_edges.dart';

void main() {
  test('pond corners and sides rotate water inward and leave center full', () {
    WaterEdge? at(int x, int y) =>
        waterEdgeAt(x, y, left: 2, top: 3, width: 5, height: 4);
    for (final entry in [(2, 3, 0), (6, 3, 1), (6, 6, 2), (2, 6, 3)]) {
      final edge = at(entry.$1, entry.$2)!;
      expect(edge.part, ZooExtraPart.grassWaterQuarter);
      expect(edge.quarterTurns, entry.$3);
    }
    for (final entry in [(4, 3, 0), (6, 4, 1), (4, 6, 2), (2, 4, 3)]) {
      final edge = at(entry.$1, entry.$2)!;
      expect(edge.part, ZooExtraPart.grassWaterHalf);
      expect(edge.quarterTurns, entry.$3);
    }
    expect(at(4, 4), isNull);
    expect(at(1, 3), isNull);
    expect(waterEdgeAt(0, 0, left: 0, top: 0, width: 1, height: 1), isNull);
  });
}
