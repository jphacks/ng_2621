import 'study_session.dart';

/// Absence of a face is not desk evidence. Require consecutive usable samples.
class AutomaticStudyMode {
  StudyMode? _candidate;
  int _count = 0;
  StudyMode? observe({required bool face, required bool desk}) {
    // When both are visible, prefer the material-based desk observations.
    final next = desk
        ? StudyMode.desk
        : face
        ? StudyMode.face
        : null;
    if (next == null) {
      reset();
      return null;
    }
    if (next != _candidate) {
      _candidate = next;
      _count = 0;
    }
    return ++_count >= 3 ? next : null;
  }

  void reset() {
    _candidate = null;
    _count = 0;
  }
}
