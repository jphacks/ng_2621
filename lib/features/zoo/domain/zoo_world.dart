import 'dart:math';

/// Coordinates and speed are measured in tiles, independent of rendering size.
class MovementArea {
  const MovementArea(this.left, this.top, this.right, this.bottom);

  final double left;
  final double top;
  final double right;
  final double bottom;

  bool contains(Point<double> point) =>
      point.x >= left &&
      point.x <= right &&
      point.y >= top &&
      point.y <= bottom;

  factory MovementArea.fromJson(Map<String, dynamic> json) => MovementArea(
    (json['left'] as num).toDouble(),
    (json['top'] as num).toDouble(),
    (json['right'] as num).toDouble(),
    (json['bottom'] as num).toDouble(),
  );
}

class AnimalDefinition {
  const AnimalDefinition({
    required this.id,
    required this.name,
    required this.imagePath,
    required this.speed,
    required this.area,
    required this.placeholderColor,
    this.evolutionIds = const [],
  });

  final String id;
  final String name;
  final String? imagePath;
  final double speed;
  final MovementArea area;
  final int placeholderColor;
  final List<String> evolutionIds;

  factory AnimalDefinition.fromJson(
    Map<String, dynamic> json,
  ) => AnimalDefinition(
    id: json['id'] as String,
    name: json['name'] as String,
    imagePath: json['imagePath'] as String?,
    speed: (json['speed'] as num).toDouble(),
    area: json['movementArea'] == null
        ? const MovementArea(0.5, 0.5, 0.5, 0.5)
        : MovementArea.fromJson(json['movementArea'] as Map<String, dynamic>),
    placeholderColor: int.parse(json['placeholderColor'] as String, radix: 16),
    evolutionIds: List<String>.from(json['evolutionIds'] as List? ?? []),
  );
}

class FacilityDefinition {
  const FacilityDefinition({
    required this.id,
    required this.tile,
    required this.left,
    required this.top,
    required this.width,
    required this.height,
    this.name,
    this.spriteId,
    bool? blocksAnimalAreas,
  }) : blocksAnimalAreas = blocksAnimalAreas ?? (tile == 'water');
  final String id;
  final String tile;
  final String? name;
  final String? spriteId;
  final bool blocksAnimalAreas;
  String get displayName => name ?? id;
  final int left, top, width, height;
  bool contains(int x, int y) =>
      x >= left && x < left + width && y >= top && y < top + height;
  factory FacilityDefinition.fromJson(Map<String, dynamic> json) =>
      FacilityDefinition(
        id: json['id'] as String,
        tile: json['tile'] as String,
        left: json['left'] as int,
        top: json['top'] as int,
        width: json['width'] as int,
        height: json['height'] as int,
        name: json['name'] as String?,
        spriteId: json['spriteId'] as String?,
        blocksAnimalAreas: json['blocksAnimalAreas'] as bool?,
      );
}

class ZooWorld {
  ZooWorld({
    required this.columns,
    required this.rows,
    required this.tileSize,
    required List<String> tiles,
    required List<AnimalDefinition> animals,
    List<FacilityDefinition> facilities = const [],
  }) : tiles = List.unmodifiable(tiles),
       animals = List.unmodifiable(animals),
       facilities = List.unmodifiable(facilities) {
    if (columns <= 0 ||
        rows <= 0 ||
        tileSize < 16 ||
        tiles.length != rows ||
        tiles.any((row) => row.length != columns) ||
        tiles.any(
          (row) => row.split('').any((tile) => !'.~=#'.contains(tile)),
        )) {
      throw const FormatException('Invalid map dimensions or tiles');
    }
    if (this.facilities.map((f) => f.id).toSet().length !=
            this.facilities.length ||
        this.facilities.any(
          (f) =>
              f.id.isEmpty ||
              !['water', 'forest', 'sprite'].contains(f.tile) ||
              (f.tile == 'sprite' &&
                  (f.spriteId == null || f.spriteId!.isEmpty)) ||
              f.left < 0 ||
              f.top < 0 ||
              f.width <= 0 ||
              f.height <= 0 ||
              f.left + f.width > columns ||
              f.top + f.height > rows,
        )) {
      throw const FormatException('Invalid facility placement');
    }
    final ids = <String>{};
    for (final animal in animals) {
      final area = animal.area;
      if (animal.id.isEmpty ||
          !ids.add(animal.id) ||
          animal.name.isEmpty ||
          !animal.speed.isFinite ||
          animal.speed <= 0 ||
          ![
            area.left,
            area.top,
            area.right,
            area.bottom,
          ].every((n) => n.isFinite) ||
          area.left < 0.5 ||
          area.top < 0.5 ||
          area.right > columns - 0.5 ||
          area.bottom > rows - 0.5 ||
          area.left > area.right ||
          area.top > area.bottom) {
        throw FormatException('Invalid animal definition: ${animal.id}');
      }
    }
    for (final animal in animals) {
      if (animal.evolutionIds.any((id) => !ids.contains(id))) {
        throw FormatException('Unknown evolution for ${animal.id}');
      }
    }
  }

  final int columns;
  final int rows;
  final int tileSize;
  final List<String> tiles;
  final List<AnimalDefinition> animals;
  final List<FacilityDefinition> facilities;

  factory ZooWorld.fromJson(Map<String, dynamic> json) {
    final map = json['map'] as Map<String, dynamic>;
    return ZooWorld(
      columns: map['columns'] as int,
      rows: map['rows'] as int,
      tileSize: map['tileSize'] as int,
      tiles: List<String>.from(map['tiles'] as List),
      facilities: (json['facilities'] as List? ?? [])
          .map((f) => FacilityDefinition.fromJson(f as Map<String, dynamic>))
          .toList(),
      animals: (json['animals'] as List)
          .map(
            (entry) => AnimalDefinition.fromJson(entry as Map<String, dynamic>),
          )
          .toList(),
    );
  }
}
