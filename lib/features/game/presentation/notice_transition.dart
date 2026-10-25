import 'package:flutter/material.dart';

/// Notification occupies an overlay, never the page's layout height.
class NoticeTransition extends StatefulWidget {
  const NoticeTransition({super.key, required this.child});
  final Widget child;
  @override
  State<NoticeTransition> createState() => _NoticeTransitionState();
}

class _NoticeTransitionState extends State<NoticeTransition> {
  bool _visible = false;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) setState(() => _visible = true);
    });
  }

  @override
  Widget build(BuildContext context) => AnimatedSlide(
    offset: _visible || MediaQuery.disableAnimationsOf(context)
        ? Offset.zero
        : const Offset(0, -1),
    duration: const Duration(milliseconds: 180),
    child: widget.child,
  );
}
