import '../../game/experience/game_feedback.dart';

import 'dart:math';

import 'package:flutter/material.dart';

import '../../../core/ui/zoo_ui.dart';
import '../../game/domain/zoo_layout.dart';
import '../../shop/domain/shop_repository.dart';
import '../../game/domain/layout_rules.dart';
import '../../game/presentation/layout_transactions.dart';
import '../domain/zoo_world.dart';
import 'zoo_controller.dart';
import 'zoo_map.dart';

class LayoutFeedback extends StatelessWidget {
  const LayoutFeedback({
    super.key,
    required this.transactions,
    this.onRecovered,
  });
  final LayoutTransactions transactions;
  final VoidCallback? onRecovered;
  @override
  Widget build(BuildContext context) => Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      if (transactions.busy) const LinearProgressIndicator(),
      if (transactions.message != null) Text(transactions.message!),
      if (transactions.uncertain)
        OutlinedButton(
          key: const ValueKey('retry-layout'),
          onPressed: transactions.busy
              ? null
              : () async {
                  if (await transactions.retry()) onRecovered?.call();
                },
          child: const Text('操作結果を再確認'),
        ),
      if (transactions.awaitingSnapshot) ...[
        const Text('確定情報の反映を待っています'),
        TextButton(
          onPressed: transactions.session.refresh,
          child: const Text('確定情報を再読み込み'),
        ),
      ],
    ],
  );
}

class EnclosureScreen extends StatefulWidget {
  const EnclosureScreen({
    super.key,
    required this.controller,
    required this.transactions,
    this.createInitially = false,
  });
  final ZooController controller;
  final LayoutTransactions transactions;
  final bool createInitially;
  @override
  State<EnclosureScreen> createState() => _EnclosureScreenState();
}

