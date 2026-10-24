import 'package:flutter/material.dart';

import '../../../core/ui/zoo_ui.dart';
import 'zoo_chrome.dart';
import 'zoo_controller.dart';
import 'zoo_map.dart';
import '../domain/zoo_world.dart';

class ZooViewport extends StatefulWidget {
  const ZooViewport({
    super.key,
    required this.controller,
    required this.onAnimals,
    this.onAnimalSelected,
    this.onShop,
  });

  final ZooController controller;
  final VoidCallback onAnimals;
  final VoidCallback? onShop;
  final ValueChanged<AnimalDefinition>? onAnimalSelected;

  @override
  State<ZooViewport> createState() => ZooViewportState();
}

class ZooViewportState extends State<ZooViewport> {
  final _camera = TransformationController();
  Size _size = Size.zero;
  bool _hasInteracted = false;

  void resetView() {
    _camera.value = Matrix4.identity();
  }

  void _zoom(double factor) {
    final previous = _camera.value.getMaxScaleOnAxis();
    final next = (previous * factor).clamp(1.0, 4.0);
    if (next == previous) return;
    final center = _size.center(Offset.zero);
    final transform = Matrix4.translationValues(center.dx, center.dy, 0)
      ..multiply(Matrix4.diagonal3Values(next / previous, next / previous, 1))
      ..multiply(Matrix4.translationValues(-center.dx, -center.dy, 0))
      ..multiply(_camera.value);
    _camera.value = transform;
    if (!_hasInteracted) setState(() => _hasInteracted = true);
  }

  @override
  void dispose() {
    _camera.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        _size = constraints.biggest;
        return ColoredBox(
          color: const Color(0xFFE4ECD9),
          child: Stack(
            children: [
              Positioned.fill(
                child: Semantics(
                  label: '動物園マップ。ドラッグで移動、ピンチで拡大できます',
                  child: InteractiveViewer(
                    transformationController: _camera,
                    minScale: 1,
                    maxScale: 4,
                    boundaryMargin: const EdgeInsets.all(120),
                    onInteractionStart: (_) {
                      if (!_hasInteracted) {
                        setState(() => _hasInteracted = true);
                      }
                    },
                    child: SizedBox.expand(
                      child: ZooMap(
                        controller: widget.controller,
                        onAnimalSelected: widget.onAnimalSelected,
                      ),
                    ),
                  ),
                ),
              ),
              Positioned(
                top: 12,
                left: 16,
                right: 12,
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'マイ動物園',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              color: zooInk,
                            ),
                          ),
                          SizedBox(height: 2),
                          Text(
                            widget.controller.animals.isEmpty
                                ? 'ここから動物園を育てよう'
                                : 'タップで動物の詳細',
                            style: TextStyle(fontSize: 11, color: zooGreen),
                          ),
                        ],
                      ),
                    ),
                    Tooltip(
                      message: '動物一覧',
                      child: Material(
                        color: Colors.transparent,
                        borderRadius: BorderRadius.circular(14),
                        child: InkWell(
                          onTap: widget.onAnimals,
                          borderRadius: BorderRadius.circular(14),
                          child: WoodPanel(
                            child: Padding(
                              padding: const EdgeInsets.all(10),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const ZooUiSprite(
                                    part: ZooUiPart.encyclopediaRed,
                                    scale: 3,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    '${widget.controller.animals.length}匹',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: zooInk,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              if (widget.controller.animals.isEmpty &&
                  widget.onShop != null &&
                  constraints.maxHeight >= 380)
                Positioned(
                  left: 16,
                  bottom: 16,
                  right: 76,
                  child: Card(
                    elevation: 0,
                    color: zooPaper,
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            '最初の仲間を迎えよう',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: zooInk,
                            ),
                          ),
                          const SizedBox(height: 4),
                          const Text(
                            '課題でコインを集めて、ショップへ。',
                            style: TextStyle(fontSize: 12, color: zooGreen),
                          ),
                          const SizedBox(height: 8),
                          OutlinedButton.icon(
                            onPressed: widget.onShop,
                            style: OutlinedButton.styleFrom(
                              foregroundColor: zooGreen,
                              side: const BorderSide(color: zooGreen),
                            ),
                            icon: const ZooArtSprite(
                              part: ZooArtPart.shop,
                              scale: 1,
                            ),
                            label: const Text('ショップへ'),
                          ),
                        ],
                      ),
                    ),
                  ),
                )
              else if (!_hasInteracted && constraints.maxHeight >= 280)
                const Positioned(
                  left: 16,
                  bottom: 18,
                  right: 76,
                  child: IgnorePointer(
                    child: Text(
                      'ドラッグで移動\nピンチで拡大',
                      style: TextStyle(
                        fontSize: 11,
                        color: zooGreen,
                        height: 1.6,
                      ),
                    ),
                  ),
                ),
              Positioned(
                right: 12,
                bottom: 12,
                child: Wrap(
                  direction: constraints.maxHeight < 240
                      ? Axis.horizontal
                      : Axis.vertical,
                  spacing: 4,
                  children: [
                    ValueListenableBuilder<Matrix4>(
                      valueListenable: _camera,
                      builder: (context, matrix, child) => Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: zooPaper,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          '${matrix.getMaxScaleOnAxis().toStringAsFixed(1)}×',
                          key: const ValueKey('zoo-zoom-level'),
                          style: const TextStyle(fontSize: 11, color: zooGreen),
                        ),
                      ),
                    ),
                    _MapButton(
                      label: '拡大',
                      onPressed: () => _zoom(2),
                      part: ZooUiPart.plus,
                    ),
                    _MapButton(
                      label: '縮小',
                      onPressed: () => _zoom(0.5),
                      part: ZooUiPart.minus,
                    ),
                    _MapButton(
                      label: '全体を表示',
                      onPressed: resetView,
                      icon: Icons.center_focus_strong_rounded,
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _MapButton extends StatelessWidget {
  const _MapButton({
    required this.label,
    required this.onPressed,
    this.part,
    this.icon,
  });

  final String label;
  final VoidCallback onPressed;
  final ZooUiPart? part;
  final IconData? icon;

  @override
  Widget build(BuildContext context) => Material(
    color: zooPaper,
    borderRadius: BorderRadius.circular(12),
    child: IconButton(
      tooltip: label,
      onPressed: onPressed,
      style: IconButton.styleFrom(minimumSize: const Size(48, 48)),
      icon: part != null
          ? ZooUiSprite(part: part!, scale: 2)
          : Icon(icon, size: 22, color: zooGreen),
    ),
  );
}
