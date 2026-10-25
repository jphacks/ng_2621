import 'package:flutter/material.dart';

import '../../../core/storage/draft_storage.dart';
import '../../study/demo_assignment_store.dart';
import '../../study/study_repository.dart';
import '../../study/teacher_assignments_screen.dart';
import 'presentation_scenario.dart';

/// Reuses the production teacher UI. Only its data source is a disposable script.
class TeacherDemoScreen extends StatefulWidget {
  const TeacherDemoScreen({super.key});
  @override
  State<TeacherDemoScreen> createState() => _TeacherDemoScreenState();
}

class _TeacherDemoScreenState extends State<TeacherDemoScreen> {
  late final _store = TeacherPresentationStore();
  @override
  void dispose() {
    _store.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => TeacherAssignmentsScreen(store: _store);
}

/// Local fixtures let the existing detail and advice screens work without a server.
class TeacherPresentationStore extends DemoAssignmentStore {
  TeacherPresentationStore()
    : super(studentId: 'presentation_student', studentName: 'デモ生徒');
  final _drafts = _PresentationDrafts();
  @override
  DraftStorage get drafts => _drafts;
  @override
  String get storageLabel => '発表デモ・保存しません';
  @override
  String get storageExplanation => '別端末とは通信しません。提出には生徒の回答例を使用します。';
  @override
  void publish(
    DemoAssignment assignment, {
    DemoStudyRole role = DemoStudyRole.teacher,
  }) {
    super.publish(assignment, role: role);
    if (submissionFor(assignment.id) == null) {
      super.submit(
        assignment.id,
        PresentationScenario.answer,
        role: DemoStudyRole.student,
      );
    }
  }

  @override
  Future<StudyAdvice> generateStudyAdvice(String studentId) async {
    final draft = await super.generateStudyAdvice(studentId);
    return StudyAdvice(
      id: draft.id,
      studentId: draft.studentId,
      createdAt: draft.createdAt,
      summary: draft.summary,
      teacherNote: draft.teacherNote,
      message: PresentationScenario.advice,
      source: draft.source,
    );
  }
}

/// Prefills the existing assignment form through its existing draft interface.
class _PresentationDrafts implements DraftStorage {
  final _values = <String, Map<String, dynamic>>{
    'new-assignment': {
      'title': PresentationScenario.title,
      'description': PresentationScenario.description,
      'subject': AssignmentSubject.other.name,
      'dueAt': PresentationScenario.assignment().dueAt.toIso8601String(),
      'requestId': PresentationScenario.assignmentId,
    },
  };
  @override
  Future<Map<String, dynamic>?> read(String key) async =>
      _values[key] == null ? null : Map.of(_values[key]!);
  @override
  Future<void> write(String key, Map<String, dynamic> value) async {
    _values[key] = Map.of(value);
  }

  @override
  Future<void> remove(String key) async {
    _values.remove(key);
  }
}
