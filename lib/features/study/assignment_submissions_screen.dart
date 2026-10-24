import 'package:flutter/material.dart';

import '../game/domain/game_snapshot.dart';
import 'assignment_detail_screen.dart';
import 'study_repository.dart';

class AssignmentSubmissionsScreen extends StatelessWidget {
  const AssignmentSubmissionsScreen({
    super.key,
    required this.store,
    required this.assignmentId,
  });
  final StudyRepository store;
  final String assignmentId;
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('生徒ごとの提出状況')),
    body: ListenableBuilder(
      listenable: store,
      builder: (context, _) => ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Text(
            store.assignmentFor(assignmentId).title,
            style: Theme.of(context).textTheme.titleLarge,
          ),
          for (final student in store.students)
            Builder(
              builder: (context) {
                final submission = store.submissionFor(
                  assignmentId,
                  studentId: student.id,
                );
                return ListTile(
                  title: Text(student.name),
                  subtitle: Text(
                    '${submission?.status.label ?? AssignmentState.notSubmitted.label}${submission == null ? '' : '\n${studyDate(submission.submittedAt)}'}',
                  ),
                  isThreeLine: submission != null,
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => AssignmentDetailScreen(
                        store: store,
                        assignmentId: assignmentId,
                        isTeacher: true,
                        studentId: student.id,
                      ),
                    ),
                  ),
                );
              },
            ),
        ],
      ),
    ),
  );
}
