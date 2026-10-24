import 'package:flutter/material.dart';

/// Student learning entry points, independent of the zoo screen layout.
class StudentLearningMenu extends StatelessWidget {
  const StudentLearningMenu({
    super.key,
    required this.onAssignments,
    required this.onStudyMode,
    required this.onRecords,
  });

  final VoidCallback onAssignments, onStudyMode, onRecords;

  @override
  Widget build(BuildContext context) => Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      ListTile(
        leading: const Icon(Icons.assignment_outlined),
        title: const Text('課題提出'),
        subtitle: const Text('課題を確認して、回答や画像・PDFを提出する'),
        trailing: const Icon(Icons.chevron_right),
        onTap: onAssignments,
      ),
      const Divider(),
      ListTile(
        onTap: onStudyMode,
        leading: const Icon(Icons.timer_outlined),
        title: const Text('勉強モード'),
        subtitle: const Text('自習に取り組む'),
        trailing: const Icon(Icons.chevron_right),
      ),
      const Divider(),
      ListTile(
        onTap: onRecords,
        leading: const Icon(Icons.insights_outlined),
        title: const Text('学習記録'),
        subtitle: const Text('これまでの学習を振り返る'),
        trailing: const Icon(Icons.chevron_right),
      ),
    ],
  );
}
