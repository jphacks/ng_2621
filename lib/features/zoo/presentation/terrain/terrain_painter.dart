import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../../../../core/ui/sprites/terrain_part.dart';
import '../../../../core/ui/sprites/zoo_extra_part.dart';
import '../../../game/domain/zoo_layout.dart';
import '../../domain/zoo_world.dart';
import '../../domain/facility_placement.dart';
import 'terrain_selection.dart';
import 'water_edges.dart';

class ZooTerrainPainter extends CustomPainter {
  ZooTerrainPainter(
    this.world,
    this.animals,
    this.facilities,
    this.image, {
    this.placements = const {},
    this.extraImage,
    this.enclosures = const {},
    this.previewOpacity = 1,
    this.previewFacilityId,
    this.previewEnclosureId,
  });
  final Map<String, FacilityPlacement> placements;
  final ZooWorld world;
  final List<AnimalDefinition> animals;
  final Set<String> facilities;
  final ui.Image? image;
  final ui.Image? extraImage;
  final Map<String, Enclosure> enclosures;
  final double previewOpacity;
  final String? previewFacilityId, previewEnclosureId;

  String _at(int x, int y) {
    if (x < 0 || y < 0 || x >= world.columns || y >= world.rows) return '.';
    var type = world.tiles[y][x];
    for (final facility in world.facilities) {
      if (facility.tile == 'water' && facility.contains(x, y) && type == '~') {
        type = '.';
      }
    }
    for (final facility in world.facilities) {
      if (!facilities.contains(facility.id) || facility.tile == 'sprite') {
        continue;
      }
      final position =
          placements[facility.id] ??
          FacilityPlacement(
            facilityId: facility.id,
            left: facility.left,
            top: facility.top,
          );
      if (position.contains(x, y, facility)) {
        type = facility.tile == 'water' ? '~' : '^';
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
    _imageSprite(
      canvas,
      image,
      part.sourceRect,
      destination,
      turns: turns,
      mirrorX: mirrorX,
    );
  }

  void _imageSprite(
    Canvas canvas,
    ui.Image? image,
    Rect source,
    Rect destination, {
    int turns = 0,
    bool mirrorX = false,
    bool mirrorY = false,
  }) {
    if (image == null) return;
    canvas.save();
    canvas.translate(destination.center.dx, destination.center.dy);
    canvas.rotate(turns * math.pi / 2);
    if (mirrorX) canvas.scale(-1, 1);
    if (mirrorY) canvas.scale(1, -1);
    canvas.drawImageRect(
      image,
      source,
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

  WaterEdge? _waterEdge(int x, int y) {
    for (final facility in world.facilities) {
      if (facility.tile != 'water' || !facilities.contains(facility.id)) {
        continue;
      }
      final position =
          placements[facility.id] ??
          FacilityPlacement(
            facilityId: facility.id,
            left: facility.left,
            top: facility.top,
          );
      if (position.contains(x, y, facility)) {
        return waterEdgeAt(
          x,
          y,
          left: position.left,
          top: position.top,
          width: facility.width,
          height: facility.height,
        );
      }
    }
    return null;
  }

  @override
  void paint(Canvas canvas, Size size) {
    final tile = world.tileSize.toDouble();
    final paint = Paint()..isAntiAlias = false;
    for (var y = 0; y < world.rows; y++) {
      for (var x = 0; x < world.columns; x++) {
        final type = _at(x, y);
        final rect = Rect.fromLTWH(x * tile, y * tile, tile, tile);
        final ghost =
            previewOpacity < 1 &&
            world.facilities.any(
              (f) =>
                  f.id == previewFacilityId &&
                  (placements[f.id] ??
                          FacilityPlacement(
                            facilityId: f.id,
                            left: f.left,
                            top: f.top,
                          ))
                      .contains(x, y, f),
            );
        if (ghost) {
          canvas.drawRect(rect, Paint()..color = const Color(0xFF238424));
          _sprite(canvas, TerrainPart.grass, rect);
          canvas.saveLayer(
            rect,
            Paint()..color = Color.fromRGBO(255, 255, 255, previewOpacity),
          );
        }
        // A readable fallback is shown until the cached sheet finishes decoding.
        paint.color = type == '~'
            ? const Color(0xFF6CBCCB)
            : const Color(0xFF238424);
        canvas.drawRect(rect, paint);
        final selection = selectTerrain(_at, x, y);
        final edge = type == '~' && extraImage != null
            ? _waterEdge(x, y)
            : null;
        if (edge == null) {
          _sprite(canvas, selection.part, rect, turns: selection.quarterTurns);
        } else {
          _imageSprite(
            canvas,
            extraImage,
            edge.part.sourceRect,
            rect,
            turns: edge.quarterTurns,
          );
        }
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
        if (ghost) canvas.restore();
      }
    }
    for (final pen in enclosures.values) {
      final ghost = previewOpacity < 1 && pen.id == previewEnclosureId;
      if (ghost) {
        canvas.saveLayer(
          Rect.fromLTWH(
            pen.left * tile,
            pen.top * tile,
            pen.width * tile,
            pen.height * tile,
          ),
          Paint()..color = Color.fromRGBO(255, 255, 255, previewOpacity),
        );
      }
      for (var y = 0; y < pen.height; y++) {
        for (var x = 0; x < pen.width; x++) {
          final sideX = x == 0 || x == pen.width - 1;
          final sideY = y == 0 || y == pen.height - 1;
          if (!sideX && !sideY) continue;
          final rect = Rect.fromLTWH(
            (pen.left + x) * tile,
            (pen.top + y) * tile,
            tile,
            tile,
          );
          if (sideX && sideY) {
            _imageSprite(
              canvas,
              extraImage,
              ZooExtraPart.fenceBottomLeft.sourceRect,
              rect,
              mirrorX: x == pen.width - 1,
              mirrorY: y == 0,
            );
          } else if (sideX) {
            _imageSprite(
              canvas,
              extraImage,
              ZooExtraPart.fenceVertical.sourceRect,
              rect,
            );
          } else {
            _sprite(
              canvas,
              y == pen.height - 1 && x == pen.width ~/ 2
                  ? TerrainPart.fenceGate
                  : TerrainPart.fence,
              rect,
            );
          }
        }
      }
      if (ghost) canvas.restore();
    }
  }

  @override
  bool shouldRepaint(ZooTerrainPainter old) =>
      old.previewOpacity != previewOpacity ||
      old.previewFacilityId != previewFacilityId ||
      old.previewEnclosureId != previewEnclosureId ||
      old.world != world ||
      old.animals != animals ||
      old.facilities != facilities ||
      old.image != image ||
      old.extraImage != extraImage ||
      old.placements != placements ||
      old.enclosures != enclosures;
}
