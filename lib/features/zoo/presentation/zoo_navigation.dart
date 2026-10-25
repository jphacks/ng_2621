import 'package:flutter/material.dart';

import '../../../core/ui/zoo_ui.dart';

/// Tracks only the central navigator; the app's authentication route is separate.
class ZooContentObserver extends NavigatorObserver {
  ZooContentObserver(this.onChanged);
  final VoidCallback onChanged;
  final List<Route<dynamic>> routes = [];
  String get section {
    for (final route in routes.reversed) {
      if (['/home', '/study', '/more'].contains(route.settings.name)) {
        return route.settings.name!;
      }
    }
    return '/home';
  }

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    routes.add(route);
    onChanged();
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    routes.remove(route);
    onChanged();
  }

  @override
  void didRemove(Route<dynamic> route, Route<dynamic>? previousRoute) {
    routes.remove(route);
    onChanged();
  }

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    final index = oldRoute == null ? -1 : routes.indexOf(oldRoute);
    if (index >= 0 && newRoute != null) routes[index] = newRoute;
    onChanged();
  }
}

class ZooMenuPage extends StatelessWidget {
  const ZooMenuPage({super.key, required this.title, required this.children});
  final String title;
  final List<Widget> children;
  @override
  Widget build(BuildContext context) => PixelUiTheme(
    child: Builder(
      builder: (context) => Theme(
        data: Theme.of(context).copyWith(
          actionIconTheme: ActionIconThemeData(
            backButtonIconBuilder: (_) =>
                const ZooUiSprite(part: ZooUiPart.back, scale: 2),
          ),
        ),
        child: Scaffold(
          backgroundColor: const Color(0xFFFAF9F0),
          appBar: AppBar(
            title: WoodPanel(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                child: Text(title),
              ),
            ),
            backgroundColor: const Color(0xFFFAF9F0),
            surfaceTintColor: Colors.transparent,
          ),
          body: TerrainTexture(
            child: Material(
              color: Colors.transparent,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: children,
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

class ZooHomeTabs extends StatelessWidget {
  const ZooHomeTabs({
    super.key,
    required this.selected,
    required this.onSelect,
  });
  final int selected;
  final ValueChanged<int> onSelect;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
    child: Row(
      children: [
        for (var index = 0; index < 3; index++)
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 3),
              child: Semantics(
                selected: selected == index,
                child: TextButton(
                  key: ValueKey('home-section-$index'),
                  style: PixelUiTheme.colorfulButtonStyle(
                    selected == index
                        ? ButtonPalette.green
                        : ButtonPalette.cyan,
                  ),
                  onPressed: () => onSelect(index),
                  child: Text(
                    ['動物園', 'ショップ', '囲い・施設'][index],
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontWeight: selected == index
                          ? FontWeight.bold
                          : FontWeight.normal,
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    ),
  );
}
