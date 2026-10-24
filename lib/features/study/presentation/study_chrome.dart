import 'package:flutter/material.dart';

import '../../../core/ui/zoo_font.dart';
import '../../../core/ui/zoo_ui.dart';

/// Presentation only: detection, storage and rewards remain in their owners.
class StudyScaffold extends StatelessWidget {
  const StudyScaffold({super.key, required this.appBar, required this.body});
  final PreferredSizeWidget appBar;
  final Widget body;

  @override
  Widget build(BuildContext context) => PixelUiTheme(
    child: Builder(
      builder: (context) => Theme(
        data: Theme.of(context).copyWith(
          actionIconTheme: ActionIconThemeData(
            backButtonIconBuilder: (_) =>
                const ZooUiSprite(part: ZooUiPart.back, scale: 2),
          ),
          inputDecorationTheme: const InputDecorationTheme(
            filled: true,
            fillColor: Color(0xFFFFFDF0),
            border: OutlineInputBorder(borderRadius: BorderRadius.zero),
          ),
        ),
        child: Scaffold(
          appBar: appBar,
          body: TerrainTexture(
            child: Material(
              color: Colors.transparent,
              child: SizedBox.expand(child: body),
            ),
          ),
        ),
      ),
    ),
  );
}

class StudyAppBar extends StatelessWidget implements PreferredSizeWidget {
  const StudyAppBar({super.key, required this.title, this.actions});
  final Widget title;
  final List<Widget>? actions;

  @override
  Size get preferredSize => const Size.fromHeight(64);

  @override
  Widget build(BuildContext context) => AppBar(
    toolbarHeight: 64,
    backgroundColor: const Color(0xFFFAF9F0),
    surfaceTintColor: Colors.transparent,
    scrolledUnderElevation: 0,
    titleTextStyle: const TextStyle(
      fontFamily: ZooFont.family,
      fontSize: 18,
      fontWeight: FontWeight.bold,
      color: Color(0xFF263D2D),
    ),
    title: WoodPanel(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: title,
      ),
    ),
    actions: actions,
  );
}

/// A readable sprite surface without stretching the original corner pixels.
class StudyCard extends StatelessWidget {
  const StudyCard({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
    child: SpritePanel(style: SpritePanelStyle.creamRound, child: child),
  );
}
