import 'package:flutter/material.dart';

import '../../../core/ui/zoo_ui.dart';
import '../../zoo/presentation/zoo_controller.dart';
import '../../zoo/presentation/zoo_map.dart';

/// A clearly labelled prepared finale, keeping the real game shell mounted below.
class DemoFinale extends StatelessWidget {
  const DemoFinale({
    super.key,
    required this.controller,
    required this.onRestart,
    required this.onExplore,
  });
  final ZooController controller;
  final VoidCallback onRestart, onExplore;
  @override
  Widget build(BuildContext context) => BlockSemantics(
    child: Material(
      color: const Color(0xFFE4ECD9),
      child: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Column(
                children: [
                  const WoodPanel(
                    child: Padding(
                      padding: EdgeInsets.all(12),
                      child: Text(
                        '学びが、動物園を育てる。',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '${controller.animals.length}種類の仲間が暮らす動物園',
                    style: const TextStyle(fontSize: 16),
                  ),
                  const Text('デモ用に配置した完成イメージ', style: TextStyle(fontSize: 11)),
                ],
              ),
            ),
            Expanded(
              child: ClipRect(
                child: InteractiveViewer(
                  minScale: 1,
                  maxScale: 4,
                  boundaryMargin: const EdgeInsets.all(120),
                  child: SizedBox.expand(child: ZooMap(controller: controller)),
                ),
              ),
            ),
            const Text('ピンチで拡大・ドラッグで移動', style: TextStyle(fontSize: 11)),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Wrap(
                spacing: 12,
                runSpacing: 8,
                alignment: WrapAlignment.center,
                children: [
                  FilledButton(
                    key: const ValueKey('demo-finale-restart'),
                    onPressed: onRestart,
                    child: const Text('もう一度体験する'),
                  ),
                  TextButton(
                    key: const ValueKey('demo-finale-explore'),
                    onPressed: onExplore,
                    child: const Text('自由に見てみる'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