class _EnclosureScreenState extends State<EnclosureScreen> {
  @override
  void initState() {
    super.initState();
    if (widget.createInitially) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _edit(null);
      });
    }
  }

  void _edit(Enclosure? enclosure) {
    Navigator.push<void>(
      context,
      MaterialPageRoute(
        builder: (_) => EnclosureEditor(
          controller: widget.controller,
          transactions: widget.transactions,
          previous: enclosure,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => PixelUiTheme(
    child: AnimatedBuilder(
      animation: widget.transactions,
      builder: (context, _) {
        final state = widget.transactions.session.snapshot;
        final layout = state?.layout;
        return Scaffold(
          backgroundColor: const Color(0xFFFAF9F0),
          appBar: AppBar(
            backgroundColor: const Color(0xFFFAF9F0),
            surfaceTintColor: Colors.transparent,
            title: const Text('囲いの購入・拡張'),
            leading: IconButton(
              tooltip: '閉じる',
              onPressed: () => Navigator.maybePop(context),
              icon: const ZooUiSprite(part: ZooUiPart.back, scale: 2),
            ),
          ),
          body: SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text('${state?.coins ?? '—'} コイン'),
                  const Text('面積1マスにつき5コイン。拡張は増えた面積分だけ支払います。移動・動物の配置は無料です。'),
                  const SizedBox(height: 12),
                  FilledButton(
                    key: const ValueKey('new-enclosure'),
                    onPressed:
                        state == null ||
                            widget.transactions.session.repository
                                is! ShopRepository ||
                            widget.transactions.blocked
                        ? null
                        : () => _edit(null),
                    child: const Text('囲いを購入して設置'),
                  ),
                  LayoutFeedback(transactions: widget.transactions),
                  if (layout != null)
                    for (final pen in layout.enclosures.values)
                      SpriteTile(
                        title: Text(
                          '囲い ${layout.enclosures.keys.toList().indexOf(pen.id) + 1}',
                        ),
                        subtitle: Text(
                          '${pen.width}×${pen.height}マス・動物${layout.animalEnclosures.values.where((id) => id == pen.id).length}匹',
                        ),
                        leading: const TerrainSprite(part: TerrainPart.fence),
                        onTap: widget.transactions.blocked
                            ? null
                            : () => _edit(pen),
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

class EnclosureEditor extends StatefulWidget {
  const EnclosureEditor({
    super.key,
    required this.controller,
    required this.transactions,
    this.previous,
  });
  final ZooController controller;
  final LayoutTransactions transactions;
  final Enclosure? previous;
  @override
  State<EnclosureEditor> createState() => _EnclosureEditorState();
}

class _EnclosureEditorState extends State<EnclosureEditor> {
  late final String _id =
      widget.previous?.id ??
      'pen_${List.generate(12, (_) => Random.secure().nextInt(256).toRadixString(16).padLeft(2, '0')).join()}';
  late int _left = widget.previous?.left ?? 0, _top = widget.previous?.top ?? 0;
  late int _width = widget.previous?.width ?? 4,
      _height = widget.previous?.height ?? 4;
  bool _confirming = false, _dragging = false;
  Enclosure get _draft => Enclosure(
    id: _id,
    left: _left,
    top: _top,
    width: _width,
    height: _height,
  );
  bool get _blocked => widget.transactions.blocked || _confirming;

  Widget _step(
    String label,
    int value,
    VoidCallback decrease,
    VoidCallback increase,
    bool canDecrease,
    bool canIncrease,
  ) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Text('$label $value'),
      const SizedBox(width: 8),
      IconButton(
        tooltip: '$labelを減らす',
        onPressed: _blocked || !canDecrease ? null : () => setState(decrease),
        icon: const ZooUiSprite(part: ZooUiPart.minus, scale: 2),
      ),
      IconButton(
        tooltip: '$labelを増やす',
        onPressed: _blocked || !canIncrease ? null : () => setState(increase),
        icon: const ZooUiSprite(part: ZooUiPart.plus, scale: 2),
      ),
    ],
  );

  Future<void> _buy(int price) async {
    if (_blocked) return;
    setState(() => _confirming = true);
    final yes = await showDialog<bool>(
      context: context,
      builder: (context) => PixelUiTheme(
        child: SpriteAlertDialog(
          title: Text(price == 0 ? '囲いを移動しますか？' : '囲いを購入・拡張しますか？'),
          content: Text('$_width×$_heightマス\n支払い：$price コイン'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('やめる'),
            ),
            FilledButton(
              key: const ValueKey('confirm-enclosure-charge'),
              onPressed: () => Navigator.pop(context, true),
              child: const Text('確定'),
            ),
          ],
        ),
      ),
    );
    if (!mounted) return;
    setState(() => _confirming = false);
    if (yes != true) return;
    final ok = await widget.transactions.submit(
      LayoutEdit(
        kind: LayoutEditKind.enclosure,
        id: _id,
        left: _left,
        top: _top,
        width: _width,
        height: _height,
      ),
    );
    if (mounted && ok) {
      GameFeedback.placementAccepted();
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) => PixelUiTheme(
    child: AnimatedBuilder(
      animation: widget.transactions,
      builder: (context, _) {
        final state = widget.transactions.session.snapshot;
        final layout = state?.layout ?? ZooLayout();
        final previous = layout.enclosures[_id];
        final issue = validateEnclosure(
          widget.controller.world,
          layout,
          _draft,
          state?.ownedFacilityIds ?? {},
        );
        final price = enclosureEditPrice(_draft, previous);
        return PopScope(
          canPop: !widget.transactions.busy && !_confirming,
          child: Scaffold(
            backgroundColor: const Color(0xFFFAF9F0),
            appBar: AppBar(
              backgroundColor: const Color(0xFFFAF9F0),
              surfaceTintColor: Colors.transparent,
              leading: IconButton(
                tooltip: '囲い一覧へ戻る',
                onPressed: widget.transactions.busy || _confirming
                    ? null
                    : () => Navigator.maybePop(context),
                icon: const ZooUiSprite(part: ZooUiPart.back, scale: 2),
              ),
              title: Text(previous == null ? '囲いを設置' : '囲いを拡張・移動'),
            ),
            body: SafeArea(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      '${state?.coins ?? '—'} コイン・追加料金 $price コイン',
                      key: const ValueKey('enclosure-price'),
                    ),
                    const Text('選択枠をドラッグするか、左上の位置をマップで選択します。幅・高さは柵を含むマス数です。'),
                    Wrap(
                      spacing: 12,
                      children: [
                        _step(
                          '幅',
                          _width,
                          () => _width--,
                          () => _width++,
                          _width > (previous?.width ?? 3),
                          _width < widget.controller.world.columns,
                        ),
                        _step(
                          '高さ',
                          _height,
                          () => _height--,
                          () => _height++,
                          _height > (previous?.height ?? 3),
                          _height < widget.controller.world.rows,
                        ),
                      ],
                    ),
                    SizedBox(
                      height: 300,
                      child: ClipRect(
                        child: InteractiveViewer(
                          minScale: 1,
                          maxScale: 4,
                          child: ZooMap(
                            controller: widget.controller,
                            enclosurePreview: _draft,
                            previewOpacity: _dragging ? .6 : 1,
                            onDraggingChanged: (value) {
                              if (mounted) setState(() => _dragging = value);
                            },
                            draggableTileArea: Rect.fromLTWH(
                              _left.toDouble(),
                              _top.toDouble(),
                              _width.toDouble(),
                              _height.toDouble(),
                            ),
                            onTileDragged: _blocked
                                ? null
                                : (x, y) => setState(() {
                                    _left = x;
                                    _top = y;
                                  }),
                            previewValid: issue == null,
                            onTileSelected: _blocked
                                ? null
                                : (x, y) => setState(() {
                                    _left = x;
                                    _top = y;
                                  }),
                          ),
                        ),
                      ),
                    ),
                    Wrap(
                      spacing: 12,
                      children: [
                        _step(
                          '列',
                          _left + 1,
                          () => _left--,
                          () => _left++,
                          _left > 0,
                          _left < widget.controller.world.columns - 1,
                        ),
                        _step(
                          '行',
                          _top + 1,
                          () => _top--,
                          () => _top++,
                          _top > 0,
                          _top < widget.controller.world.rows - 1,
                        ),
                      ],
                    ),
                    Semantics(
                      liveRegion: true,
                      child: Text(issue ?? 'この場所に設置できます'),
                    ),
                    const SizedBox(height: 8),
                    FilledButton(
                      key: const ValueKey('buy-enclosure'),
                      onPressed:
                          _blocked ||
                              state == null ||
                              issue != null ||
                              price > state.coins
                          ? null
                          : () => _buy(price),
                      child: Text(previous == null ? '購入して設置' : '拡張・移動を確定'),
                    ),
                    if (state != null && price > state.coins)
                      const Text('コインが足りません'),
                    LayoutFeedback(
                      transactions: widget.transactions,
                      onRecovered: () {
                        if (mounted) Navigator.pop(context);
                      },
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    ),
  );
}

class AnimalEnclosurePicker extends StatelessWidget {
  const AnimalEnclosurePicker({
    super.key,
    required this.animal,
    required this.transactions,
  });
  final AnimalDefinition animal;
  final LayoutTransactions transactions;
  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: transactions,
    builder: (context, _) {
      final state = transactions.session.snapshot;
      final layout = state?.layout ?? ZooLayout();
      return Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text('配置する囲いを選んでください。複数の動物を同じ囲いに置けます。'),
          if (layout.enclosures.isEmpty)
            const Text('先に「その他 → 囲いの購入・拡張」から囲いを設置してください。'),
          for (final pen in layout.enclosures.values)
            SpriteTile(
              key: ValueKey('assign-${pen.id}'),
              title: Text(
                '囲い ${layout.enclosures.keys.toList().indexOf(pen.id) + 1}（${pen.width}×${pen.height}）',
              ),
              subtitle: Text(
                layout.animalEnclosures[animal.id] == pen.id
                    ? '現在の囲い'
                    : 'ここに配置',
              ),
              enabled:
                  !transactions.blocked &&
                  state?.ownedAnimalIds.contains(animal.id) == true,
              onTap: transactions.blocked
                  ? null
                  : () async {
                      final navigator = Navigator.of(context);
                      if (await transactions.submit(
                            LayoutEdit(
                              kind: LayoutEditKind.assignAnimal,
                              id: animal.id,
                              enclosureId: pen.id,
                            ),
                          ) &&
                          context.mounted) {
                        navigator.pop();
                      }
                    },
            ),
          LayoutFeedback(
            transactions: transactions,
            onRecovered: () {
              if (context.mounted) Navigator.pop(context);
            },
          ),
        ],
      );
    },
  );
}
