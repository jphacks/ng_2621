import 'package:flutter/material.dart';

import '../domain/game_repository.dart';
import '../domain/game_snapshot.dart';
import 'game_session.dart';

/// Read-only projection of the assignment owner's confirmed result.
class GameStatus extends StatelessWidget {
  const GameStatus({super.key, required this.session, this.walletOnly = false});

  final GameSession session;
  final bool walletOnly;

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: session,
    builder: (context, child) {
      if (session.loading && session.snapshot == null) {
        return const Center(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: CircularProgressIndicator(),
          ),
        );
      }
      if (session.failed) {
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('課題・残高を更新できませんでした。'),
            if (session.snapshot != null) const Text('上部の残高は前回確認時点の値です。'),
            TextButton(onPressed: session.refresh, child: const Text('再読み込み')),
          ],
        );
      }
      final snapshot = session.snapshot;
      if (snapshot == null) {
        return const Text('課題管理システムに未接続です。接続後に自分の課題と確定した残高が表示されます。');
      }
      return Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (session.repository.connection == GameConnection.demo)
            const Padding(
              padding: EdgeInsets.only(bottom: 16),
              child: Text('デモデータ・閲覧専用\n実際の提出・承認は行いません。再起動で初期状態に戻ります。'),
            ),
          if (walletOnly) ...[
            Text(
              '${snapshot.coins} コイン',
              style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            const Text('確定した報酬履歴'),
            if (snapshot.rewards.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 16),
                child: Text('報酬履歴はまだありません'),
              ),
            for (final reward in snapshot.rewards)
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(
                  reward.kind == RewardKind.submit
                      ? '提出で+${reward.amount}'
                      : '承認で+${reward.amount}',
                ),
                subtitle: Text(_date(reward.confirmedAt)),
              ),
          ] else ...[
            const Text(
              '宿題が、動物園を育てる。',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            if (snapshot.assignments.isEmpty) const Text('配布された課題はまだありません'),
            for (final assignment in snapshot.assignments) ...[
              const Divider(),
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(assignment.title),
                subtitle: Text(assignment.state.label),
                trailing: assignment.submittedLate ? const Text('期限後') : null,
              ),
              Text(assignment.description),
              const SizedBox(height: 8),
              Text('締切 ${_date(assignment.dueAt)}'),
              Text(
                '提出で+${assignment.submissionReward} / 承認で+${assignment.approvalReward}',
              ),
              if (assignment.state == AssignmentState.pendingReview)
                Text('先生の確認でさらに +${assignment.approvalReward}コイン'),
              if (assignment.state == AssignmentState.needsRevision)
                const Text('もう一度チャレンジ！ 前回の提出コインはそのまま'),
              if (assignment.feedback != null)
                Text('先生から：${assignment.feedback}'),
              const SizedBox(height: 8),
            ],
            const SizedBox(height: 12),
            const Text('提出・承認の操作は課題管理側で行います。', style: TextStyle(fontSize: 12)),
          ],
        ],
      );
    },
  );

  static String _date(DateTime time) {
    final local = time.toLocal();
    String two(int n) => n.toString().padLeft(2, '0');
    return '${local.year}/${two(local.month)}/${two(local.day)} ${two(local.hour)}:${two(local.minute)}';
  }
}
