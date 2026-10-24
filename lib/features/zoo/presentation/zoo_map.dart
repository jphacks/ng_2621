import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';

import '../domain/zoo_world.dart';
import '../domain/facility_placement.dart';
import '../domain/animal_walker.dart';
import '../../game/domain/zoo_layout.dart';
import '../../animals/presentation/animal_art.dart';
import 'zoo_controller.dart';
import '../../../core/ui/zoo_ui.dart';
import 'terrain/terrain_painter.dart';

class ZooMap extends StatelessWidget {
  const ZooMap({
    super.key,
    required this.controller,
    this.onAnimalSelected,
    this.onTileSelected,
    this.draggableTileArea,
    this.onTileDragged,
    this.placementsOverride,
    this.overlay,
    this.enclosurePreview,
    this.previewValid = true,
  });

  final ZooController controller;
  final void Function(int x, int y)? onTileSelected;
  final Rect? draggableTileArea;
  final void Function(int x, int y)? onTileDragged;
  final Map<String, FacilityPlacement>? placementsOverride;
  final Widget? overlay;
  final Enclosure? enclosurePreview;
  final bool previewValid;
  Map<String, Enclosure> get _drawnEnclosures {
    final result = {...controller.layout.enclosures};
    final preview = enclosurePreview;
    if (preview != null) result[preview.id] = preview;
    return result;
  }

  Offset _animalPosition(AnimalWalker animal) {
    var x = animal.position.x, y = animal.position.y;
    final pen = enclosurePreview;
    if (pen != null &&
        controller.layout.animalEnclosures[animal.definition.id] == pen.id) {
      final area = pen.movementArea;
      x = x.clamp(area.left, area.right);
      y = y.clamp(area.top, area.bottom);
    }
    return Offset(
      x * controller.world.tileSize - 8,
      y * controller.world.tileSize - 8,
    );
  }

  final ValueChanged<AnimalDefinition>? onAnimalSelected;

