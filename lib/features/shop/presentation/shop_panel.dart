import 'package:flutter/material.dart';

import '../../game/domain/game_repository.dart';
import '../../game/presentation/game_session.dart';
import '../data/shop_catalog_loader.dart';
import '../domain/shop_catalog.dart';
import '../domain/shop_repository.dart';
import 'shop_purchase_controller.dart';

class ShopPanel extends StatefulWidget {
  const ShopPanel({
    super.key,
    required this.session,
    this.purchases,
    this.onViewZoo,
  });
  final GameSession session;
  final ShopPurchaseController? purchases;
  final VoidCallback? onViewZoo;
  @override
  State<ShopPanel> createState() => _ShopPanelState();
}

class _ShopPanelState extends State<ShopPanel> {
  ShopCatalog? _catalog;
  bool _loadFailed = false;
  late final ShopPurchaseController _purchases;
  bool _confirming = false;
  final _feedbackAnchor = GlobalKey();
  PurchaseStatus? _presentedStatus;
  bool _revealScheduled = false;

  @override
  void initState() {
    super.initState();
    _purchases = widget.purchases ?? ShopPurchaseController(widget.session);
    _purchases.addListener(_revealFeedback);
    _load();
  }

  void _revealFeedback() {
    if (_presentedStatus == _purchases.status) return;
    _presentedStatus = _purchases.status;
    if (_revealScheduled || _purchases.status == PurchaseStatus.idle) return;
    _revealScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _revealScheduled = false;
      if (!mounted) return;
      final target = _feedbackAnchor.currentContext;
      if (target != null) {
        Scrollable.ensureVisible(
          target,
          duration: MediaQuery.disableAnimationsOf(context)
              ? Duration.zero
              : const Duration(milliseconds: 220),
        );
      }
    });
  }

  Future<void> _load() async {
    setState(() => _loadFailed = false);
    try {
      final repository = widget.session.repository;
      final catalog = await (repository is ShopRepository
          ? (repository as ShopRepository).loadCatalog()
          : loadShopCatalog());
      if (mounted) setState(() => _catalog = catalog);
    } catch (_) {
      if (mounted) setState(() => _loadFailed = true);
    }
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
      builder: (context) => AlertDialog(
        scrollable: true,
        title: Text('${item.name}を購入しますか？'),
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
                  ? '購入後、動物園に自動で配置されます。'
                  : '購入後、動物園の決まった場所に追加されます。',
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
            child: const Text('購入を確定'),
          ),
        ],
      ),
    );
    if (!mounted) return;
    setState(() => _confirming = false);
    if (confirmed == true) await _purchases.buy(item);
  }

  @override
  void dispose() {
    _purchases.removeListener(_revealFeedback);
    if (widget.purchases == null) _purchases.dispose();
    super.dispose();
  }

  Widget _feedback() {
    if (_purchases.status == PurchaseStatus.idle) {
      return const SizedBox.shrink();
    }
    final success = _purchases.status == PurchaseStatus.success;
    return Semantics(
      liveRegion: true,
      child: Card(
        color: success ? const Color(0xFFE5F0DC) : const Color(0xFFFFF2DC),
        elevation: 0,
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
                    Icon(
                      success ? Icons.check_circle_outline : Icons.info_outline,
                    ),
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
                if (success &&
                    !_purchases.awaitingSnapshot &&
                    widget.onViewZoo != null)
                  FilledButton.icon(
                    onPressed: widget.onViewZoo,
                    icon: const Icon(Icons.pets),
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
      final catalog = _catalog;
      if (_loadFailed) {
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('商品を読み込めませんでした'),
            TextButton(onPressed: _load, child: const Text('再読み込み')),
          ],
        );
      }
      if (catalog == null) {
        return const Center(child: CircularProgressIndicator());
      }
      final snapshot = widget.session.snapshot;
      final available =
          widget.session.repository is ShopRepository &&
          !widget.session.failed &&
          !widget.session.loading &&
          snapshot != null;
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '${snapshot?.coins ?? '—'} コイン',
            key: const ValueKey('shop-balance'),
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
          ),
          if (widget.session.repository.connection == GameConnection.demo)
            const Text(
              'デモショップ・再起動で購入状態はリセットされます',
              style: TextStyle(fontSize: 12),
            ),
          if (!available) ...[
            const Text('購入先に未接続、または更新停止中です'),
            if (widget.session.failed)
              TextButton(
                onPressed: widget.session.refresh,
                child: const Text('残高を再読み込み'),
              ),
          ],
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
          if (catalog.items.isEmpty)
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text('購入できる商品はまだありません'),
            ),
          for (final item in catalog.items)
            Builder(
              builder: (context) {
                final owned = snapshot != null && item.isOwned(snapshot);
                final unlocked = snapshot != null && item.isUnlocked(snapshot);
                final enough = snapshot != null && snapshot.coins >= item.price;
                final names = {
                  for (final i in catalog.items) i.targetId: i.name,
                };
                final requirements = [
                  ...item.requiredAnimalIds.map(
                    (id) => '${names[id] ?? id}を解放',
                  ),
                  if (item.minimumAnimalSpecies > 0)
                    '動物${item.minimumAnimalSpecies}種類を解放',
                ];
                return Card(
                  elevation: 0,
                  margin: const EdgeInsets.only(top: 12),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                item.name,
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            Icon(
                              item.kind == ShopItemKind.animal
                                  ? Icons.pets
                                  : Icons.park_outlined,
                            ),
                          ],
                        ),
                        Text('${item.price} コイン'),
                        Text(
                          requirements.isEmpty
                              ? '初期から購入可'
                              : requirements.join('・'),
                          style: const TextStyle(fontSize: 12),
                        ),
                        const SizedBox(height: 8),
                        FilledButton(
                          key: ValueKey('buy-${item.id}'),
                          onPressed:
                              available &&
                                  !owned &&
                                  unlocked &&
                                  enough &&
                                  !_purchases.busy &&
                                  !_purchases.uncertain &&
                                  !_purchases.awaitingSnapshot &&
                                  !_confirming
                              ? () => _confirmAndBuy(item)
                              : null,
                          child: Text(
                            _purchases.busy && _purchases.item?.id == item.id
                                ? '購入を確認中…'
                                : owned
                                ? '購入済み'
                                : !available
                                ? '未接続'
                                : !unlocked
                                ? '未解放'
                                : !enough
                                ? 'コイン不足'
                                : '購入する',
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
        ],
      );
    },
  );
}
