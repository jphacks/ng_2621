import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../core/ui/zoo_ui.dart';
import '../../zoo/domain/zoo_world.dart';
import 'animal_art.dart';

/// Fixed pages; catalog order determines numbering, independent of ownership.
class AnimalEncyclopedia extends StatefulWidget {
  const AnimalEncyclopedia({
    super.key,
    required this.animals,
    required this.ownedIds,
    required this.onSelect,
    this.onChooseGoal,
  });
  final VoidCallback? onChooseGoal;
  final List<AnimalDefinition> animals;
  final Set<String> ownedIds;
  final ValueChanged<AnimalDefinition> onSelect;

  @override
  State<AnimalEncyclopedia> createState() => _AnimalEncyclopediaState();
}

class _AnimalEncyclopediaState extends State<AnimalEncyclopedia> {
  int _page = 0;

  @override
  Widget build(BuildContext context) => PixelUiTheme(
    child: Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(16),
      child: SizedBox(
        width: 620,
        height: MediaQuery.sizeOf(context).height * .85,
        child: SpritePanel(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                Row(
                  children: [
                    const Expanded(
                      child: WoodPanel(
                        child: Padding(
                          padding: EdgeInsets.all(8),
                          child: Text('動物一覧', style: TextStyle(fontSize: 20)),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    if (widget.onChooseGoal != null)
                      IconButton(
                        tooltip: '目標の動物を選ぶ',
                        onPressed: widget.onChooseGoal,
                        icon: const ZooUiSprite(
                          part: ZooUiPart.check,
                          scale: 2,
                        ),
                      ),
                    IconButton(
                      tooltip: '閉じる',
                      onPressed: () => Navigator.pop(context),
                      icon: const ZooUiSprite(part: ZooUiPart.cross, scale: 2),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Expanded(
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      // Fit square cells in both portrait and landscape; never scroll.
                      const gap = 12.0;
                      final gridHeight = math.max(
                        1.0,
                        constraints.maxHeight - 64,
                      );
                      final side = math.max(
                        1.0,
                        math.min(
                          104.0,
                          math.min(
                            (constraints.maxWidth - gap) / 2,
                            gridHeight,
                          ),
                        ),
                      );
                      final columns = math.max(
                        1,
                        math.min(
                          4,
                          ((constraints.maxWidth + gap) / (side + gap)).floor(),
                        ),
                      );
                      final rows = math.max(
                        1,
                        math.min(
                          3,
                          ((gridHeight + gap) / (side + gap)).floor(),
                        ),
                      );
                      final perPage = columns * rows;
                      final pages = math.max(
                        1,
                        (widget.animals.length / perPage).ceil(),
                      );
                      final page = math.min(_page, pages - 1);
                      final start = page * perPage;
                      return Column(
                        children: [
                          Expanded(
                            child: Center(
                              child: SizedBox(
                                width: columns * side + (columns - 1) * gap,
                                child: Wrap(
                                  spacing: gap,
                                  runSpacing: gap,
                                  children: [
                                    for (
                                      var index = start;
                                      index <
                                          math.min(
                                            start + perPage,
                                            widget.animals.length,
                                          );
                                      index++
                                    )
                                      SizedBox.square(
                                        dimension: side,
                                        child: _entry(
                                          widget.animals[index],
                                          index + 1,
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          if (widget.animals.isEmpty)
                            const Text('登録された動物はいません'),
                          // Controls are outside the grid and remain visible on every page.
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              IconButton(
                                tooltip: '前のページ',
                                onPressed: page > 0
                                    ? () => setState(() => _page = page - 1)
                                    : null,
                                icon: const ZooUiSprite(
                                  part: ZooUiPart.arrowLeft,
                                  scale: 2,
                                ),
                              ),
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                ),
                                child: Text('${page + 1} / $pages'),
                              ),
                              IconButton(
                                tooltip: '次のページ',
                                onPressed: page + 1 < pages
                                    ? () => setState(() => _page = page + 1)
                                    : null,
                                icon: const ZooUiSprite(
                                  part: ZooUiPart.arrowRight,
                                  scale: 2,
                                ),
                              ),
                            ],
                          ),
                        ],
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );

  Widget _entry(AnimalDefinition animal, int number) {
    final owned = widget.ownedIds.contains(animal.id);
    return Semantics(
      label:
          'No.${number.toString().padLeft(2, '0')} ${animal.name}${owned ? '' : ' 未所持'}',
      button: true,
      enabled: owned,
      child: ColorActionPanel(
        enabled: owned,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            key: ValueKey('encyclopedia-${animal.id}'),
            onTap: owned ? () => widget.onSelect(animal) : null,
            child: Stack(
              children: [
                Center(child: AnimalArt(animalId: animal.id, size: 48)),
                Positioned(
                  left: 6,
                  top: 6,
                  child: Text(
                    'No.${number.toString().padLeft(2, '0')}',
                    style: const TextStyle(fontSize: 12),
                  ),
                ),
                if (!owned)
                  const Center(
                    child: ZooUiSprite(part: ZooUiPart.lock, scale: 3),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