  @override
  Widget build(BuildContext context) {
    final world = controller.world;
    final width = world.columns * world.tileSize.toDouble();
    final height = world.rows * world.tileSize.toDouble();
    return LayoutBuilder(
      builder: (context, constraints) {
        final dpr = MediaQuery.devicePixelRatioOf(context);
        final fit = math.min(
          constraints.maxWidth / width,
          constraints.maxHeight / height,
        );
        // Integer physical pixel scaling prevents uneven pixel sizes on phones.
        final scale = math.max(1, (fit * dpr).floor()) / dpr;
        final actualScale = math.min(fit, scale);
        return Center(
          child: SizedBox(
            width: width * actualScale,
            height: height * actualScale,
            child: FittedBox(
              child: SizedBox(
                width: width,
                height: height,
                child: Builder(
                  builder: (mapContext) => GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTapUp: onAnimalSelected == null && onTileSelected == null
                        ? null
                        : (details) {
                            if (onTileSelected != null) {
                              onTileSelected!(
                                (details.localPosition.dx / world.tileSize)
                                    .floor(),
                                (details.localPosition.dy / world.tileSize)
                                    .floor(),
                              );
                              return;
                            }
                            final box =
                                mapContext.findRenderObject()! as RenderBox;
                            AnimalDefinition? nearest;
                            var distance = 24.0;
                            for (final animal in controller.animals) {
                              final center = box.localToGlobal(
                                Offset(
                                  animal.position.x * world.tileSize,
                                  animal.position.y * world.tileSize,
                                ),
                              );
                              final candidate =
                                  (center - details.globalPosition).distance;
                              if (candidate <= distance) {
                                distance = candidate;
                                nearest = animal.definition;
                              }
                            }
                            if (nearest != null) onAnimalSelected!(nearest);
                          },
                    child: ClipRect(
                      child: AnimatedBuilder(
                        animation: controller,
                        child: ValueListenableBuilder<int>(
                          valueListenable: controller.sceneryRevision,
                          builder: (context, revision, child) => RepaintBoundary(
                            key: const ValueKey('zoo-terrain'),
                            child: SpriteSheetImage(
                              assetPath: TerrainSprite.assetPath,
                              builder: (context, image) => SpriteSheetImage(
                                assetPath: ZooExtraSprite.assetPath,
                                builder: (context, extraImage) => SizedBox(
                                  width: width,
                                  height: height,
                                  child: Stack(
                                    children: [
                                      CustomPaint(
                                        size: Size(width, height),
                                        painter: ZooTerrainPainter(
                                          world,
                                          controller.animals
                                              .map((a) => a.definition)
                                              .toList(),
                                          controller.ownedFacilities,
                                          image,
                                          extraImage: extraImage,
                                          enclosures: _drawnEnclosures,
                                          placements:
                                              placementsOverride ??
                                              controller.placements,
                                        ),
                                      ),
                                      for (final facility in world.facilities)
                                        if (facility.tile == 'sprite' &&
                                            (placementsOverride ??
                                                    controller.placements)
                                                .containsKey(facility.id) &&
                                            controller.ownedFacilities.contains(
                                              facility.id,
                                            ))
                                          Positioned(
                                            key: ValueKey(
                                              'facility-${facility.id}',
                                            ),
                                            left:
                                                ((placementsOverride ??
                                                            controller
                                                                .placements)[facility
                                                            .id]
                                                        ?.left ??
                                                    facility.left) *
                                                world.tileSize.toDouble(),
                                            top:
                                                ((placementsOverride ??
                                                            controller
                                                                .placements)[facility
                                                            .id]
                                                        ?.top ??
                                                    facility.top) *
                                                world.tileSize.toDouble(),
                                            width:
                                                facility.width *
                                                world.tileSize.toDouble(),
                                            height:
                                                facility.height *
                                                world.tileSize.toDouble(),
                                            child:
                                                ZooBuildingPart.forId(
                                                      facility.spriteId,
                                                    ) !=
                                                    null
                                                ? FittedBox(
                                                    child: ZooBuildingSprite(
                                                      part:
                                                          ZooBuildingPart.forId(
                                                            facility.spriteId,
                                                          )!,
                                                      scale: 1,
                                                      semanticLabel:
                                                          facility.displayName,
                                                    ),
                                                  )
                                                : const SizedBox.shrink(),
                                          ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                        builder: (context, background) => Stack(
                          clipBehavior: Clip.hardEdge,
                          children: [
                            background!,
                            for (final animal in controller.animals)
                              Positioned(
                                key: ValueKey(animal.instanceId),
                                left: _animalPosition(animal).dx
                                    .roundToDouble(),
                                top: _animalPosition(animal).dy.roundToDouble(),
                                width: 16,
                                height: 16,
                                child: Semantics(
                                  label: animal.definition.name,
                                  image: true,
                                  button: onAnimalSelected != null,
                                  onTap: onAnimalSelected == null
                                      ? null
                                      : () => onAnimalSelected!(
                                          animal.definition,
                                        ),
                                  child: _AnimalSprite(
                                    definition: animal.definition,
                                  ),
                                ),
                              ),
                            if (draggableTileArea != null &&
                                onTileDragged != null)
                              _MapDragTarget(
                                area: draggableTileArea!,
                                tile: world.tileSize.toDouble(),
                                columns: world.columns,
                                rows: world.rows,
                                toMap: (global) =>
                                    (mapContext.findRenderObject()!
                                            as RenderBox)
                                        .globalToLocal(global),
                                onMove: onTileDragged!,
                              ),
                            if (enclosurePreview != null)
                              Positioned.fill(
                                child: IgnorePointer(
                                  child: CustomPaint(
                                    painter: _EnclosureHighlight(
                                      enclosurePreview!,
                                      world.tileSize,
                                      previewValid,
                                    ),
                                  ),
                                ),
                              ),
                            if (overlay != null)
                              Positioned.fill(
                                child: IgnorePointer(child: overlay!),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _AnimalSprite extends StatelessWidget {
  const _AnimalSprite({required this.definition});

  final AnimalDefinition definition;

  @override
  Widget build(BuildContext context) {
    final placeholder = AnimalArt(
      animalId: definition.id,
      size: 16,
      fallback: CustomPaint(
        painter: _AnimalPainter(Color(definition.placeholderColor)),
      ),
    );
    final path = definition.imagePath;
    if (path == null || path.isEmpty) return placeholder;
    return Image.asset(
      path,
      fit: BoxFit.contain,
      filterQuality: FilterQuality.none,
      isAntiAlias: false,
      errorBuilder: (context, error, stackTrace) => placeholder,
    );
  }
}

/// Temporary 8x8 pixel animal, replaceable through imagePath in JSON.
class _AnimalPainter extends CustomPainter {
  _AnimalPainter(this.color);

  final Color color;
  static const _pixels = [
    '  #  #  ',
    ' ###### ',
    ' ##o#o# ',
    ' ###### ',
    '  ####  ',
    ' ###### ',
    ' ##  ## ',
    '        ',
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..isAntiAlias = false;
    for (var y = 0; y < 8; y++) {
      for (var x = 0; x < 8; x++) {
        final pixel = _pixels[y][x];
        if (pixel == ' ') continue;
        paint.color = pixel == 'o' ? const Color(0xFF282C34) : color;
        canvas.drawRect(Rect.fromLTWH(x * 2, y * 2, 2, 2), paint);
      }
    }
  }

  @override
  bool shouldRepaint(_AnimalPainter oldDelegate) => oldDelegate.color != color;
}

class _EnclosureHighlight extends CustomPainter {
  _EnclosureHighlight(this.pen, this.tile, this.valid);
  final Enclosure pen;
  final int tile;
  final bool valid;
  @override
  void paint(Canvas canvas, Size size) {
    final rect = Rect.fromLTWH(
      pen.left * tile.toDouble(),
      pen.top * tile.toDouble(),
      pen.width * tile.toDouble(),
      pen.height * tile.toDouble(),
    );
    final paint = Paint()
      ..isAntiAlias = false
      ..color = valid ? const Color(0x3344AA44) : const Color(0x66FF3333);
    canvas.drawRect(rect, paint);
    paint
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..color = valid ? const Color(0xFF225522) : const Color(0xFFAA2222);
    canvas.drawRect(rect.deflate(0.5), paint);
  }

  @override
  bool shouldRepaint(_EnclosureHighlight old) =>
      old.pen != pen || old.tile != tile || old.valid != valid;
}

/// Keeps the original grab offset while the preview rebuilds under the pointer.
class _MapDragTarget extends StatefulWidget {
  const _MapDragTarget({
    required this.area,
    required this.tile,
    required this.columns,
    required this.rows,
    required this.toMap,
    required this.onMove,
  });
  final Rect area;
  final double tile;
  final int columns, rows;
  final Offset Function(Offset) toMap;
  final void Function(int, int) onMove;
  @override
  State<_MapDragTarget> createState() => _MapDragTargetState();
}

class _MapDragTargetState extends State<_MapDragTarget> {
  Offset? _grabOffset;
  @override
  Widget build(BuildContext context) => Positioned(
    left: widget.area.left * widget.tile,
    top: widget.area.top * widget.tile,
    width: widget.area.width * widget.tile,
    height: widget.area.height * widget.tile,
    child: MouseRegion(
      cursor: SystemMouseCursors.grab,
      child: GestureDetector(
        key: const ValueKey('map-placement-drag'),
        dragStartBehavior: DragStartBehavior.down,
        behavior: HitTestBehavior.opaque,
        onPanStart: (details) => _grabOffset =
            widget.toMap(details.globalPosition) -
            Offset(
              widget.area.left * widget.tile,
              widget.area.top * widget.tile,
            ),
        onPanUpdate: (details) {
          final grab = _grabOffset;
          if (grab == null) return;
          final origin =
              (widget.toMap(details.globalPosition) - grab) / widget.tile;
          widget.onMove(
            origin.dx.round().clamp(
              0,
              math.max(0, widget.columns - widget.area.width.toInt()),
            ),
            origin.dy.round().clamp(
              0,
              math.max(0, widget.rows - widget.area.height.toInt()),
            ),
          );
        },
        onPanEnd: (_) => _grabOffset = null,
        onPanCancel: () => _grabOffset = null,
      ),
    ),
  );
}
