import 'package:flutter/material.dart';

import '../../../core/ui/zoo_ui.dart';

import '../domain/game_notice.dart';
import 'game_session.dart';

/// Stays until dismissed so a sheet or short disconnect cannot hide a reward.
class GameNoticeBanner extends StatelessWidget {
  const GameNoticeBanner({
    super.key,
    required this.session,
    required this.onDetails,
  });

  final GameSession session;
  final VoidCallback onDetails;

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: session,
    builder: (context, child) {
      final notice = session.currentNotice;
      if (notice == null) return const SizedBox.shrink();
      return Semantics(
        liveRegion: true,
        child: SpritePanel(
          style: SpritePanelStyle.lime,
          child: Material(
            color: Colors.transparent,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 8, 8),
              child: Row(
                children: [
                  notice.kind == GameNoticeKind.reward
                      ? const ZooArtSprite(part: ZooArtPart.coins, scale: 2)
                      : const ZooUiSprite(part: ZooUiPart.dot, scale: 3),
                  const SizedBox(width: 10),
                  Expanded(
                    child: InkWell(
                      onTap: onDetails,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              notice.message,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF263D2D),
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              notice.detail,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontSize: 12),
                            ),
                            if (session.pendingNotices.length > 1)
                              Text(
                                'ほか${session.pendingNotices.length - 1}件',
                                style: const TextStyle(fontSize: 11),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: '通知を閉じる',
                    onPressed: () => session.dismissNotice(notice.id),
                    icon: const ZooUiSprite(part: ZooUiPart.cross, scale: 2),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    },
  );
}
