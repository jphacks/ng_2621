import 'package:flutter/foundation.dart';

import '../game/data/mock_game_repository.dart';
import '../game/domain/game_repository.dart';
import '../game/domain/game_snapshot.dart';
import '../shop/domain/shop_catalog.dart';
import '../shop/domain/shop_repository.dart';

enum AssignmentSubject {
  japanese('国語'),
  mathematics('算数・数学'),
  english('英語'),
  science('理科'),
  socialStudies('社会'),
  other('その他');

  const AssignmentSubject(this.label);
  final String label;
}

enum DemoStudyRole { teacher, student }

class StudyFailure implements Exception {
  const StudyFailure(this.message);
  final String message;
}

class DemoAssignment {
  const DemoAssignment({
    this.id = '',
    required this.subject,
    required this.title,
    required this.description,
    required this.dueAt,
  });
  final String id;
  final AssignmentSubject subject;
  final String title;
  final String description;
  final DateTime dueAt;
}

class DemoSubmission {
  const DemoSubmission({
    required this.assignmentId,
    required this.answerText,
    required this.status,
    required this.submittedAt,
    required this.updatedAt,
    this.reviewedAt,
    this.feedback = '',
    this.revisionCount = 0,
  });
  final String assignmentId;
  String get id => '${assignmentId}_demo_student';
  String get studentName => 'デモ生徒';
  final String answerText;
  final AssignmentState status;
  final DateTime submittedAt;
  final DateTime updatedAt;
  final DateTime? reviewedAt;
  final String feedback;
  final int revisionCount;
}

