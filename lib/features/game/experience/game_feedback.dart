import 'package:flutter/services.dart';

/// Cosmetic feedback must never turn a successful purchase into a failed save.
class GameFeedback {
  static Future<void> placementAccepted() async {
    try {
      await HapticFeedback.selectionClick();
    } catch (_) {}
    try {
      await SystemSound.play(SystemSoundType.click);
    } catch (_) {}
  }
}
