import 'package:flutter/material.dart';

import '../../game/presentation/game_session.dart';
import '../domain/shop_catalog.dart';
import '../domain/shop_repository.dart';
import 'shop_purchase_controller.dart';
import '../../../core/ui/zoo_ui.dart';
import 'shop_item_art.dart';

class ShopPanel extends StatefulWidget {
  const ShopPanel({
    super.key,
    required this.session,
    required this.purchases,
    required this.item,
    required this.catalog,
    this.onViewZoo,
    this.onPlaceFacility,
    this.onCreateEnclosure,
  });
  final GameSession session;
  final ShopPurchaseController purchases;
  final ShopItem item;
  final ShopCatalog catalog;
  final VoidCallback? onViewZoo;
  final VoidCallback? onPlaceFacility;
  final VoidCallback? onCreateEnclosure;
  @override
  State<ShopPanel> createState() => _ShopPanelState();
}

class _ShopPanelState extends State<ShopPanel> {
  late final ShopPurchaseController _purchases;
  bool _confirming = false;
  PurchaseStatus? _presentedStatus;
  bool _revealScheduled = false;
  final _feedbackAnchor = GlobalKey();

  @override
  void initState() {
    super.initState();
    _purchases = widget.purchases;
    _purchases.addListener(_revealFeedback);
    _revealFeedback();
  }

