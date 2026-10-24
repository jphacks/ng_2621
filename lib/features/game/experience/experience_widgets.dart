import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../core/ui/zoo_ui.dart';
import '../../animals/presentation/animal_art.dart';
import '../../shop/domain/shop_catalog.dart';
import '../domain/game_snapshot.dart';
import 'game_experience.dart';

String unlockDescription(
  ShopItem item,
  ShopCatalog catalog,
  GameSnapshot? state,
) {
  final names = [
    for (final id in item.requiredAnimalIds)
      catalog.items.where((i) => i.targetId == id).firstOrNull?.name ?? id,
  ];
  final parts = <String>[
    if (names.isNotEmpty) '${names.join('・')}を所持',
    if (item.minimumAnimalSpecies > 0) '動物${item.minimumAnimalSpecies}種類を所持',
  ];
  return parts.isEmpty
      ? '解放条件なし'
      : '${parts.join('、')}（${state != null && item.isUnlocked(state) ? '達成' : '未達成'}）';
}

class GoalBanner extends StatelessWidget {
  const GoalBanner({
    super.key,
    required this.item,
    required this.catalog,
    required this.state,
    required this.onChange,
    required this.onShop,
  });
  final ShopItem item;
  final ShopCatalog catalog;
  final GameSnapshot state;
  final VoidCallback onChange, onShop;
  @override
  Widget build(BuildContext context) => SpritePanel(
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: Row(
        children: [
          AnimalArt(animalId: item.targetId, size: 32),
          const SizedBox(width: 8),
          Expanded(
            child: InkWell(
              onTap: onChange,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '目標：${item.name}',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  Text(
                    item.isOwned(state)
                        ? '目標達成！動物を迎えました'
                        : 'あと${math.max(0, item.price - state.coins)}コイン',
                    key: const ValueKey('goal-progress'),
                  ),
                  if (!item.isUnlocked(state))
                    Text(
                      unlockDescription(item, catalog, state),
                      style: const TextStyle(fontSize: 12),
                    ),
                ],
              ),
            ),
          ),
          IconButton(
            tooltip: '目標の商品を見る',
            onPressed: onShop,
            icon: const ZooArtSprite(part: ZooArtPart.shop, scale: 2),
          ),
        ],
      ),
    ),
  );
}

/// Animation does not call a repository or adjust a displayed coin balance.
class RewardCelebration extends StatelessWidget {
  const RewardCelebration({
    super.key,
    required this.reward,
    required this.onClose,
    required this.onShop,
  });
  final ConfirmedGameReward reward;
  final VoidCallback onClose, onShop;
  @override
  Widget build(BuildContext context) => Stack(
    children: [
      Positioned.fill(
        child: IgnorePointer(
          child: LayoutBuilder(
            builder: (context, c) => TweenAnimationBuilder<double>(
              key: ValueKey(reward.transactionId),
              tween: Tween(begin: 0, end: 1),
              duration: MediaQuery.disableAnimationsOf(context)
                  ? Duration.zero
                  : const Duration(milliseconds: 900),
              builder: (context, value, _) => value >= 1
                  ? const SizedBox.shrink()
                  : Align(
                      alignment: Alignment(value * .8, -value),
                      child: const ZooArtSprite(
                        part: ZooArtPart.coins,
                        scale: 4,
                      ),
                    ),
            ),
          ),
        ),
      ),
      Align(
        alignment: Alignment.bottomCenter,
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 84),
            child: SpritePanel(
              style: SpritePanelStyle.creamRound,
              child: Material(
                color: Colors.transparent,
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Semantics(
                    liveRegion: true,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '${reward.source}のごほうび +${reward.amount}コイン',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        const Text('確定した報酬が動物園に届きました！'),
                        Wrap(
                          spacing: 8,
                          children: [
                            OutlinedButton(
                              onPressed: onClose,
                              child: const Text('閉じる'),
                            ),
                            FilledButton(
                              onPressed: onShop,
                              child: const Text('ごほうびでショップへ'),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    ],
  );
}

class AnimalReaction extends StatelessWidget {
  const AnimalReaction({
    super.key,
    required this.child,
    required this.revision,
  });
  final Widget child;
  final int revision;
  @override
  Widget build(BuildContext context) {
    if (revision == 0 || MediaQuery.disableAnimationsOf(context)) return child;
    return TweenAnimationBuilder<double>(
      key: ValueKey(revision),
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 600),
      builder: (context, value, child) => Transform.translate(
        offset: Offset(0, -math.sin(value * math.pi).abs() * 5),
        child: child,
      ),
      child: child,
    );
  }
}
