import 'package:flutter/material.dart';

import 'study_repository.dart';
import 'teacher_assignments_screen.dart';

class StudentAssignmentsScreen extends StatelessWidget {
  const StudentAssignmentsScreen({super.key, required this.store});
  final StudyRepository store;
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('自分の課題')),
    body: Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 700),
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [DemoAssignmentList(store: store)],
        ),
      ),
    ),
  );
}
