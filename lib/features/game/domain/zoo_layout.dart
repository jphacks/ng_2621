import '../../zoo/domain/zoo_world.dart';
import '../../zoo/domain/facility_placement.dart';

class Enclosure {
  const Enclosure({
    required this.id,
    required this.left,
    required this.top,
    required this.width,
    required this.height,
  });
  final String id;
  final int left, top, width, height;
  int get area => width * height;
  MovementArea get movementArea => MovementArea(
    left + 1.5,
    top + 1.5,
    left + width - 1.5,
    top + height - 1.5,
  );
  Map<String, dynamic> toJson() => {
    'id': id,
    'left': left,
    'top': top,
    'width': width,
    'height': height,
  };
  factory Enclosure.fromJson(Map<String, dynamic> json) => Enclosure(
    id: json['id'] as String,
    left: json['left'] as int,
    top: json['top'] as int,
    width: json['width'] as int,
    height: json['height'] as int,
  );
}

/// Game-owned confirmed layout. Inventory remains in GameSnapshot.
class ZooLayout {
  ZooLayout({
    Map<String, Enclosure> enclosures = const {},
    Map<String, String> animalEnclosures = const {},
    Map<String, FacilityPlacement> facilities = const {},
  }) : enclosures = Map.unmodifiable(enclosures),
       animalEnclosures = Map.unmodifiable(animalEnclosures),
       facilities = Map.unmodifiable(facilities);
  final Map<String, Enclosure> enclosures;
  final Map<String, String> animalEnclosures;
  final Map<String, FacilityPlacement> facilities;
  Map<String, dynamic> toJson() => {
    'enclosures': enclosures.values.map((e) => e.toJson()).toList(),
    'animalEnclosures': animalEnclosures,
    'facilities': facilities.values.map((f) => f.toJson()).toList(),
  };
  factory ZooLayout.fromJson(Map<String, dynamic> json) {
    final enclosures = (json['enclosures'] as List)
        .map((e) => Enclosure.fromJson(e as Map<String, dynamic>))
        .toList();
    final facilities = (json['facilities'] as List)
        .map((f) => FacilityPlacement.fromJson(f as Map<String, dynamic>))
        .toList();
    if (enclosures.any(
          (e) =>
              e.id.isEmpty ||
              e.width < 3 ||
              e.height < 3 ||
              e.left < 0 ||
              e.top < 0,
        ) ||
        enclosures.map((e) => e.id).toSet().length != enclosures.length ||
        facilities.map((f) => f.facilityId).toSet().length !=
            facilities.length) {
      throw const FormatException('Invalid zoo layout');
    }
    final assignments = Map<String, String>.from(
      json['animalEnclosures'] as Map,
    );
    if (assignments.values.any((id) => !enclosures.any((e) => e.id == id))) {
      throw const FormatException('Unknown enclosure');
    }
    return ZooLayout(
      enclosures: {for (final e in enclosures) e.id: e},
      animalEnclosures: assignments,
      facilities: {for (final f in facilities) f.facilityId: f},
    );
  }
}

enum LayoutEditKind { enclosure, assignAnimal, facility }

/// Coordinates/dimensions only; never an input price or balance.
class LayoutEdit {
  const LayoutEdit({
    required this.kind,
    required this.id,
    this.left = 0,
    this.top = 0,
    this.width = 0,
    this.height = 0,
    this.enclosureId,
  });
  final LayoutEditKind kind;
  final String id;
  final int left, top, width, height;
  final String? enclosureId;
  @override
  bool operator ==(Object other) =>
      other is LayoutEdit &&
      kind == other.kind &&
      id == other.id &&
      left == other.left &&
      top == other.top &&
      width == other.width &&
      height == other.height &&
      enclosureId == other.enclosureId;
  @override
  int get hashCode =>
      Object.hash(kind, id, left, top, width, height, enclosureId);
}
