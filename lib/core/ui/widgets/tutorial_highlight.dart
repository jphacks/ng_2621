import 'package:flutter/material.dart';

/// Adds a visible pulse without changing layout or intercepting the target tap.
class TutorialHighlight extends StatefulWidget {
  const TutorialHighlight({
    super.key,
    required this.child,
    this.active = false,
  });
  final Widget child;
  final bool active;
  @override
  State<TutorialHighlight> createState() => _TutorialHighlightState();
}

class _TutorialHighlightState extends State<TutorialHighlight>
    with SingleTickerProviderStateMixin {
  late final _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 700),
  );
  bool _scrolled = false;
  void _sync() {
    if (!widget.active) _scrolled = false;
    if (widget.active && !_scrolled) {
      _scrolled = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && widget.active) {
          Scrollable.ensureVisible(
            context,
            alignment: .15,
            duration: MediaQuery.disableAnimationsOf(context)
                ? Duration.zero
                : const Duration(milliseconds: 180),
          );
        }
      });
    }
    if (widget.active && !MediaQuery.disableAnimationsOf(context)) {
      if (!_pulse.isAnimating) _pulse.repeat(reverse: true);
    } else {
      _pulse.stop();
      _pulse.value = 1;
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _sync();
  }

  @override
  void didUpdateWidget(covariant TutorialHighlight old) {
    super.didUpdateWidget(old);
    _sync();
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.active) return widget.child;
    return Semantics(
      hint: '次にタップする操作です',
      child: Stack(
        fit: StackFit.passthrough,
        clipBehavior: Clip.none,
        children: [
          widget.child,
          Positioned.fill(
            child: IgnorePointer(
              child: AnimatedBuilder(
                animation: _pulse,
                builder: (context, _) =>
                    CustomPaint(painter: _HighlightPainter(_pulse.value)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _HighlightPainter extends CustomPainter {
  _HighlightPainter(this.pulse);
  final double pulse;
  @override
  void paint(Canvas canvas, Size size) {
    final rect = (Offset.zero & size).deflate(1);
    canvas.drawRect(
      rect,
      Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = 6
        ..isAntiAlias = false,
    );
    canvas.drawRect(
      rect,
      Paint()
        ..color = Color.lerp(
          const Color(0xFFFFC400),
          const Color(0xFFFFF38A),
          pulse,
        )!
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..isAntiAlias = false,
    );
  }

  @override
  bool shouldRepaint(_HighlightPainter old) => old.pulse != pulse;
}
