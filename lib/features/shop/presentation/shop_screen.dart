import 'package:flutter/material.dart';

import '../../../core/ui/zoo_ui.dart';
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
  late final _pages = PageController(initialPage: _kind.index);
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
      if (mounted) {
        setState(() => _catalog = catalog);
        _syncPage();
      }
    } catch (_) {
      if (mounted) setState(() => _failed = true);
    }
  }

  @override
  void dispose() {
    _search.dispose();
    _pages.dispose();
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
              title: WoodPanel(
                child: Padding(
                  padding: const EdgeInsets.all(8),
                  child: Text(item.name),
                ),
              ),
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
    if (kind != null) _syncPage();
  }

  void _selectKind(ShopItemKind kind) {
    setState(() => _kind = kind);
    _syncPage();
  }

  void _syncPage() {
    void apply() {
      if (mounted && _pages.hasClients) _pages.jumpToPage(_kind.index);
    }

    if (_pages.hasClients) {
      apply();
    } else {
      WidgetsBinding.instance.addPostFrameCallback((_) => apply());
    }
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
      style: PixelUiTheme.colorfulButtonStyle(
        selected ? ButtonPalette.green : ButtonPalette.cyan,
      ),
      child: Text(
        label,
        style: TextStyle(
          fontWeight: selected ? FontWeight.bold : FontWeight.normal,
        ),
      ),
    ),
  );

  Widget _catalogPage(ShopItemKind kind, bool available) {
    final items = ShopCatalogFilter(
      kind: kind,
      query: _search.text,
      purchasableOnly: _purchasableOnly,
      hideOwned: _hideOwned,
    ).apply(_catalog!, widget.session.snapshot, connected: available);
    return CustomScrollView(
      key: PageStorageKey(kind),
      controller: _scroll[kind],
      slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${items.length}件',
                  key: kind == _kind
                      ? const ValueKey('shop-result-count')
                      : null,
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
                    _purchases.status != PurchaseStatus.idle)
                  OutlinedButton(
                    key: const ValueKey('resume-purchase'),
                    onPressed: () => _openItem(_purchases.item!),
                    child: const Text('前回の購入結果を確認'),
                  ),
                if (items.isEmpty) ...[
                  const Text('条件に合う商品はありません'),
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
          padding: const EdgeInsets.fromLTRB(12, 0, 12, 16),
          sliver: SliverGrid(
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 4,
              crossAxisSpacing: 8,
              mainAxisSpacing: 8,
            ),
            delegate: SliverChildBuilderDelegate((context, index) {
              final item = items[index];
              return ShopItemCard(
                item: item,
                snapshot: widget.session.snapshot,
                available: available,
                onTap: () => _openItem(item),
              );
            }, childCount: items.length),
          ),
        ),
      ],
    );
  }

  static const _title = WoodPanel(
    child: Padding(
      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      child: Text('ショップで仲間を迎える', style: TextStyle(fontSize: 13)),
    ),
  );

  @override
  Widget build(BuildContext context) => PixelUiTheme(
    child: AnimatedBuilder(
      animation: Listenable.merge([widget.session, _purchases]),
      builder: (context, child) {
        final available =
            widget.session.repository is ShopRepository &&
            widget.session.snapshot != null &&
            !widget.session.loading &&
            !widget.session.failed;
        return LayoutBuilder(
          builder: (context, space) => Scaffold(
            backgroundColor: const Color(0xFFFAF9F0),
            appBar: widget.embedded || space.maxHeight < 260
                ? null
                : AppBar(
                    toolbarHeight: 48,
                    backgroundColor: const Color(0xFFFAF9F0),
                    surfaceTintColor: Colors.transparent,
                    title: _title,
                    automaticallyImplyLeading: false,
                    leading: Navigator.of(context).canPop()
                        ? IconButton(
                            tooltip: '戻る',
                            onPressed: () => Navigator.maybePop(context),
                            icon: const ZooUiSprite(
                              part: ZooUiPart.back,
                              scale: 2,
                            ),
                          )
                        : null,
                  ),
            body: SafeArea(
              top: false,
              child: Column(
                children: [
                  if (widget.embedded && space.maxHeight >= 260)
                    const Padding(
                      padding: EdgeInsets.only(top: 2, bottom: 2),
                      child: _title,
                    ),
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 2,
                    ),
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
                                () => _selectKind(kind),
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
                        : _catalog == null
                        ? const Center(child: CircularProgressIndicator())
                        : Column(
                            children: [
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 4,
                                ),
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: TextField(
                                        key: const ValueKey('shop-search'),
                                        controller: _search,
                                        onChanged: (_) => _updateFilters(() {}),
                                        textInputAction: TextInputAction.search,
                                        decoration: InputDecoration(
                                          isDense: true,
                                          labelText: '名前で検索',
                                          filled: true,
                                          fillColor: Colors.white,
                                          border: const OutlineInputBorder(
                                            borderRadius: BorderRadius.zero,
                                          ),
                                          prefixIcon: const Padding(
                                            padding: EdgeInsets.all(8),
                                            child: ZooExtraSprite(
                                              part:
                                                  ZooExtraPart.magnifyingGlass,
                                              scale: 1,
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
                                    const SizedBox(width: 8),
                                    TextButton(
                                      key: const ValueKey('shop-open-filters'),
                                      onPressed: _showFilters,
                                      child: Text(
                                        '絞り込み${_purchasableOnly || _hideOwned ? '（${(_purchasableOnly ? 1 : 0) + (_hideOwned ? 1 : 0)}）' : ''}',
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Expanded(
                                child: PageView.builder(
                                  key: const ValueKey('shop-catalog-pages'),
                                  controller: _pages,
                                  itemCount: ShopItemKind.values.length,
                                  onPageChanged: (index) => setState(
                                    () => _kind = ShopItemKind.values[index],
                                  ),
                                  itemBuilder: (context, index) => _catalogPage(
                                    ShopItemKind.values[index],
                                    available,
                                  ),
                                ),
                              ),
                            ],
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
