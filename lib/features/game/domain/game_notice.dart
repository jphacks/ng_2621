import 'game_snapshot.dart';

enum GameNoticeKind { reward, revisionRequested }

class GameNotice {
  const GameNotice({
    required this.id,
    required this.kind,
    required this.message,
    required this.detail,
  });

  final String id;
  final GameNoticeKind kind;
  final String message;
  final String detail;
}

/// Session-local notification deduplication, never a coin-granting ledger.
class GameNoticeTracker {
  GameSnapshot? _previous;
  final _seenRewards = <String>{};
  final _seenRevisionRequests = <String>{};

  List<GameNotice> receive(GameSnapshot incoming) {
    final previous = _previous;
    if (previous != null) {
      if (previous.organizationId != incoming.organizationId ||
          previous.studentId != incoming.studentId) {
        throw const FormatException('Notification session identity changed');
      }
      if (incoming.revision <= previous.revision) return const [];
    }
    final notices = <GameNotice>[];
    final rewards = incoming.rewards.toList()
      ..sort((a, b) {
        final time = a.confirmedAt.compareTo(b.confirmedAt);
        return time != 0 ? time : a.kind.index.compareTo(b.kind.index);
      });
    for (final reward in rewards) {
      if (!_seenRewards.add(reward.transactionId) || previous == null) continue;
      final assignment = incoming.assignments.firstWhere(
        (a) => a.id == reward.assignmentId,
      );
      notices.add(
        GameNotice(
          id: reward.transactionId,
          kind: GameNoticeKind.reward,
          message: reward.kind == RewardKind.submit
              ? '課題を提出！ +${reward.amount}コイン'
              : '先生が確認！ +${reward.amount}コイン',
          detail:
              reward.kind == RewardKind.submit &&
                  assignment.state == AssignmentState.pendingReview
              ? '${assignment.title}・先生の確認でさらに +${assignment.approvalReward}コイン'
              : assignment.title,
        ),
      );
    }
    for (final assignment in incoming.assignments) {
      if (assignment.state != AssignmentState.needsRevision) continue;
      final key = '${assignment.id}_revision_${assignment.revisionCount}';
      if (!_seenRevisionRequests.add(key) || previous == null) continue;
      final submitted = incoming.rewards
          .where(
            (r) =>
                r.assignmentId == assignment.id && r.kind == RewardKind.submit,
          )
          .firstOrNull;
      notices.add(
        GameNotice(
          id: key,
          kind: GameNoticeKind.revisionRequested,
          message: submitted == null
              ? '再提出の依頼が届きました'
              : 'もう一度チャレンジ！ 前回の${submitted.amount}コインはそのまま',
          detail: assignment.feedback?.trim().isNotEmpty == true
              ? '${assignment.title}・${assignment.feedback}'
              : assignment.title,
        ),
      );
    }
    _previous = incoming;
    return notices;
  }
}
