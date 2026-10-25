import '../../game/experience/game_feedback.dart';

import 'package:flutter/material.dart';

import '../../../core/ui/zoo_ui.dart';
import '../domain/facility_placement.dart';
import '../domain/zoo_world.dart';
import 'zoo_controller.dart';
import 'zoo_map.dart';

/// Draft location stays local until explicitly confirmed and saved.
class FacilityPlacementScreen extends StatefulWidget {
  const FacilityPlacementScreen({
    super.key,
    required this.controller,
    required this.definition,
    this.highlighted = false,
    required this.name,
    required this.onSave,
  });
  final ZooController controller;
  final FacilityDefinition definition;
  final bool highlighted;
  final String name;
  final Future<void> Function(FacilityPlacement placement) onSave;

  @override
  State<FacilityPlacementScreen> createState() =>
      _FacilityPlacementScreenState();
}

class _FacilityPlacementScreenState extends State<FacilityPlacementScreen> {
  late FacilityPlacement _draft = widget.controller.positionOf(
    widget.definition,
  );
  bool _saving = false, _dragging = false;
  String? _error;

  void _select(int x, int y) {
    if (_saving) return;
    setState(() {
      _draft = FacilityPlacement(
        facilityId: widget.definition.id,
        left: x,
        top: y,
      );
      _error = null;
    });
  }

  Future<void> _save() async {
    if (_saving ||
        _dragging ||
        widget.controller.placementIssue(_draft) != null) {
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await widget.onSave(_draft);
      GameFeedback.placementAccepted();
      if (mounted) {
        setState(() => _saving = false);
        Navigator.pop(context);
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _saving = false;
          _error = '配置を保存できませんでした。もう一度お試しください。';
        });
      }
    }
  }

  Widget _arrow(
    String label,
    ZooUiPart part,
    int dx,
    int dy, {
    int turns = 0,
  }) => IconButton(
    tooltip: label,
    onPressed:
        _saving ||
            _draft.left + dx < 0 ||
            _draft.top + dy < 0 ||
            _draft.left + dx >= widget.controller.world.columns ||
            _draft.top + dy >= widget.controller.world.rows
        ? null
        : () => _select(_draft.left + dx, _draft.top + dy),
    icon: RotatedBox(
      quarterTurns: turns,
      child: ZooUiSprite(part: part, scale: 2),
    ),
  );

  Widget _map() => ClipRect(
    key: const ValueKey('facility-map-viewport'),
    child: InteractiveViewer(
      panEnabled: !_dragging,
      scaleEnabled: !_dragging,
      minScale: 1,
      maxScale: 4,
      boundaryMargin: EdgeInsets.zero,
      child: SizedBox.expand(
        child: ZooMap(
          controller: widget.controller,
          previewFacilityId: widget.definition.id,
          previewOpacity: _dragging ? .6 : 1,
          onDraggingChanged: (value) {
            if (mounted) setState(() => _dragging = value);
          },
          onTileSelected: _saving ? null : _select,
          draggableTileArea: Rect.fromLTWH(
            _draft.left.toDouble(),
            _draft.top.toDouble(),
            widget.definition.width.toDouble(),
            widget.definition.height.toDouble(),
          ),
          onTileDragged: _saving ? null : _select,
          placementsOverride: {
            ...widget.controller.placements,
            _draft.facilityId: _draft,
          },
          overlay: _PlacementGrid(
            world: widget.controller.world,
            definition: widget.definition,
            draft: _draft,
            valid: widget.controller.placementIssue(_draft) == null,
          ),
        ),
      ),
    ),
  );

  Widget _controls(PlacementIssue? issue) => SingleChildScrollView(
    key: const ValueKey('facility-placement-controls'),
    physics: _dragging ? const NeverScrollableScrollPhysics() : null,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          '枠をドラッグ／マップをタップして配置（${widget.definition.width}×${widget.definition.height}マス）',
          style: const TextStyle(fontSize: 12),
        ),
        Text(
          '位置：列 ${_draft.left + 1} ／ 行 ${_draft.top + 1}',
          key: const ValueKey('placement-position'),
          style: const TextStyle(fontSize: 14),
        ),
        Wrap(
          alignment: WrapAlignment.center,
          spacing: 8,
          runSpacing: 4,
          children: [
            _arrow('左へ1マス', ZooUiPart.arrowLeft, -1, 0),
            _arrow('上へ1マス', ZooUiPart.arrowLeft, 0, -1, turns: 1),
            _arrow('下へ1マス', ZooUiPart.arrowRight, 0, 1, turns: 1),
            _arrow('右へ1マス', ZooUiPart.arrowRight, 1, 0),
          ],
        ),
        Semantics(
          liveRegion: true,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Text(
              _error ?? issue?.message ?? 'この場所に設置できます',
              key: const ValueKey('placement-status'),
              style: TextStyle(
                fontSize: 13,
                color: _error != null || issue != null
                    ? const Color(0xFF8B2323)
                    : const Color(0xFF263D2D),
              ),
            ),
          ),
        ),
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: _saving ? null : () => Navigator.pop(context),
                child: const Text('キャンセル', style: TextStyle(fontSize: 13)),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: TutorialHighlight(
                active: widget.highlighted && issue == null && !_dragging,
                child: FilledButton(
                  key: const ValueKey('confirm-placement'),
                  onPressed: _saving || _dragging || issue != null
                      ? null
                      : _save,
                  child: Text(
                    _saving ? '保存中…' : 'ここに設置',
                    style: const TextStyle(fontSize: 13),
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    ),
  );

  @override
  Widget build(BuildContext context) => PixelUiTheme(
    child: AnimatedBuilder(
      animation: widget.controller.sceneryRevision,
      builder: (context, _) {
        final issue = widget.controller.placementIssue(_draft);
        return PopScope(
          canPop: !_saving,
          child: Scaffold(
            backgroundColor: const Color(0xFFFAF9F0),
            appBar: AppBar(
              title: Text('${widget.name}を配置'),
              leading: IconButton(
                tooltip: '配置をキャンセル',
                onPressed: _saving ? null : () => Navigator.pop(context),
                icon: const ZooUiSprite(part: ZooUiPart.back, scale: 2),
              ),
            ),
            body: SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    if (constraints.maxWidth > constraints.maxHeight * 1.3) {
                      return Row(
                        children: [
                          Expanded(flex: 3, child: _map()),
                          const SizedBox(width: 12),
                          Expanded(flex: 2, child: _controls(issue)),
                        ],
                      );
                    }
                    return Column(
                      children: [
                        Expanded(child: _map()),
                        const SizedBox(height: 8),
                        ConstrainedBox(
                          constraints: BoxConstraints(
                            maxHeight: (constraints.maxHeight - 80).clamp(
                              0.0,
                              260.0,
                            ),
                          ),
                          child: _controls(issue),
                        ),
                      ],
                    );
                  },
                ),
              ),
            ),
          ),
        );
      },
    ),
  );
}

