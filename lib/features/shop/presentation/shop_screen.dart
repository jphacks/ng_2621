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
    this.onCreateEnclosure,
    this.initialQuery = '',
    this.initialKind = ShopItemKind.animal,
    this.embedded = false,
    this.onViewZoo,
  });
  final String initialQuery;
  final ShopItemKind initialKind;
  final bool embedded;
  final VoidCallback? onViewZoo;
  final GameSession session;
  final ShopPurchaseController? purchases;
  final ValueChanged<String>? onPlaceFacility;
  final VoidCallback? onCreateEnclosure;

  @override
  State<ShopScreen> createState() => ShopScreenState();
}

class ShopScreenState extends State<ShopScreen> {
  late final _purchases =
      widget.purchases ?? ShopPurchaseController(widget.session);
  late final _search = TextEditingController(text: widget.initialQuery);
  final _scroll = {
    for (final kind in ShopItemKind.values) kind: ScrollController(),
  };
  ShopCatalog? _catalog;
  bool _failed = false, _purchasableOnly = false, _hideOwned = false;
  late ShopItemKind _kind = widget.initialKind;

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
                  onCreateEnclosure: widget.onCreateEnclosure == null
                      ? null
                      : () {
                          Navigator.pop(detailContext);
                          if (!widget.embedded &&
                              Navigator.of(context).canPop()) {
                            Navigator.pop(context);
                          }
                          widget.onCreateEnclosure!();
                        },
                  onPlaceFacility: widget.onPlaceFacility == null
                      ? null
                      : () {
                          Navigator.pop(detailContext);
                          if (!widget.embedded &&
                              Navigator.of(context).canPop()) {
                            Navigator.pop(context);
                          }
                          widget.onPlaceFacility!(item.targetId);
                        },
                  onViewZoo: () {
                    Navigator.pop(detailContext);
                    if (!widget.embedded && Navigator.of(context).canPop()) {
                      Navigator.pop(context);
                    }
                    widget.onViewZoo?.call();
                  },
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  void browse({String? query, ShopItemKind? kind}) {
    if (query == null && kind == null) return;
    _updateFilters(() {
      if (query != null) _search.text = query;
      if (kind != null) _kind = kind;
    });
  }

  Future<void> _showFilters() => showModalBottomSheet<void>(
    context: context,
    useSafeArea: true,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (sheetContext) => StatefulBuilder(
      builder: (context, refresh) => PixelUiTheme(
        child: SpritePanel(
          child: Material(
            color: Colors.transparent,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    '商品の絞り込み',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  SwitchListTile(
                    key: const ValueKey('shop-purchasable'),
                    title: const Text('購入可能のみ'),
                    value: _purchasableOnly,
                    onChanged: (value) {
                      _updateFilters(() => _purchasableOnly = value);
                      refresh(() {});
                    },
                  ),
                  SwitchListTile(
                    key: const ValueKey('shop-hide-owned'),
                    title: const Text('購入済みを隠す'),
                    value: _hideOwned,
                    onChanged: (value) {
                      _updateFilters(() => _hideOwned = value);
                      refresh(() {});
                    },
                  ),
                  Wrap(
                    spacing: 8,
                    children: [
                      TextButton(
                        onPressed: () {
                          _updateFilters(() {
                            _purchasableOnly = false;
                            _hideOwned = false;
                          });
                          refresh(() {});
                        },
                        child: const Text('絞り込みを解除'),
                      ),
                      FilledButton(
                        onPressed: () => Navigator.pop(sheetContext),
                        child: const Text('一覧に戻る'),
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
  );

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
      style: PixelUiTheme.buttonStyle(SpritePanelStyle.wood).copyWith(
        backgroundBuilder: (context, states, child) => selected
            ? SpritePanel(
                style: SpritePanelStyle.wood,
                child: child ?? const SizedBox.shrink(),
              )
            : child ?? const SizedBox.shrink(),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontWeight: selected ? FontWeight.bold : FontWeight.normal,
        ),
      ),
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
        return LayoutBuilder(
          builder: (context, space) => Scaffold(
            backgroundColor: const Color(0xFFFAF9F0),
            appBar: space.maxHeight < 260
                ? null
                : AppBar(
                    backgroundColor: const Color(0xFFFAF9F0),
                    surfaceTintColor: Colors.transparent,
                    title: const Text('ショップで仲間を迎える'),
                    automaticallyImplyLeading: !widget.embedded,
                    leading: widget.embedded
                        ? null
                        : IconButton(
                            tooltip: '閉じる',
                            onPressed: () => Navigator.maybePop(context),
                            icon: const ZooUiSprite(
                              part: ZooUiPart.back,
                              scale: 2,
                            ),
                          ),
                  ),
            body: SafeArea(
              top: false,
              child: Column(
                children: [
                  if (space.maxHeight >= 260)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        child: Row(
                          children: [
                            const ZooArtSprite(
                              part: ZooArtPart.coins,
                              scale: 2,
                            ),
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
                  Padding(
                    padding: const EdgeInsets.fromLTRB(12, 6, 12, 10),
                    child: Row(
                      children: [
                        for (final kind in ShopItemKind.values)
                          Expanded(
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 4,
                              ),
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
                                  MediaQuery.textScalerOf(context).scale(16) /
                                  16;
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
                                          Padding(
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
                                                filled: true,
                                                fillColor: Colors.white,
                                                border:
                                                    const OutlineInputBorder(
                                                      borderRadius:
                                                          BorderRadius.zero,
                                                    ),
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
                                          const SizedBox(height: 8),
                                          Align(
                                            alignment: Alignment.centerRight,
                                            child: TextButton(
                                              key: const ValueKey(
                                                'shop-open-filters',
                                              ),
                                              style: ButtonStyle(
                                                backgroundBuilder:
                                                    (context, states, child) =>
                                                        child ??
                                                        const SizedBox.shrink(),
                                              ),
                                              onPressed: _showFilters,
                                              child: Text(
                                                '絞り込み${_purchasableOnly || _hideOwned ? '（${(_purchasableOnly ? 1 : 0) + (_hideOwned ? 1 : 0)}）' : ''}',
                                              ),
                                            ),
                                          ),
                                          if (widget
                                                  .session
                                                  .repository
                                                  .connection ==
                                              GameConnection.demo)
                                            const Padding(
                                              padding: EdgeInsets.only(top: 8),
                                              child: Text(
                                                'デモショップ',
                                                style: TextStyle(fontSize: 12),
                                              ),
                                            ),
                                          if (!available) ...[
                                            const Text('購入先に未接続、または更新停止中です'),
                                            if (widget.session.failed)
                                              TextButton(
                                                onPressed:
                                                    widget.session.refresh,
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
                                              onPressed: () =>
                                                  _updateFilters(() {
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
                                            mainAxisExtent:
                                                120 + 80 * textScale,
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
          ),
        );
      },
    ),
  );
}
