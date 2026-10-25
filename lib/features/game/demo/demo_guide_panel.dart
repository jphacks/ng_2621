import 'package:flutter/material.dart';

import '../../../core/ui/zoo_ui.dart';
import 'demo_tutorial_controller.dart';

class DemoGuidePanel extends StatefulWidget {
  const DemoGuidePanel({
    super.key,
    required this.controller,
    required this.onAction,
    required this.onRestart,
    this.ready = true,
    this.busy = false,
  });
  final DemoTutorialController controller;
  final VoidCallback onAction, onRestart;
  final bool ready, busy;
  @override
  State<DemoGuidePanel> createState() => _DemoGuidePanelState();
}

class _DemoGuidePanelState extends State<DemoGuidePanel> {
  bool _collapsed = false;
  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: widget.controller,
    builder: (context, _) {
      final tour = widget.controller;
      return SpritePanel(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      '発表デモ ${tour.step == DemoStep.complete ? "完成イメージ" : "${tour.step.index + 1}/12"}',
                      style: const TextStyle(fontSize: 11),
                    ),
                  ),
                  IconButton(
                    tooltip: _collapsed ? '案内を広げる' : '案内をたたむ',
                    onPressed: () => setState(() => _collapsed = !_collapsed),
                    icon: Icon(
                      _collapsed ? Icons.expand_more : Icons.expand_less,
                    ),
                    visualDensity: VisualDensity.compact,
                  ),
                  TextButton(
                    key: const ValueKey('demo-restart'),
                    onPressed: widget.onRestart,
                    style: PixelUiTheme.legacyButtonStyle(
                      SpritePanelStyle.gray,
                    ),
                    child: const Text('はじめから', style: TextStyle(fontSize: 11)),
                  ),
                  if (Navigator.of(context).canPop())
                    IconButton(
                      tooltip: '発表デモを終了',
                      onPressed: () => Navigator.maybePop(context),
                      icon: const ZooUiSprite(part: ZooUiPart.cross, scale: 1),
                    ),
                ],
              ),
              if (!_collapsed) ...[
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        tour.title,
                        key: const ValueKey('demo-step-title'),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    FilledButton(
                      key: const ValueKey('demo-next'),
                      onPressed: widget.ready && !widget.busy
                          ? widget.onAction
                          : null,
                      child: Text(
                        widget.busy
                            ? '処理中…'
                            : widget.ready
                            ? tour.actionLabel
                            : '準備中…',
                        style: const TextStyle(fontSize: 12),
                      ),
                    ),
                    IconButton(
                      tooltip: 'この手順の説明',
                      onPressed: () => showDialog<void>(
                        context: context,
                        builder: (context) => PixelUiTheme(
                          child: SpriteAlertDialog(
                            title: Text(tour.title),
                            content: Text(tour.explanation),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(context),
                                child: const Text('わかりました'),
                              ),
                            ],
                          ),
                        ),
                      ),
                      icon: const Text('？'),
                    ),
                  ],
                ),
                const SizedBox(height: 3),
                LinearProgressIndicator(
                  value: tour.step.index / 12,
                  minHeight: 3,
                ),
              ],
            ],
          ),
        ),
      );
    },
  );
}

class DemoAnswerDialog extends StatefulWidget {
  const DemoAnswerDialog({super.key});
  @override
  State<DemoAnswerDialog> createState() => _DemoAnswerDialogState();
}

class _DemoAnswerDialogState extends State<DemoAnswerDialog> {
  final _answer = TextEditingController(text: '今日は分数の計算を学びました。');
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
