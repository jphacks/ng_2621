/// Game-facing DTOs. These do not implement assignment management or auth.
enum AssignmentState {
  notSubmitted('not_submitted', '未提出'),
  pendingReview('pending_review', '確認待ち'),
  needsRevision('needs_revision', '再提出待ち'),
  approved('approved', '承認済み');

  const AssignmentState(this.wireName, this.label);
  final String wireName;
  final String label;

  static AssignmentState parse(String value) => values.firstWhere(
    (state) => state.wireName == value,
    orElse: () => throw FormatException('Unknown assignment state: $value'),
  );
}

enum RewardKind { submit, approve }

class AssignmentSummary {
  AssignmentSummary({
    required this.id,
    required this.organizationId,
    required this.classId,
    required this.title,
    required this.description,
    required this.dueAt,
    required this.state,
    this.submittedAt,
    this.feedback,
    this.revisionCount = 0,
    this.submissionReward = 30,
    this.approvalReward = 70,
  }) {
    if ([
          id,
          organizationId,
          classId,
          title,
        ].any((value) => value.trim().isEmpty) ||
        revisionCount < 0 ||
        submissionReward < 0 ||
        approvalReward < 0 ||
        (state == AssignmentState.notSubmitted && submittedAt != null) ||
        (state != AssignmentState.notSubmitted && submittedAt == null)) {
      throw const FormatException('Invalid assignment summary');
    }
  }

  final String id;
  final String organizationId;
  final String classId;
  final String title;
  final String description;
  final DateTime dueAt;
  final AssignmentState state;
  final DateTime? submittedAt;
  final String? feedback;
  final int revisionCount;
  final int submissionReward;
  final int approvalReward;

  bool get submittedLate => submittedAt?.isAfter(dueAt) ?? false;

  factory AssignmentSummary.fromJson(Map<String, dynamic> json) =>
      AssignmentSummary(
        id: json['id'] as String,
        organizationId: json['organizationId'] as String,
        classId: json['classId'] as String,
        title: json['title'] as String,
        description: json['description'] as String,
        dueAt: DateTime.parse(json['dueAt'] as String),
        state: AssignmentState.parse(json['status'] as String),
        submittedAt: json['submittedAt'] == null
            ? null
            : DateTime.parse(json['submittedAt'] as String),
        feedback: json['feedback'] as String?,
        revisionCount: json['revisionCount'] as int,
        submissionReward: json['submissionReward'] as int,
        approvalReward: json['approvalReward'] as int,
      );

  Map<String, dynamic> toJson() => {
    'id': id,
    'organizationId': organizationId,
    'classId': classId,
    'title': title,
    'description': description,
    'dueAt': dueAt.toUtc().toIso8601String(),
    'status': state.wireName,
    'submittedAt': submittedAt?.toUtc().toIso8601String(),
    'feedback': feedback,
    'revisionCount': revisionCount,
    'submissionReward': submissionReward,
    'approvalReward': approvalReward,
  };
}

class RewardReceipt {
  RewardReceipt({
    required this.assignmentId,
    required this.studentId,
    required this.kind,
    required this.amount,
    required this.confirmedAt,
  }) {
    if (assignmentId.isEmpty || studentId.isEmpty || amount <= 0) {
      throw const FormatException('Invalid reward receipt');
    }
  }

  final String assignmentId;
  final String studentId;
  final RewardKind kind;
  final int amount;
  final DateTime confirmedAt;

  String get transactionId => '${assignmentId}_${studentId}_${kind.name}';

  factory RewardReceipt.fromJson(Map<String, dynamic> json) {
    final receipt = RewardReceipt(
      assignmentId: json['assignmentId'] as String,
      studentId: json['studentId'] as String,
      kind: RewardKind.values.byName(json['kind'] as String),
      amount: json['amount'] as int,
      confirmedAt: DateTime.parse(json['confirmedAt'] as String),
    );
    if (receipt.transactionId != json['id']) {
      throw const FormatException('Invalid reward transaction ID');
    }
    return receipt;
  }

  Map<String, dynamic> toJson() => {
    'id': transactionId,
    'assignmentId': assignmentId,
    'studentId': studentId,
    'kind': kind.name,
    'amount': amount,
    'confirmedAt': confirmedAt.toUtc().toIso8601String(),
  };
}

/// A server-confirmed projection, not client instructions to grant coins.
class GameSnapshot {
  GameSnapshot({
    required this.organizationId,
    required this.studentId,
    required this.revision,
    required this.coins,
    required this.confirmedAt,
    required Iterable<String> classIds,
    Iterable<AssignmentSummary> assignments = const [],
    Iterable<RewardReceipt> rewards = const [],
    Iterable<String> ownedAnimalIds = const [],
    Iterable<String> ownedFacilityIds = const [],
  }) : classIds = Set.unmodifiable(classIds),
       assignments = List.unmodifiable(assignments),
       rewards = List.unmodifiable(rewards),
       ownedAnimalIds = Set.unmodifiable(ownedAnimalIds),
       ownedFacilityIds = Set.unmodifiable(ownedFacilityIds) {
    if (organizationId.isEmpty ||
        studentId.isEmpty ||
        revision < 0 ||
        coins < 0 ||
        this.classIds.any((id) => id.isEmpty) ||
        this.assignments.map((a) => a.id).toSet().length !=
            this.assignments.length ||
        this.rewards.map((r) => r.transactionId).toSet().length !=
            this.rewards.length ||
        this.assignments.any(
          (a) =>
              a.organizationId != organizationId ||
              !this.classIds.contains(a.classId),
        ) ||
        this.rewards.any(
          (r) =>
              r.studentId != studentId ||
              !this.assignments.any((a) => a.id == r.assignmentId),
        )) {
      throw const FormatException('Invalid or cross-scope game snapshot');
    }
  }

  final String organizationId;
  final String studentId;
  final int revision;
  final int coins;
  final DateTime confirmedAt;
  final Set<String> classIds;
  final List<AssignmentSummary> assignments;
  final List<RewardReceipt> rewards;
  final Set<String> ownedAnimalIds;
  final Set<String> ownedFacilityIds;

  factory GameSnapshot.fromJson(Map<String, dynamic> json) {
    if (json['schemaVersion'] != 1) {
      throw const FormatException('Unsupported game snapshot schema');
    }
    return GameSnapshot(
      organizationId: json['organizationId'] as String,
      studentId: json['studentId'] as String,
      revision: json['revision'] as int,
      coins: json['coins'] as int,
      confirmedAt: DateTime.parse(json['confirmedAt'] as String),
      classIds: List<String>.from(json['classIds'] as List),
      assignments: (json['assignments'] as List).map(
        (a) => AssignmentSummary.fromJson(a as Map<String, dynamic>),
      ),
      rewards: (json['rewards'] as List).map(
        (r) => RewardReceipt.fromJson(r as Map<String, dynamic>),
      ),
      ownedAnimalIds: List<String>.from(json['ownedAnimalIds'] as List),
      ownedFacilityIds: List<String>.from(json['ownedFacilityIds'] as List),
    );
  }

  Map<String, dynamic> toJson() => {
    'schemaVersion': 1,
    'organizationId': organizationId,
    'studentId': studentId,
    'revision': revision,
    'coins': coins,
    'confirmedAt': confirmedAt.toUtc().toIso8601String(),
    'classIds': classIds.toList(),
    'assignments': assignments.map((a) => a.toJson()).toList(),
    'rewards': rewards.map((r) => r.toJson()).toList(),
    'ownedAnimalIds': ownedAnimalIds.toList(),
    'ownedFacilityIds': ownedFacilityIds.toList(),
  };
}
