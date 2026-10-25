import 'presentation_scenario.dart';

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

class DemoAnswerDialog extends StatefulWidget {
  const DemoAnswerDialog({super.key});
  @override
  State<DemoAnswerDialog> createState() => _DemoAnswerDialogState();
}

class _DemoAnswerDialogState extends State<DemoAnswerDialog> {
  final _answer = TextEditingController(text: PresentationScenario.answer);
  @override
  void dispose() {
    _answer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => PixelUiTheme(
    child: SpriteAlertDialog(
      title: const Text('生徒役：課題に回答'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('今日わかったことを1つ書いて提出しましょう。用意した回答をそのまま使えます。'),
          TextField(
            key: const ValueKey('demo-answer'),
            controller: _answer,
            maxLines: 3,
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('あとで'),
        ),
        ValueListenableBuilder<TextEditingValue>(
          valueListenable: _answer,
          builder: (context, value, _) => FilledButton(
            key: const ValueKey('demo-submit'),
            onPressed: value.text.trim().isEmpty
                ? null
                : () => Navigator.pop(context, value.text.trim()),
            child: const Text('提出する ＋30'),
          ),
        ),
      ],
    ),
  );
}
