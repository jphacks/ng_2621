import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../domain/zoo_world.dart';
import 'zoo_controller.dart';

class ZooMap extends StatelessWidget {
  const ZooMap({super.key, required this.controller});

  final ZooController controller;

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
                child: ClipRect(
                  child: AnimatedBuilder(
                    animation: controller,
                    child: ValueListenableBuilder<int>(
                      valueListenable: controller.sceneryRevision,
                      builder: (context, revision, child) => RepaintBoundary(
                        key: const ValueKey('zoo-terrain'),
                        child: CustomPaint(
                          size: Size(width, height),
                          painter: _TilePainter(
                            world,
                            controller.animals
                                .map((a) => a.definition)
                                .toList(),
                            controller.ownedFacilities,
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
                            left: (animal.position.x * world.tileSize - 8)
                                .roundToDouble(),
                            top: (animal.position.y * world.tileSize - 8)
                                .roundToDouble(),
                            width: 16,
                            height: 16,
                            child: Semantics(
                              label: animal.definition.name,
                              image: true,
                              child: _AnimalSprite(
                                definition: animal.definition,
                              ),
                            ),
                          ),
                      ],
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
    final placeholder = CustomPaint(
      painter: _AnimalPainter(Color(definition.placeholderColor)),
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

class _TilePainter extends CustomPainter {
  _TilePainter(this.world, this.animals, this.facilities);

  final ZooWorld world;
  final List<AnimalDefinition> animals;
  final Set<String> facilities;

  @override
  void paint(Canvas canvas, Size size) {
    final tile = world.tileSize.toDouble();
    final paint = Paint()..isAntiAlias = false;
    for (var y = 0; y < world.rows; y++) {
      for (var x = 0; x < world.columns; x++) {
        var type = world.tiles[y][x];
        for (final facility in world.facilities) {
          if (!facility.contains(x, y)) continue;
          if (facilities.contains(facility.id)) {
            type = facility.tile == 'water' ? '~' : '^';
          } else if (facility.tile == 'water' && type == '~') {
            type = '.';
          }
        }
        paint.color = switch (type) {
          '=' => const Color(0xFFE4CD9B),
          '~' => const Color(0xFF6CBCCB),
          '^' => const Color(0xFF4F8150),
          _ =>
            (x + y).isEven ? const Color(0xFF91BD70) : const Color(0xFF87B568),
        };
        canvas.drawRect(Rect.fromLTWH(x * tile, y * tile, tile, tile), paint);
        if (type == '.') {
          paint.color = const Color(0xFF78A65D);
          canvas.drawRect(
            Rect.fromLTWH(x * tile + 3, y * tile + 9, 2, 2),
            paint,
          );
        } else if (type == '^') {
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
        } else if (type == '~') {
          paint.color = const Color(0xFF9CD5DF);
          canvas.drawRect(
            Rect.fromLTWH(x * tile + 3, y * tile + 7, 7, 1),
            paint,
          );
        }
      }
    }
    // Each configured movement rectangle is also shown as an enclosure.
    paint.color = const Color(0xFF876449);
    paint.style = PaintingStyle.stroke;
    paint.strokeWidth = 1;
    for (final animal in animals) {
      final area = animal.area;
      canvas.drawRect(
        Rect.fromLTRB(
          (area.left - 0.5) * tile + 0.5,
          (area.top - 0.5) * tile + 0.5,
          (area.right + 0.5) * tile - 0.5,
          (area.bottom + 0.5) * tile - 0.5,
        ),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_TilePainter oldDelegate) =>
      oldDelegate.world != world ||
      oldDelegate.animals != animals ||
      oldDelegate.facilities != facilities;
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
