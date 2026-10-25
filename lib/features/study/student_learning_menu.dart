import '../../core/ui/zoo_ui.dart';

import 'package:flutter/material.dart';

/// Student learning entry points, independent of the zoo screen layout.
class StudentLearningMenu extends StatelessWidget {
  const StudentLearningMenu({
    super.key,
    required this.onAssignments,
    this.highlightAssignments = false,
    required this.onStudyMode,
    required this.onRecords,
  });

  final VoidCallback onAssignments, onStudyMode, onRecords;
  final bool highlightAssignments;

  @override
  Widget build(BuildContext context) => Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      SpriteTile(
        highlighted: highlightAssignments,
        panelStyle: SpritePanelStyle.cream,
        leading: const ZooArtSprite(part: ZooArtPart.bookAndPen, scale: 2),
        title: const Text('課題提出'),
        subtitle: const Text('課題を確認して、回答や画像・PDFを提出する'),
        trailing: const ZooUiSprite(part: ZooUiPart.arrowRight, scale: 2),
        onTap: onAssignments,
      ),
      const SizedBox(height: 4),
      SpriteTile(
        panelStyle: SpritePanelStyle.cream,
        onTap: onStudyMode,
        leading: const Icon(Icons.timer_outlined),
        title: const Text('勉強モード'),
        subtitle: const Text('自習に取り組む'),
        trailing: const ZooUiSprite(part: ZooUiPart.arrowRight, scale: 2),
      ),
      const SizedBox(height: 4),
      SpriteTile(
        panelStyle: SpritePanelStyle.cream,
        onTap: onRecords,
        leading: const Icon(Icons.insights_outlined),
        title: const Text('学習記録'),
        subtitle: const Text('これまでの学習を振り返る'),
        trailing: const ZooUiSprite(part: ZooUiPart.arrowRight, scale: 2),
      ),
    ],
  );
}
