import 'dart:math';

import 'zoo_world.dart';

enum AnimalActivity { waiting, walking }

/// Runtime state belongs to an individual, not its species definition.
class AnimalWalker {
  AnimalWalker({
    required this.instanceId,
    required this.definition,
    required this.random,
    MovementArea? area,
  }) : _area = area ?? definition.area {
    position = _randomPoint();
    _waitRemaining = _nextWait();
  }

  final String instanceId;
  final AnimalDefinition definition;
  final Random random;
  MovementArea _area;
  MovementArea get movementArea => _area;
  void setMovementArea(MovementArea area) {
    if (_area.left == area.left &&
        _area.top == area.top &&
        _area.right == area.right &&
        _area.bottom == area.bottom) {
      return;
    }
    _area = area;
    position = Point(
      position.x.clamp(area.left, area.right),
      position.y.clamp(area.top, area.bottom),
    );
    _target = null;
    activity = AnimalActivity.waiting;
    _waitRemaining = _nextWait();
  }

  late Point<double> position;
  Point<double>? _target;
  late double _waitRemaining;
  AnimalActivity activity = AnimalActivity.waiting;

  Point<double> _randomPoint() {
    final area = _area;
    return Point(
      area.left + random.nextDouble() * (area.right - area.left),
      area.top + random.nextDouble() * (area.bottom - area.top),
    );
  }

  double _nextWait() => 0.5 + random.nextDouble() * 2;

  void advance(double seconds) {
    if (!seconds.isFinite || seconds <= 0) return;
    if (activity == AnimalActivity.waiting) {
      _waitRemaining -= seconds;
      if (_waitRemaining <= 0) {
        _target = _randomPoint();
        activity = AnimalActivity.walking;
      }
      return;
    }
    final target = _target!;
    final dx = target.x - position.x;
    final dy = target.y - position.y;
    final distance = sqrt(dx * dx + dy * dy);
    final step = definition.speed * seconds;
    if (distance <= step) {
      position = target;
      activity = AnimalActivity.waiting;
      _waitRemaining = _nextWait();
    } else {
      position = Point(
        position.x + dx / distance * step,
        position.y + dy / distance * step,
      );
    }
  }
}
