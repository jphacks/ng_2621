import 'package:flutter/material.dart';

import '../../../core/ui/zoo_ui.dart';
import '../../game/domain/game_repository.dart';
import '../../game/presentation/game_session.dart';
import '../data/shop_catalog_loader.dart';
import '../domain/shop_catalog.dart';
import '../domain/shop_repository.dart';
import 'shop_catalog_filter.dart';
import 'shop_item_card.dart';
import 'shop_panel.dart';
import 'shop_purchase_controller.dart';

/// Owns only browsing state. Session and purchase state survive the route when
/// supplied by the zoo, including requests whose result is not yet known.
class ShopScreen extends StatefulWidget {
  const ShopScreen({
    super.key,
    required this.session,
    this.purchases,
    this.onPlaceFacility,
  });
  final GameSession session;
  final ShopPurchaseController? purchases;
  final ValueChanged<String>? onPlaceFacility;

  @override
  State<ShopScreen> createState() => _ShopScreenState();
}

class _ShopScreenState extends State<ShopScreen> {
  late final _purchases =
      widget.purchases ?? ShopPurchaseController(widget.session);
  final _search = TextEditingController();
  final _scroll = {
    for (final kind in ShopItemKind.values) kind: ScrollController(),
  };
  ShopCatalog? _catalog;
  bool _failed = false, _purchasableOnly = false, _hideOwned = false;
  ShopItemKind _kind = ShopItemKind.animal;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _failed = false);
    try {
      final repo = widget.session.repository;
      final catalog = await (repo is ShopRepository
          ? (repo as ShopRepository).loadCatalog()
          : loadShopCatalog());
      if (mounted) setState(() => _catalog = catalog);
    } catch (_) {
      if (mounted) setState(() => _failed = true);
    }
  }

  @override
  void dispose() {
    _search.dispose();
    for (final controller in _scroll.values) {
      controller.dispose();
    }
    if (widget.purchases == null) _purchases.dispose();
    super.dispose();
  }

  void _updateFilters(VoidCallback update) {
    setState(update);
    if (_scroll[_kind]!.hasClients) _scroll[_kind]!.jumpTo(0);
  }

  Future<void> _openItem(ShopItem item) async {
    FocusManager.instance.primaryFocus?.unfocus();
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (detailContext) => PixelUiTheme(
          child: Scaffold(
            backgroundColor: const Color(0xFFFAF9F0),
            appBar: AppBar(
              backgroundColor: const Color(0xFFFAF9F0),
              title: Text(item.name),
              leading: IconButton(
                tooltip: '商品一覧へ戻る',
                onPressed: () => Navigator.pop(detailContext),
                icon: const ZooUiSprite(part: ZooUiPart.back, scale: 2),
              ),
            ),
            body: SafeArea(
              top: false,
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: ShopPanel(
                  session: widget.session,
                  purchases: _purchases,
                  item: item,
                  catalog: _catalog!,
                  onPlaceFacility: widget.onPlaceFacility == null
                      ? null
                      : () {
                          Navigator.pop(detailContext);
                          if (Navigator.of(context).canPop()) {
                            Navigator.pop(context);
                          }
                          widget.onPlaceFacility!(item.targetId);
                        },
                  onViewZoo: () {
                    Navigator.pop(detailContext);
                    if (Navigator.of(context).canPop()) Navigator.pop(context);
                  },
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _toggle(
    String label,
    bool selected,
    VoidCallback onPressed, {
    Key? key,
  }) => Semantics(
    selected: selected,
    child: OutlinedButton(
      key: key,
      onPressed: onPressed,
      style: PixelUiTheme.buttonStyle(
        selected ? SpritePanelStyle.lime : SpritePanelStyle.cream,
      ),
      child: Text(label),
    ),
  );

  @override
  Widget build(BuildContext context) => PixelUiTheme(
    child: AnimatedBuilder(
      animation: Listenable.merge([widget.session, _purchases]),
      builder: (context, child) {
        final snapshot = widget.session.snapshot;
        final available =
            widget.session.repository is ShopRepository &&
            snapshot != null &&
            !widget.session.loading &&
            !widget.session.failed;
        final catalog = _catalog;
        final items = catalog == null
            ? <ShopItem>[]
            : ShopCatalogFilter(
                kind: _kind,
                query: _search.text,
                purchasableOnly: _purchasableOnly,
                hideOwned: _hideOwned,
              ).apply(catalog, snapshot, connected: available);
        return Scaffold(
          backgroundColor: const Color(0xFFFAF9F0),
          appBar: AppBar(
            backgroundColor: const Color(0xFFFAF9F0),
            surfaceTintColor: Colors.transparent,
            title: const WoodPanel(
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                child: Text('ショップ'),
              ),
            ),
            leading: IconButton(
              tooltip: '閉じる',
              onPressed: () => Navigator.maybePop(context),
              icon: const ZooUiSprite(part: ZooUiPart.back, scale: 2),
            ),
          ),
          body: SafeArea(
            top: false,
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: SpritePanel(
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Row(
                        children: [
                          const ZooArtSprite(part: ZooArtPart.coins, scale: 2),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              '${snapshot?.coins ?? '—'} コイン',
                              key: const ValueKey('shop-balance'),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    children: [
                      for (final kind in ShopItemKind.values)
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 4),
                            child: _toggle(
                              kind == ShopItemKind.animal ? '動物' : '施設',
                              _kind == kind,
                              () => setState(() => _kind = kind),
                              key: ValueKey(
                                'shop-filter-${kind == ShopItemKind.animal ? '動物' : '施設'}',
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                Expanded(
                  child: _failed
                      ? Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Text('商品を読み込めませんでした'),
                              TextButton(
                                onPressed: _load,
                                child: const Text('再読み込み'),
                              ),
                            ],
                          ),
                        )
                      : catalog == null
                      ? const Center(child: CircularProgressIndicator())
                      : LayoutBuilder(
                          builder: (context, constraints) {
                            final textScale =
                                MediaQuery.textScalerOf(context).scale(16) / 16;
                            final columns =
                                textScale > 1.3 || constraints.maxWidth < 360
                                ? 1
                                : (constraints.maxWidth / 180).floor().clamp(
                                    2,
                                    4,
                                  );
                            return CustomScrollView(
                              key: PageStorageKey(_kind),
                              controller: _scroll[_kind],
                              slivers: [
                                SliverPadding(
                                  padding: const EdgeInsets.fromLTRB(
                                    16,
                                    0,
                                    16,
                                    12,
                                  ),
                                  sliver: SliverToBoxAdapter(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.stretch,
                                      children: [
                                        SpritePanel(
                                          child: Padding(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 12,
                                              vertical: 2,
                                            ),
                                            child: TextField(
                                              key: const ValueKey(
                                                'shop-search',
                                              ),
                                              controller: _search,
                                              onChanged: (_) =>
                                                  _updateFilters(() {}),
                                              textInputAction:
                                                  TextInputAction.search,
                                              decoration: InputDecoration(
                                                labelText: '名前で検索',
                                                border: InputBorder.none,
                                                prefixIcon: const Padding(
                                                  padding: EdgeInsets.all(8),
                                                  child: ZooExtraSprite(
                                                    part: ZooExtraPart
                                                        .magnifyingGlass,
                                                    scale: 1.5,
                                                  ),
                                                ),
                                                suffixIcon: _search.text.isEmpty
                                                    ? null
                                                    : IconButton(
                                                        tooltip: '検索をクリア',
                                                        onPressed: () =>
                                                            _updateFilters(
                                                              _search.clear,
                                                            ),
                                                        icon: const ZooUiSprite(
                                                          part: ZooUiPart.cross,
                                                          scale: 1,
                                                        ),
                                                      ),
                                              ),
                                            ),
                                          ),
                                        ),
                                        const SizedBox(height: 8),
                                        Wrap(
                                          spacing: 8,
                                          runSpacing: 4,
                                          children: [
                                            _toggle(
                                              '購入可能のみ',
                                              _purchasableOnly,
                                              () => _updateFilters(
                                                () => _purchasableOnly =
                                                    !_purchasableOnly,
                                              ),
                                              key: const ValueKey(
                                                'shop-purchasable',
                                              ),
                                            ),
                                            _toggle(
                                              '購入済みを隠す',
                                              _hideOwned,
                                              () => _updateFilters(
                                                () => _hideOwned = !_hideOwned,
                                              ),
                                              key: const ValueKey(
                                                'shop-hide-owned',
                                              ),
                                            ),
                                          ],
                                        ),
                                        if (widget
                                                .session
                                                .repository
                                                .connection ==
                                            GameConnection.demo)
                                          const Padding(
                                            padding: EdgeInsets.only(top: 8),
                                            child: Text(
                                              'デモショップ・再起動で購入状態はリセットされます',
                                              style: TextStyle(fontSize: 12),
                                            ),
                                          ),
                                        if (!available) ...[
                                          const Text('購入先に未接続、または更新停止中です'),
                                          if (widget.session.failed)
                                            TextButton(
                                              onPressed: widget.session.refresh,
                                              child: const Text('残高を再読み込み'),
                                            ),
                                        ],
                                        if (_purchases.item != null &&
                                            _purchases.status !=
                                                PurchaseStatus.idle)
                                          OutlinedButton(
                                            key: const ValueKey(
                                              'resume-purchase',
                                            ),
                                            onPressed: () =>
                                                _openItem(_purchases.item!),
                                            child: const Text('前回の購入結果を確認'),
                                          ),
                                        const SizedBox(height: 8),
                                        Text(
                                          '${items.length}件',
                                          key: const ValueKey(
                                            'shop-result-count',
                                          ),
                                        ),
                                        if (items.isEmpty) ...[
                                          const Padding(
                                            padding: EdgeInsets.symmetric(
                                              vertical: 24,
                                            ),
                                            child: Text('条件に合う商品はありません'),
                                          ),
                                          TextButton(
                                            onPressed: () => _updateFilters(() {
                                              _search.clear();
                                              _purchasableOnly = false;
                                              _hideOwned = false;
                                            }),
                                            child: const Text('検索・絞り込みをリセット'),
                                          ),
                                        ],
                                      ],
                                    ),
                                  ),
                                ),
                                SliverPadding(
                                  padding: const EdgeInsets.fromLTRB(
                                    16,
                                    0,
                                    16,
                                    24,
                                  ),
                                  sliver: SliverGrid(
                                    gridDelegate:
                                        SliverGridDelegateWithFixedCrossAxisCount(
                                          crossAxisCount: columns,
                                          mainAxisSpacing: 12,
                                          crossAxisSpacing: 12,
                                          mainAxisExtent: 120 + 80 * textScale,
                                        ),
                                    delegate: SliverChildBuilderDelegate((
                                      context,
                                      index,
                                    ) {
                                      final item = items[index];
                                      return ShopItemCard(
                                        item: item,
                                        snapshot: snapshot,
                                        available: available,
                                        onTap: () => _openItem(item),
                                      );
                                    }, childCount: items.length),
                                  ),
                                ),
                              ],
                            );
                          },
                        ),
                ),
              ],
            ),
          ),
        );
      },
    ),
  );
}
