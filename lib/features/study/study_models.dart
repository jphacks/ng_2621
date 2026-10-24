import '../game/domain/game_snapshot.dart';

enum AssignmentSubject {
  japanese('国語'),
  mathematics('算数・数学'),
  english('英語'),
  science('理科'),
  socialStudies('社会'),
  other('その他');

  const AssignmentSubject(this.label);
  final String label;
}

enum DemoStudyRole { teacher, student }

class StudyFailure implements Exception {
  const StudyFailure(this.message, {this.code});
  final String message;
  final String? code;
}

class DemoAssignment {
  const DemoAssignment({
    this.id = '',
    required this.subject,
    required this.title,
    required this.description,
    required this.dueAt,
  });
  final String id;
  final AssignmentSubject subject;
  final String title;
  final String description;
  final DateTime dueAt;
}

class DemoSubmission {
  const DemoSubmission({
    required this.assignmentId,
    required this.answerText,
    required this.status,
    required this.submittedAt,
    required this.updatedAt,
    this.reviewedAt,
    this.feedback = '',
    this.revisionCount = 0,
    this.studentId = 'demo_student',
    this.studentName = 'デモ生徒',
    this.version = 0,
  });
  final String assignmentId;
  String get id => '${assignmentId}_$studentId';
  final String studentId;
  final String studentName;
  final int version;
  final String answerText;
  final AssignmentState status;
  final DateTime submittedAt;
  final DateTime updatedAt;
  final DateTime? reviewedAt;
  final String feedback;
  final int revisionCount;
}

class StudyStudent {
  const StudyStudent(this.id, this.name);
  final String id;
  final String name;
}
