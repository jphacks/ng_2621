import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../../../../core/ui/sprites/terrain_part.dart';
import '../../domain/zoo_world.dart';
import 'terrain_selection.dart';

class ZooTerrainPainter extends CustomPainter {
  ZooTerrainPainter(this.world, this.animals, this.facilities, this.image);
  final ZooWorld world;
  final List<AnimalDefinition> animals;
  final Set<String> facilities;
  final ui.Image? image;

  String _at(int x, int y) {
    if (x < 0 || y < 0 || x >= world.columns || y >= world.rows) return '.';
    var type = world.tiles[y][x];
    for (final facility in world.facilities) {
      if (!facility.contains(x, y)) continue;
      if (facilities.contains(facility.id)) {
        type = facility.tile == 'water' ? '~' : '^';
      } else if (facility.tile == 'water' && type == '~') {
        type = '.';
      }
    }
    return type;
  }

  void _sprite(
    Canvas canvas,
    TerrainPart part,
    Rect destination, {
    int turns = 0,
    bool mirrorX = false,
  }) {
    final image = this.image;
    if (image == null) return;
    canvas.save();
    canvas.translate(destination.center.dx, destination.center.dy);
    canvas.rotate(turns * math.pi / 2);
    if (mirrorX) canvas.scale(-1, 1);
    canvas.drawImageRect(
      image,
      part.sourceRect,
      Rect.fromCenter(
        center: Offset.zero,
        width: destination.width,
        height: destination.height,
      ),
      Paint()
        ..filterQuality = FilterQuality.none
        ..isAntiAlias = false,
    );
    canvas.restore();
  }

  @override
  void paint(Canvas canvas, Size size) {
    final tile = world.tileSize.toDouble();
    final paint = Paint()..isAntiAlias = false;
    for (var y = 0; y < world.rows; y++) {
      for (var x = 0; x < world.columns; x++) {
        final type = _at(x, y);
        final rect = Rect.fromLTWH(x * tile, y * tile, tile, tile);
        // A readable fallback is shown until the cached sheet finishes decoding.
        paint.color = type == '~'
            ? const Color(0xFF6CBCCB)
            : const Color(0xFF238424);
        canvas.drawRect(rect, paint);
        final selection = selectTerrain(_at, x, y);
        _sprite(canvas, selection.part, rect, turns: selection.quarterTurns);
        if (type == '^') {
          paint.color = const Color(0xFF315C3A);
          canvas.drawRect(
            Rect.fromLTWH(x * tile + 4, y * tile + 3, 8, 7),
            paint,
          );
          paint.color = const Color(0xFF70583D);
          canvas.drawRect(
            Rect.fromLTWH(x * tile + 7, y * tile + 10, 2, 4),
            paint,
          );
        }
      }
    }
    // Shared enclosures (e.g. original and evolved fox) get one fence pair.
    final enclosures = <Rect>{};
    for (final animal in animals) {
      final a = animal.area;
      enclosures.add(
        Rect.fromLTRB(
          (a.left - 0.5) * tile,
          (a.top - 0.5) * tile,
          (a.right + 0.5) * tile,
          (a.bottom + 0.5) * tile,
        ),
      );
    }
    for (final rect in enclosures) {
      final count = math.max(2, (rect.width / tile).ceil());
      final segment = rect.width / count;
      for (final bottom in [rect.top, rect.bottom]) {
        for (var index = 0; index < count; index++) {
          final part = index == 0 || index == count - 1
              ? TerrainPart.fenceEnd
              : index == count ~/ 2
              ? TerrainPart.fenceGate
              : TerrainPart.fence;
          _sprite(
            canvas,
            part,
            Rect.fromLTWH(
              rect.left + index * segment,
              bottom - tile + 1,
              segment,
              tile,
            ),
            mirrorX: index == count - 1,
          );
        }
      }
    }
  }

  @override
  bool shouldRepaint(ZooTerrainPainter old) =>
      old.world != world ||
      old.animals != animals ||
      old.facilities != facilities ||
      old.image != image;
}
