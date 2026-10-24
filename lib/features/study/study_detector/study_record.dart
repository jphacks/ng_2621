import 'study_session.dart';

/// Aggregate observations only; never pixels, OCR text or face landmarks.
class StudyRecord {
  const StudyRecord({
    required this.id,
    required this.startedAt,
    required this.mode,
    required this.elapsedMs,
    required this.stateMs,
    required this.samples,
    required this.subject,
    required this.completed,
    this.studentId = 'demo_student',
    this.studentName = 'デモ生徒',
  });
  final String id, subject, studentId, studentName;
  final DateTime startedAt;
  final StudyMode mode;
  final int elapsedMs, samples;
  final Map<String, int> stateMs;
  final bool completed;
  int get suspendedMs => stateMs[StudyState.suspended.name] ?? 0;
  int get activeMs => elapsedMs - suspendedMs;
  DateTime get endedAt => startedAt.add(Duration(milliseconds: elapsedMs));
  factory StudyRecord.fromReport(
    String id,
    SessionReport report, {
    required String subject,
    required int samples,
    required bool completed,
  }) {
    final totals = {
      for (final state in StudyState.values)
        state.name: report.total(state).inMilliseconds,
    };
    // Integer conversion can lose a fraction of a millisecond in each bucket.
    totals[StudyState.unknown.name] =
        totals[StudyState.unknown.name]! +
        report.elapsed.inMilliseconds -
        totals.values.fold(0, (a, b) => a + b);
    return StudyRecord(
      id: id,
      startedAt: report.startedAt,
      mode: report.mode,
      elapsedMs: report.elapsed.inMilliseconds,
      samples: samples,
      subject: subject,
      completed: completed,
      stateMs: Map.unmodifiable(totals),
    );
  }
  Map<String, dynamic> toJson() => {
    'id': id,
    'startedAt': startedAt.toUtc().toIso8601String(),
    'mode': mode.name,
    'elapsedMs': elapsedMs,
    'stateMs': stateMs,
    'samples': samples,
    'subject': subject,
    'completed': completed,
    'studentId': studentId,
    'studentName': studentName,
    'detectorVersion': 'study-detector-v1',
  };
  factory StudyRecord.fromJson(Map<String, dynamic> json) {
    final result = StudyRecord(
      id: json['id'] as String,
      startedAt: DateTime.parse(json['startedAt'] as String),
      mode: StudyMode.values.byName(json['mode'] as String),
      elapsedMs: json['elapsedMs'] as int,
      samples: json['samples'] as int,
      subject: json['subject'] as String,
      completed: json['completed'] as bool,
      studentId: json['studentId'] as String? ?? 'demo_student',
      studentName: json['studentName'] as String? ?? 'デモ生徒',
      stateMs: Map<String, dynamic>.from(json['stateMs'] as Map)
          .map((k, v) => MapEntry(k, v as int)),
    );
    result.validate();
    return result;
  }
  void validate() {
    if (!RegExp(r'^[A-Za-z0-9_-]{1,180}$').hasMatch(id) ||
        elapsedMs < 0 ||
        elapsedMs > const Duration(hours: 24).inMilliseconds ||
        samples < 0 ||
        samples > 100000 ||
        subject.length > 100 ||
        stateMs.length != StudyState.values.length ||
        StudyState.values.any((s) => (stateMs[s.name] ?? -1) < 0) ||
        stateMs.values.fold(0, (a, b) => a + b) != elapsedMs) {
      throw const FormatException('学習記録の内容が無効です');
    }
  }
}
