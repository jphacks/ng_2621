import 'dart:math';

import 'package:flutter/material.dart';

import '../../game/domain/game_repository.dart';
import '../../game/presentation/game_session.dart';
import '../data/shop_catalog_loader.dart';
import '../domain/shop_catalog.dart';
import '../domain/shop_repository.dart';

class ShopPanel extends StatefulWidget {
  const ShopPanel({super.key, required this.session});
  final GameSession session;
  @override
  State<ShopPanel> createState() => _ShopPanelState();
}

class _ShopPanelState extends State<ShopPanel> {
  ShopCatalog? _catalog;
  bool _loadFailed = false;
  String? _buying;
  String? _message;
  final _requests = <String, String>{};

  @override
  void initState() {
    super.initState();
    _load();
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

  Future<void> _buy(ShopItem item) async {
    final repository = widget.session.repository;
    final snapshot = widget.session.snapshot;
    if (_buying != null ||
        repository is! ShopRepository ||
        snapshot == null ||
        widget.session.failed ||
        widget.session.loading ||
        item.isOwned(snapshot)) {
      return;
    }
    final id = _requests.putIfAbsent(item.id, () {
      final random = Random.secure();
      return List.generate(
        16,
        (_) => random.nextInt(256).toRadixString(16).padLeft(2, '0'),
      ).join();
    });
    setState(() {
      _buying = item.id;
      _message = null;
    });
    try {
      await (repository as ShopRepository).purchase(
        PurchaseRequest(requestId: id, itemId: item.id),
      );
      _requests.remove(item.id);
      if (mounted) setState(() => _message = '${item.name}を購入しました');
    } on PurchaseFailure catch (error) {
      _requests.remove(
        item.id,
      ); // A definitive rejection may be retried as a new request.
      if (mounted) setState(() => _message = error.message);
    } catch (_) {
      // Unknown outcome: preserve the idempotency key for an explicit retry.
      if (mounted) setState(() => _message = '購入結果を確認できませんでした。同じ商品で再試行できます。');
    } finally {
      if (mounted) setState(() => _buying = null);
    }
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: widget.session,
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
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
          ),
          if (widget.session.repository.connection == GameConnection.demo)
            const Text(
              'デモショップ・再起動で購入状態はリセットされます',
              style: TextStyle(fontSize: 12),
            ),
          if (!available) const Text('購入先に未接続、または更新停止中です'),
          if (_message != null)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Semantics(
                liveRegion: true,
                child: Text(
                  _message!,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
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
                                  _buying == null
                              ? () => _buy(item)
                              : null,
                          child: Text(
                            _buying == item.id
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
