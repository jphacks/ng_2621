class StudyAdvice {
  const StudyAdvice({
    required this.id,
    required this.studentId,
    required this.createdAt,
    required this.summary,
    required this.teacherNote,
    required this.message,
    required this.source,
    this.publishedAt,
  });
  final String id, studentId, summary, teacherNote, message, source;
  final DateTime createdAt;
  final DateTime? publishedAt;
  bool get published => publishedAt != null;
  Map<String, dynamic> toJson() => {
    'id': id,
    'studentId': studentId,
    'createdAt': createdAt.toUtc().toIso8601String(),
    'summary': summary,
    'teacherNote': teacherNote,
    'message': message,
    'source': source,
    'publishedAt': publishedAt?.toUtc().toIso8601String(),
  };
  factory StudyAdvice.fromJson(Map<String, dynamic> j) => StudyAdvice(
    id: j['id'] as String,
    studentId: j['studentId'] as String,
    createdAt: DateTime.parse(j['createdAt'] as String),
    summary: j['summary'] as String,
    teacherNote: j['teacherNote'] as String,
    message: j['message'] as String,
    source: j['source'] as String,
    publishedAt: j['publishedAt'] == null
        ? null
        : DateTime.parse(j['publishedAt'] as String),
  );
}
