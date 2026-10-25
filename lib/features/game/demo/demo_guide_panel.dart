import 'package:flutter/material.dart';

import '../../../core/ui/zoo_ui.dart';
import 'demo_tutorial_controller.dart';

class DemoGuidePanel extends StatelessWidget {
  const DemoGuidePanel({
    super.key,
    required this.controller,
    required this.onAction,
    this.ready = true,
    this.busy = false,
    this.instruction,
    this.notice,
  });
  final DemoTutorialController controller;
  final VoidCallback onAction;
  final bool ready, busy;
  final String? instruction, notice;
  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: controller,
    builder: (context, _) => WoodPanel(
      originalSheet: true,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '発表デモ ${controller.step == DemoStep.complete ? "完成イメージ" : "${controller.step.index + 1}/${DemoStep.complete.index}"}',
              style: const TextStyle(fontSize: 10),
            ),
            Text(
              notice ?? controller.title,
              key: const ValueKey('demo-step-title'),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
            ),
            Text(
              instruction ?? controller.explanation,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 11),
            ),
            if (controller.isDirectAction)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: FilledButton(
                  key: const ValueKey('demo-next'),
                  onPressed: ready && !busy ? onAction : null,
                  child: Text(
                    busy
                        ? '処理中…'
                        : ready
                        ? controller.actionLabel
                        : '準備中…',
                    style: const TextStyle(fontSize: 12),
                  ),
                ),
              ),
          ],
        ),
      ),
    ),
  );
}