class _PlacementGrid extends StatelessWidget {
  const _PlacementGrid({
    required this.world,
    required this.definition,
    required this.draft,
    required this.valid,
  });
  final ZooWorld world;
  final FacilityDefinition definition;
  final FacilityPlacement draft;
  final bool valid;
  @override
  Widget build(BuildContext context) =>
      CustomPaint(painter: _GridPainter(world, definition, draft, valid));
}

class _GridPainter extends CustomPainter {
  _GridPainter(this.world, this.definition, this.draft, this.valid);
  final ZooWorld world;
  final FacilityDefinition definition;
  final FacilityPlacement draft;
  final bool valid;
  @override
  void paint(Canvas canvas, Size size) {
    final tile = world.tileSize.toDouble();
    final paint = Paint()..isAntiAlias = false;
    paint.color = const Color(0x55FFFFFF);
    for (var x = 0; x <= world.columns; x++) {
      canvas.drawLine(
        Offset(x * tile, 0),
        Offset(x * tile, size.height),
        paint,
      );
    }
    for (var y = 0; y <= world.rows; y++) {
      canvas.drawLine(Offset(0, y * tile), Offset(size.width, y * tile), paint);
    }
    final rect = Rect.fromLTWH(
      draft.left * tile,
      draft.top * tile,
      definition.width * tile,
      definition.height * tile,
    );
    paint.color = valid ? const Color(0x4444CC44) : const Color(0x66FF3333);
    canvas.drawRect(rect, paint);
    paint
      ..color = valid ? const Color(0xFF275F27) : const Color(0xFFAA2020)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    canvas.drawRect(rect.deflate(1), paint);
  }

  @override
  bool shouldRepaint(_GridPainter old) =>
      old.world != world ||
      old.definition != definition ||
      old.draft != draft ||
      old.valid != valid;
}
