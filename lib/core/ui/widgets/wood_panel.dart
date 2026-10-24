import 'package:flutter/material.dart';

import 'sprite_panel.dart';

/// Joins the supplied left/middle/right artwork; borders keep their pixel size.
class WoodPanel extends StatelessWidget {
  const WoodPanel({super.key, required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) =>
      SpritePanel(style: SpritePanelStyle.wood, child: child);
}

class WoodButton extends StatefulWidget {
  const WoodButton({super.key, required this.onPressed, required this.child});
  final VoidCallback? onPressed;
  final Widget child;
  @override
  State<WoodButton> createState() => _WoodButtonState();
}

class _WoodButtonState extends State<WoodButton> {
  bool _pressed = false;
  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    enabled: widget.onPressed != null,
    child: AnimatedScale(
      scale: _pressed && !MediaQuery.disableAnimationsOf(context) ? 0.98 : 1,
      duration: MediaQuery.disableAnimationsOf(context)
          ? Duration.zero
          : const Duration(milliseconds: 90),
      child: WoodPanel(
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: widget.onPressed,
            onHighlightChanged: (pressed) => setState(() => _pressed = pressed),
            borderRadius: BorderRadius.circular(8),
            child: ConstrainedBox(
              constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                child: DefaultTextStyle.merge(
                  style: const TextStyle(
                    color: Color(0xFF4D321F),
                    fontWeight: FontWeight.w800,
                  ),
                  child: widget.child,
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );
}