/// Single-class, single-student in-memory demo, never production authorization.
/// Synchronous mutations commit state and unique reward receipts together.
class DemoAssignmentStore extends ChangeNotifier
    implements GameRepository, ShopRepository {
  DemoAssignmentStore({DateTime Function()? clock})
    : _clock = clock ?? DateTime.now {
    _game.receiveConfirmedSnapshot(
      GameSnapshot(
        organizationId: 'demo_org',
        studentId: 'demo_student',
        classIds: ['demo_class'],
        revision: 1,
        coins: 0,
        confirmedAt: _clock(),
      ),
    );
  }
  final DateTime Function() _clock;
  final _game = MockGameRepository();
  final _assignments = <DemoAssignment>[];
  final _submissions = <String, DemoSubmission>{};
  int _sequence = 0;
  List<DemoAssignment> get assignments => List.unmodifiable(_assignments);
  DemoSubmission? submissionFor(String id) => _submissions[id];
  GameSnapshot get snapshot => _game.currentSnapshot;
  int get coins => snapshot.coins;
  @override
  GameConnection get connection => GameConnection.demo;
  @override
  Stream<GameSnapshot> watchGameState() => _game.watchGameState();
  @override
  Future<ShopCatalog> loadCatalog() => _game.loadCatalog();
  @override
  Future<PurchaseReceipt> purchase(PurchaseRequest request) =>
      _game.purchase(request);

  void publish(
    DemoAssignment assignment, {
    DemoStudyRole role = DemoStudyRole.teacher,
  }) {
    _requireRole(role, DemoStudyRole.teacher);
    if (assignment.title.trim().isEmpty ||
        assignment.title.length > 100 ||
        assignment.description.trim().isEmpty ||
        assignment.description.length > 3000) {
      throw const StudyFailure('タイトルと説明を入力してください（タイトル100文字・説明3000文字以内）');
    }
    _assignments.add(
      DemoAssignment(
        id: 'assignment_${++_sequence}',
        subject: assignment.subject,
        title: assignment.title.trim(),
        description: assignment.description.trim(),
        dueAt: assignment.dueAt,
      ),
    );
    _commit();
  }

  DemoAssignment assignmentFor(String id) => _assignments.firstWhere(
    (a) => a.id == id,
    orElse: () => throw const StudyFailure('課題が見つかりません'),
  );

  int submit(String id, String answer, {required DemoStudyRole role}) {
    _requireRole(role, DemoStudyRole.student);
    assignmentFor(id);
    final text = answer.trim();
    if (text.isEmpty || answer.length > 5000) {
      throw const StudyFailure('回答を1〜5000文字で入力してください');
    }
    final previous = _submissions[id];
    if (previous?.status == AssignmentState.approved) {
      throw const StudyFailure('承認済みの課題は変更できません');
    }
    if (previous?.status == AssignmentState.pendingReview) {
      if (previous!.answerText == text) return 0;
      throw const StudyFailure('先生の確認待ちです。回答は変更できません');
    }
    final now = _clock();
    _submissions[id] = DemoSubmission(
      assignmentId: id,
      answerText: text,
      status: AssignmentState.pendingReview,
      submittedAt: now,
      updatedAt: now,
      feedback: previous?.feedback ?? '',
      revisionCount: previous == null ? 0 : previous.revisionCount + 1,
    );
    final amount = previous == null ? 30 : 0;
    _commit(rewardId: amount == 0 ? null : id, kind: RewardKind.submit);
    return amount;
  }

  int review(
    String id, {
    required DemoStudyRole role,
    required bool approve,
    String feedback = '',
  }) {
    _requireRole(role, DemoStudyRole.teacher);
    assignmentFor(id);
    if (feedback.length > 1000) {
      throw const StudyFailure('コメントは1000文字以内で入力してください');
    }
    final previous = _submissions[id];
    if (previous == null) throw const StudyFailure('未提出の課題は確認できません');
    if (previous.status == AssignmentState.approved && approve) return 0;
    if (previous.status != AssignmentState.pendingReview) {
      throw const StudyFailure('確認待ちの提出物だけを確認できます');
    }
    final now = _clock();
    _submissions[id] = DemoSubmission(
      assignmentId: id,
      answerText: previous.answerText,
      status: approve
          ? AssignmentState.approved
          : AssignmentState.needsRevision,
      submittedAt: previous.submittedAt,
      updatedAt: now,
      reviewedAt: now,
      feedback: feedback.trim(),
      revisionCount: previous.revisionCount,
    );
    _commit(rewardId: approve ? id : null, kind: RewardKind.approve);
    return approve ? 70 : 0;
  }

  void _requireRole(DemoStudyRole actual, DemoStudyRole expected) {
    if (actual != expected) throw const StudyFailure('この操作は選択した役割では行えません');
  }

  void _commit({String? rewardId, RewardKind kind = RewardKind.submit}) {
    final current = snapshot;
    final rewards = [...current.rewards];
    var amount = 0;
    if (rewardId != null) {
      final receipt = RewardReceipt(
        assignmentId: rewardId,
        studentId: current.studentId,
        kind: kind,
        amount: kind == RewardKind.submit ? 30 : 70,
        confirmedAt: _clock(),
      );
      if (!rewards.any((r) => r.transactionId == receipt.transactionId)) {
        rewards.add(receipt);
        amount = receipt.amount;
      }
    }
    _game.receiveConfirmedSnapshot(
      GameSnapshot(
        organizationId: current.organizationId,
        studentId: current.studentId,
        classIds: current.classIds,
        revision: current.revision + 1,
        coins: current.coins + amount,
        confirmedAt: _clock(),
        rewards: rewards,
        ownedAnimalIds: current.ownedAnimalIds,
        ownedFacilityIds: current.ownedFacilityIds,
        assignments: _assignments.map((a) {
          final s = _submissions[a.id];
          return AssignmentSummary(
            id: a.id,
            organizationId: current.organizationId,
            classId: 'demo_class',
            title: a.title,
            description: a.description,
            dueAt: a.dueAt,
            state: s?.status ?? AssignmentState.notSubmitted,
            submittedAt: s?.submittedAt,
            feedback: s?.feedback,
            revisionCount: s?.revisionCount ?? 0,
          );
        }),
      ),
    );
    notifyListeners();
  }

  @override
  void dispose() {
    _game.dispose();
    super.dispose();
  }
}
