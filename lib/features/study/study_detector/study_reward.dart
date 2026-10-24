import 'study_session.dart';

const studyCoinMs = 120000;
const studyDailyCap = 30;
const studyDayOffset = Duration(hours: 9);
String studyDay(DateTime instant) {
  final date = instant.toUtc().add(studyDayOffset);
  return '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
}

Map<String, int> rewardDays(SessionReport report) {
  final totals = <String, int>{};
  final start = report.startedAt.toUtc().millisecondsSinceEpoch;
  for (final interval in report.rewardIntervals) {
    var cursor = start + interval.start.inMilliseconds;
    final end = start + interval.end.inMilliseconds;
    while (cursor < end) {
      final instant = DateTime.fromMillisecondsSinceEpoch(cursor, isUtc: true);
      final jst = instant.add(studyDayOffset);
      final midnight = DateTime.utc(
        jst.year,
        jst.month,
        jst.day + 1,
      ).subtract(studyDayOffset).millisecondsSinceEpoch;
      final until = end < midnight ? end : midnight;
      final day = studyDay(instant);
      totals[day] = (totals[day] ?? 0) + until - cursor;
      cursor = until;
    }
  }
  return totals;
}

int studyCoinsFor(int milliseconds) =>
    (milliseconds ~/ studyCoinMs).clamp(0, studyDailyCap);
int studyDayCapacity(DateTime start, int elapsedMs, String day) {
  if (!RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(day)) return -1;
  final jst = DateTime.tryParse('${day}T00:00:00Z');
  if (jst == null || studyDay(jst.subtract(studyDayOffset)) != day) return -1;
  final left = jst.subtract(studyDayOffset).millisecondsSinceEpoch;
  final right = left + const Duration(days: 1).inMilliseconds;
  final first = start.toUtc().millisecondsSinceEpoch;
  final last = first + elapsedMs;
  final begin = first > left ? first : left;
  final end = last < right ? last : right;
  return end > begin ? end - begin : 0;
}
