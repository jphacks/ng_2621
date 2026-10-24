import 'package:flutter/material.dart';

import '../../../core/ui/zoo_ui.dart';

const zooInk = Color(0xFF263D2D);
const zooGreen = Color(0xFF386A43);
const zooPaper = Color(0xFFFAF9F0);
const zooLine = Color(0xFFD8E1CF);

/// Only compact, always-needed information stays on the home screen.
class ZooHeader extends StatelessWidget {
  const ZooHeader({super.key, required this.onProfile, required this.onWallet});

  final VoidCallback onProfile;
  final VoidCallback onWallet;

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
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: onProfile,
                    borderRadius: BorderRadius.circular(12),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Row(
                        children: [
                          Container(
                            width: 48,
                            padding: const EdgeInsets.symmetric(vertical: 5),
                            decoration: BoxDecoration(
                              color: const Color(0xFFE9EEDC),
                              borderRadius: BorderRadius.circular(12),
                            ),
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
            const SizedBox(width: 10),
            Expanded(
              flex: 2,
              child: Tooltip(
                message: '所持金の詳細',
                child: Material(
                  color: const Color(0xFFF3EBCF),
                  borderRadius: BorderRadius.circular(12),
                  child: InkWell(
                    onTap: onWallet,
                    borderRadius: BorderRadius.circular(12),
                    child: const Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 10,
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.paid_outlined,
                            size: 22,
                            color: Color(0xFF8C6A20),
                          ),
                          SizedBox(width: 6),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  'コイン',
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: Color(0xFF75613C),
                                  ),
                                ),
                                FittedBox(
                                  fit: BoxFit.scaleDown,
                                  child: Text(
                                    '1,000',
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
          ],
        ),
      ),
    );
  }
}

class ZooBottomBar extends StatelessWidget {
  const ZooBottomBar({
    super.key,
    required this.onHome,
    required this.onStudy,
    required this.onMore,
  });

  final VoidCallback onHome;
  final VoidCallback onStudy;
  final VoidCallback onMore;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        color: zooPaper,
        border: Border(top: BorderSide(color: zooLine)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
          child: Row(
            children: [
              Expanded(
                child: Semantics(
                  selected: true,
                  child: TextButton(
                    style: TextButton.styleFrom(
                      foregroundColor: zooGreen,
                      minimumSize: const Size(48, 56),
                    ),
                    onPressed: onHome,
                    child: const Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.home_rounded, size: 25),
                        SizedBox(height: 3),
                        Text('ホーム'),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: zooGreen,
                    foregroundColor: Colors.white,
                    minimumSize: const Size(48, 62),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 8,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18),
                    ),
                  ),
                  onPressed: onStudy,
                  child: const Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.menu_book_rounded, size: 25),
                      SizedBox(height: 3),
                      Text('勉強', style: TextStyle(fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextButton(
                  style: TextButton.styleFrom(
                    foregroundColor: zooInk,
                    minimumSize: const Size(48, 56),
                  ),
                  onPressed: onMore,
                  child: const Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.more_horiz_rounded, size: 25),
                      SizedBox(height: 3),
                      Text('その他'),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Details are revealed on demand rather than permanently covering the zoo.
Future<void> showZooSheet(
  BuildContext context, {
  required String title,
  required List<Widget> children,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    backgroundColor: zooPaper,
    constraints: BoxConstraints(
      maxHeight: MediaQuery.sizeOf(context).height * 0.8,
    ),
    builder: (context) => SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: zooInk,
                    ),
                  ),
                ),
                IconButton(
                  tooltip: '閉じる',
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close, color: zooInk),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ...children,
          ],
        ),
      ),
    ),
  );
}