  void _revealFeedback() {
    if (_purchases.item?.id != widget.item.id ||
        _presentedStatus == _purchases.status) {
      return;
    }
    _presentedStatus = _purchases.status;
    if (_revealScheduled || _purchases.status == PurchaseStatus.idle) return;
    _revealScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _revealScheduled = false;
      if (!mounted) return;
      final target = _feedbackAnchor.currentContext;
      if (target == null) return;
      Scrollable.ensureVisible(
        target,
        duration: MediaQuery.disableAnimationsOf(context)
            ? Duration.zero
            : const Duration(milliseconds: 220),
      );
    });
  }

  Future<void> _confirmAndBuy(ShopItem item) async {
    if (_confirming ||
        _purchases.busy ||
        _purchases.uncertain ||
        _purchases.awaitingSnapshot) {
      return;
    }
    setState(() => _confirming = true);
    final coins = widget.session.snapshot?.coins;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => PixelUiTheme(
        child: SpriteAlertDialog(
          title: Text('${item.name}を${item.isResearch ? '進化で解放' : '購入'}しますか？'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('${item.price} コインを使います。'),
              if (coins != null) ...[
                const SizedBox(height: 12),
                Text('現在 $coins コイン'),
                Text('購入後 ${coins - item.price} コイン（見込み）'),
              ],
              const SizedBox(height: 12),
              Text(
                item.kind == ShopItemKind.animal
                    ? '購入後、動物一覧から囲いに配置してください。'
                    : '購入後、動物園で配置・移動できます。',
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('やめる'),
            ),
            FilledButton(
              key: const ValueKey('confirm-purchase'),
              onPressed: () => Navigator.pop(context, true),
              child: Text(item.isResearch ? '進化を確定' : '購入を確定'),
            ),
          ],
        ),
      ),
    );
    if (!mounted) return;
    setState(() => _confirming = false);
    if (confirmed == true) await _purchases.buy(item);
  }

  @override
  void dispose() {
    _purchases.removeListener(_revealFeedback);
    super.dispose();
  }

  Widget _feedback() {
    if (_purchases.status == PurchaseStatus.idle ||
        _purchases.item?.id != widget.item.id) {
      return const SizedBox.shrink();
    }
    final success = _purchases.status == PurchaseStatus.success;
    return Semantics(
      liveRegion: true,
      child: SpritePanel(
        style: success ? SpritePanelStyle.lime : SpritePanelStyle.cream,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (_purchases.busy) ...[
                const LinearProgressIndicator(),
                const SizedBox(height: 8),
                const Text('購入結果を確認しています…'),
              ] else ...[
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (success)
                      TweenAnimationBuilder<double>(
                        key: const ValueKey('purchase-success-animation'),
                        tween: Tween(begin: 0.65, end: 1.0),
                        duration: MediaQuery.disableAnimationsOf(context)
                            ? Duration.zero
                            : const Duration(milliseconds: 280),
                        curve: Curves.easeOutBack,
                        builder: (context, scale, child) =>
                            Transform.scale(scale: scale, child: child),
                        child: const ZooUiSprite(
                          part: ZooUiPart.check,
                          scale: 2,
                        ),
                      )
                    else
                      const ZooUiSprite(part: ZooUiPart.exclamation, scale: 2),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _purchases.message ?? '',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
                if (_purchases.uncertain)
                  TextButton(
                    key: const ValueKey('retry-purchase'),
                    onPressed: _purchases.retry,
                    child: const Text('購入結果を確認する'),
                  ),
                if (_purchases.awaitingSnapshot) ...[
                  const SizedBox(height: 8),
                  const Text('確定データの反映を待っています。'),
                  TextButton(
                    onPressed: widget.session.refresh,
                    child: const Text('残高・所持情報を再読み込み'),
                  ),
                ],
                if (success && !_purchases.awaitingSnapshot) ...[
                  const SizedBox(height: 8),
                  Text(
                    _purchases.item?.kind == ShopItemKind.animal
                        ? '仲間が増えました！'
                        : '動物園が広がりました！',
                  ),
                ],
                if (success &&
                    !_purchases.awaitingSnapshot &&
                    widget.onViewZoo != null)
                  FilledButton.icon(
                    onPressed: widget.onViewZoo,
                    icon: const ZooArtSprite(part: ZooArtPart.home, scale: 1),
                    label: const Text('動物園を見る'),
                  ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: Listenable.merge([widget.session, _purchases]),
    builder: (context, child) {
      final item = widget.item;
      final snapshot = widget.session.snapshot;
      final available =
          widget.session.repository is ShopRepository &&
          !widget.session.failed &&
          !widget.session.loading &&
          snapshot != null;
      final owned = snapshot != null && item.isOwned(snapshot);
      final unlocked = snapshot != null && item.isUnlocked(snapshot);
      final enough = snapshot != null && snapshot.coins >= item.minimumPrice;
      final names = {for (final i in widget.catalog.items) i.targetId: i.name};
      final requirements = [
        ...item.requiredFacilityIds.map(
          (id) => '${names[id] ?? id}を${item.isResearch ? "購入・配置" : "購入"}',
        ),
        ...item.requiredAnimalIds.map((id) => '${names[id] ?? id}を解放'),
        if (item.minimumAnimalSpecies > 0)
          '動物${item.minimumAnimalSpecies}種類を解放',
      ];
      final blocked =
          _purchases.busy ||
          _purchases.uncertain ||
          _purchases.awaitingSnapshot ||
          _confirming;
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '${snapshot?.coins ?? '—'} コイン',
            key: const ValueKey('shop-balance'),
            style: const TextStyle(fontSize: 22),
          ),
          const SizedBox(height: 12),
          SpritePanel(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(child: ShopItemArt(item: item, size: 64)),
                  const SizedBox(height: 12),
                  Text(item.name, style: const TextStyle(fontSize: 22)),
                  Text(item.priceLabel),
                  const SizedBox(height: 12),
                  const Text(
                    '解放条件',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  Text(
                    requirements.isEmpty ? '初期から購入可' : requirements.join('・'),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    item.pricing == ShopPricing.area
                        ? '面積1マス5コイン。3×3マス以上で購入し、後から拡張できます。'
                        : item.kind == ShopItemKind.animal
                        ? '購入後、動物一覧から任意の囲いに配置できます。'
                        : '購入後、動物園で配置・移動できます。',
                  ),
                  const SizedBox(height: 16),
                  FilledButton(
                    key: ValueKey('buy-${item.id}'),
                    onPressed:
                        available && !owned && unlocked && enough && !blocked
                        ? (item.pricing == ShopPricing.area
                              ? widget.onCreateEnclosure
                              : () => _confirmAndBuy(item))
                        : null,
                    child: Text(
                      item.pricing == ShopPricing.area
                          ? 'サイズと場所を選ぶ'
                          : _purchases.busy && _purchases.item?.id == item.id
                          ? '購入を確認中…'
                          : owned
                          ? '購入済み'
                          : !available
                          ? '未接続'
                          : !unlocked
                          ? '未解放'
                          : !enough
                          ? 'コイン不足'
                          : item.isResearch
                          ? '進化する'
                          : '購入する',
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (owned &&
              item.kind == ShopItemKind.facility &&
              widget.onPlaceFacility != null)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: FilledButton(
                key: const ValueKey('place-facility'),
                onPressed: blocked ? null : widget.onPlaceFacility,
                child: const Text('配置・移動する'),
              ),
            ),
          const SizedBox(height: 12),
          if (!available) ...[
            const Text('購入先に未接続、または更新停止中です'),
            if (widget.session.failed)
              TextButton(
                onPressed: widget.session.refresh,
                child: const Text('残高を再読み込み'),
              ),
          ],
          if (blocked && _purchases.item?.id != item.id)
            const Text('別の購入結果を確認中です。ショップに戻り「前回の購入結果を確認」から確認してください。'),
          Container(
            key: _feedbackAnchor,
            child: AnimatedSwitcher(
              duration: MediaQuery.disableAnimationsOf(context)
                  ? Duration.zero
                  : const Duration(milliseconds: 160),
              child: KeyedSubtree(
                key: ValueKey(_purchases.status),
                child: _feedback(),
              ),
            ),
          ),
        ],
      );
    },
  );
}
