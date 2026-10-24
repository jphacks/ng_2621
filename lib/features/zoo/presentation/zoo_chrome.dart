import 'package:flutter/material.dart';

import '../../../core/ui/zoo_ui.dart';

const zooInk = Color(0xFF263D2D);
const zooGreen = Color(0xFF386A43);
const zooPaper = Color(0xFFFAF9F0);
const zooLine = Color(0xFFD8E1CF);

/// Only compact, always-needed information stays on the home screen.
class ZooHeader extends StatelessWidget {
  const ZooHeader({
    super.key,
    required this.onProfile,
    required this.onWallet,
    this.coins,
    this.connectionLabel = '未接続',
  });

  final VoidCallback onProfile;
  final VoidCallback onWallet;
  final int? coins;
  final String connectionLabel;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        color: zooPaper,
        border: Border(bottom: BorderSide(color: zooLine)),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
        child: Row(
          children: [
            Expanded(
              flex: 3,
              child: Tooltip(
                message: 'プロフィール',
                child: SpritePanel(
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: onProfile,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 8,
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 48,
                              padding: const EdgeInsets.symmetric(vertical: 5),
                              child: const Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  ZooUiSprite(part: ZooUiPart.smile, scale: 2),
                                  SizedBox(height: 3),
                                  Text(
                                    'Lv.1',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w800,
                                      color: zooGreen,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 10),
                            const Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    'ゲスト',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w800,
                                      color: zooInk,
                                    ),
                                  ),
                                  SizedBox(height: 3),
                                  Text(
                                    'ZooっとStudy',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: zooGreen,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              flex: 2,
              child: Tooltip(
                message: '所持金の詳細',
                child: SpritePanel(
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: onWallet,
                      child: Padding(
                        padding: EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 10,
                        ),
                        child: Row(
                          children: [
                            const ZooArtSprite(
                              part: ZooArtPart.coins,
                              scale: 2,
                            ),
                            SizedBox(width: 6),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    'コイン${connectionLabel.isEmpty ? '' : '・$connectionLabel'}',
                                    style: TextStyle(
                                      fontSize: 10,
                                      color: Color(0xFF75613C),
                                    ),
                                  ),
                                  FittedBox(
                                    fit: BoxFit.scaleDown,
                                    child: Text(
                                      coins == null
                                          ? '—'
                                          : coins.toString().replaceAllMapped(
                                              RegExp(r'(\d)(?=(\d{3})+(?!\d))'),
                                              (match) => '${match[1]},',
                                            ),
                                      style: TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.w800,
                                        color: zooInk,
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
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

enum ZooMainTab { home, study, more }

class ZooBottomBar extends StatelessWidget {
  const ZooBottomBar({
    super.key,
    required this.onHome,
    required this.onStudy,
    this.studyLabel = '学習',
    required this.onMore,
    this.selectedTab = ZooMainTab.home,
  });
  final VoidCallback onHome, onStudy, onMore;
  final String studyLabel;
  final ZooMainTab selectedTab;
  @override
  Widget build(BuildContext context) => SpritePanel(
    style: SpritePanelStyle.brick,
    child: SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
        child: Row(
          children: [
            _tab(
              ZooMainTab.home,
              'ホーム',
              const ZooArtSprite(part: ZooArtPart.home, scale: 2),
              onHome,
              compact:
                  MediaQuery.sizeOf(context).height < 400 ||
                  MediaQuery.viewInsetsOf(context).bottom > 0,
            ),
            const SizedBox(width: 8),
            _tab(
              ZooMainTab.study,
              studyLabel,
              const ZooArtSprite(part: ZooArtPart.bookAndPen, scale: 2),
              onStudy,
              compact:
                  MediaQuery.sizeOf(context).height < 400 ||
                  MediaQuery.viewInsetsOf(context).bottom > 0,
            ),
            const SizedBox(width: 8),
            _tab(
              ZooMainTab.more,
              'その他',
              const Icon(Icons.settings_outlined, size: 28),
              onMore,
              compact:
                  MediaQuery.sizeOf(context).height < 400 ||
                  MediaQuery.viewInsetsOf(context).bottom > 0,
            ),
          ],
        ),
      ),
    ),
  );
  Widget _tab(
    ZooMainTab tab,
    String label,
    Widget icon,
    VoidCallback onTap, {
    bool compact = false,
  }) => Expanded(
    child: Semantics(
      selected: selectedTab == tab,
      child: TextButton(
        key: ValueKey('main-tab-${tab.name}'),
        style: PixelUiTheme.buttonStyle(
          selectedTab == tab ? SpritePanelStyle.cream : SpritePanelStyle.wood,
        ),
        onPressed: onTap,
        child: compact
            ? Text(
                label,
                style: TextStyle(
                  fontWeight: selectedTab == tab
                      ? FontWeight.bold
                      : FontWeight.normal,
                ),
              )
            : Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  icon,
                  const SizedBox(height: 3),
                  Text(
                    label,
                    style: TextStyle(
                      fontWeight: selectedTab == tab
                          ? FontWeight.bold
                          : FontWeight.normal,
                    ),
                  ),
                ],
              ),
      ),
    ),
  );
}

/// Details are revealed on demand rather than permanently covering the zoo.
Future<void> showZooSheet(
  BuildContext context, {
  required String title,
  required List<Widget> children,
  bool patternedBackground = false,
}) {
  Widget surface(Widget child) => patternedBackground
      ? TerrainTexture(child: child)
      : SpritePanel(child: child);
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: false,
    shape: const RoundedRectangleBorder(),
    backgroundColor: Colors.transparent,
    constraints: BoxConstraints(
      maxHeight: MediaQuery.sizeOf(context).height * 0.8,
    ),
    builder: (context) => PixelUiTheme(
      child: surface(
        SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
                child: Row(
                  children: [
                    Expanded(
                      child: WoodPanel(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 2,
                          ),
                          child: Text(
                            title,
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w800,
                              color: zooInk,
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      tooltip: '閉じる',
                      onPressed: () => Navigator.pop(context),
                      icon: const ZooUiSprite(part: ZooUiPart.cross, scale: 2),
                    ),
                  ],
                ),
              ),
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: children,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
