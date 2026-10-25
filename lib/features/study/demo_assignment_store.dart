import 'dart:typed_data';
import 'dart:convert';

import '../../core/storage/attachments/attachment_vault.dart';
import '../../core/storage/draft_storage.dart';

import '../game/data/mock_game_repository.dart';
import '../game/domain/game_repository.dart';
import '../game/domain/game_snapshot.dart';
import '../shop/domain/shop_catalog.dart';
import '../shop/domain/shop_repository.dart';

import 'study_repository.dart';
import 'study_detector/study_record.dart';
import 'study_detector/study_reward.dart';
export 'study_models.dart';

/// Single-class local demo with optional device persistence, never cloud authority.
/// Synchronous mutations commit state and unique reward receipts together.
class DemoAssignmentStore extends StudyRepository
    implements GameRepository, ShopRepository {
  DemoAssignmentStore({
    DateTime Function()? clock,
    this.storage,
    this.assignmentSource,
    this.studentId = 'demo_student',
    this.studentName = 'デモ生徒',
    AttachmentVault? attachmentVault,
  }) : _game = MockGameRepository(
         initialSnapshot: GameSnapshot(
           organizationId: 'demo_org',
           studentId: studentId,
           classIds: ['demo_class'],
           revision: 0,
           coins: 0,
           confirmedAt: DateTime.now(),
         ),
       ),
       _clock = clock ?? DateTime.now,
       _attachmentVault = attachmentVault ?? MemoryAttachmentVault() {
    _game.receiveConfirmedSnapshot(
      GameSnapshot(
        organizationId: 'demo_org',
        studentId: studentId,
        classIds: ['demo_class'],
        revision: 1,
        coins: 0,
        confirmedAt: _clock(),
      ),
    );
  }
  final String studentId, studentName;
  @override
  List<StudyStudent> get students => [StudyStudent(studentId, studentName)];
  final DraftStorage? storage;
  final DraftStorage? assignmentSource;
  final AttachmentVault _attachmentVault;
  final _knownAttachments = <String, StudyAttachment>{};
  Future<void> _saveQueue = Future.value();
  String? _saveError;
  bool _saving = false;
  bool _disposed = false;
  final _receipts = <String, PurchaseReceipt>{};
  @override
  DraftStorage? get drafts => storage;
  @override
  String get storageLabel => storage == null
      ? 'メモリ内デモ'
      : _saveError != null
      ? '端末への保存に失敗'
      : _saving
      ? '端末に保存中…'
      : '端末内に保存済み';
  @override
  String get storageExplanation => storage == null
      ? super.storageExplanation
      : studentId == 'demo_student'
      ? 'この端末に保存します。先生と生徒は同じデモデータを共有します。クラウド同期はありません。'
      : 'この生徒のデータを端末内に保存します。同じ端末の先生からクラスの課題を受け取れます。別端末との同期はありません。';
  @override
  String? get storageError => _saveError;

  static Future<DemoAssignmentStore> open(
    DraftStorage storage, {
    AttachmentVault? attachmentVault,
    DraftStorage? assignmentSource,
    String studentId = 'demo_student',
    String studentName = 'デモ生徒',
  }) async {
    final store = DemoAssignmentStore(
      storage: storage,
      assignmentSource: assignmentSource,
      studentId: studentId,
      studentName: studentName,
      attachmentVault: attachmentVault,
    );
    try {
      final saved = await storage.read('study-state');
      if (saved != null) store._restore(saved);
      await store.syncClassAssignments();
      return store;
    } catch (_) {
      store.dispose();
      throw const StudyFailure('保存データを読み込めませんでした。既存データは上書きしていません。');
    }
  }

  Map<String, dynamic> _serialize() => {
    'schemaVersion': 1,
    'studyAdvice': _advice.values.map((a) => a.toJson()).toList(),
    'studyDailyMs': _studyDailyMs,
    'studyCoins': _studyCoins,
    'studyRecords': _studyRecords.values.map((r) => r.toJson()).toList(),
    'sequence': _sequence,
    'knownAttachments': _knownAttachments.values
        .map((f) => f.toJson())
        .toList(),
    'snapshot': snapshot.toJson(),
    'assignments': [
      for (final a in _assignments)
        {
          'id': a.id,
          'subject': a.subject.name,
          'title': a.title,
          'description': a.description,
          'dueAt': a.dueAt.toIso8601String(),
        },
    ],
    'submissions': [
      for (final s in _submissions.values)
        {
          'assignmentId': s.assignmentId,
          'answerText': s.answerText,
          'status': s.status.wireName,
          'submittedAt': s.submittedAt.toIso8601String(),
          'updatedAt': s.updatedAt.toIso8601String(),
          'reviewedAt': s.reviewedAt?.toIso8601String(),
          'feedback': s.feedback,
          'revisionCount': s.revisionCount,
          'version': s.version,
          'attachments': s.attachments.map((f) => f.toJson()).toList(),
        },
    ],
    'purchases': [
      for (final r in _receipts.values)
        {
          'requestId': r.requestId,
          'itemId': r.itemId,
          'price': r.price,
          'revision': r.revision,
        },
    ],
  };

  void _restore(Map<String, dynamic> saved) {
    if (saved['schemaVersion'] != 1) {
      throw const FormatException('Unknown saved schema');
    }
    final restored = GameSnapshot.fromJson(
      Map<String, dynamic>.from(saved['snapshot'] as Map),
    );
    if (restored.organizationId != 'demo_org' ||
        restored.studentId != studentId) {
      throw const FormatException('Invalid demo identity');
    }
    for (final raw in saved['studyAdvice'] as List? ?? []) {
      final advice = StudyAdvice.fromJson(
        Map<String, dynamic>.from(raw as Map),
      );
      _advice[advice.id] = advice;
    }
    _sequence = saved['sequence'] as int;
    _studyDailyMs.addAll(
      Map<String, dynamic>.from(saved['studyDailyMs'] as Map? ?? {})
          .map((k, v) => MapEntry(k, v as int)),
    );
    _studyCoins.addAll(
      Map<String, dynamic>.from(saved['studyCoins'] as Map? ?? {})
          .map((k, v) => MapEntry(k, v as int)),
    );
    for (final raw in saved['studyRecords'] as List? ?? []) {
      final record = StudyRecord.fromJson(
        Map<String, dynamic>.from(raw as Map),
      );
      _studyRecords[record.id] = record;
    }
    for (final raw in saved['knownAttachments'] as List? ?? []) {
      final file = StudyAttachment.fromJson(
        Map<String, dynamic>.from(raw as Map),
      );
      _knownAttachments[file.storagePath] = file;
    }
    for (final raw in saved['assignments'] as List) {
      final a = Map<String, dynamic>.from(raw as Map);
      _assignments.add(
        DemoAssignment(
          id: a['id'] as String,
          subject: AssignmentSubject.values.byName(a['subject'] as String),
          title: a['title'] as String,
          description: a['description'] as String,
          dueAt: DateTime.parse(a['dueAt'] as String),
        ),
      );
    }
    if (_assignments.map((a) => a.id).toSet().length != _assignments.length ||
        _assignments.length != restored.assignments.length) {
      throw const FormatException('Invalid saved assignments');
    }
    for (final raw in saved['submissions'] as List) {
      final s = Map<String, dynamic>.from(raw as Map);
      final id = s['assignmentId'] as String;
      assignmentFor(id);
      _submissions[id] = DemoSubmission(
        studentId: studentId,
        studentName: studentName,
        assignmentId: id,
        answerText: s['answerText'] as String,
        status: AssignmentState.parse(s['status'] as String),
        submittedAt: DateTime.parse(s['submittedAt'] as String),
        updatedAt: DateTime.parse(s['updatedAt'] as String),
        reviewedAt: s['reviewedAt'] == null
            ? null
            : DateTime.parse(s['reviewedAt'] as String),
        feedback: s['feedback'] as String,
        revisionCount: s['revisionCount'] as int,
        version: s['version'] as int? ?? 0,
        attachments: (s['attachments'] as List? ?? [])
            .map(
              (f) =>
                  StudyAttachment.fromJson(Map<String, dynamic>.from(f as Map)),
            )
            .toList(),
      );
    }
    for (final raw in saved['purchases'] as List) {
      final r = Map<String, dynamic>.from(raw as Map);
      final receipt = PurchaseReceipt(
        requestId: r['requestId'] as String,
        itemId: r['itemId'] as String,
        price: r['price'] as int,
        revision: r['revision'] as int,
      );
      _receipts[receipt.requestId] = receipt;
    }
    _game.receiveConfirmedSnapshot(restored);
  }

  void _persist() {
    if (storage == null) return;
    final data = _serialize();
    _saving = true;
    _saveQueue = _saveQueue
        .then((_) => storage!.write('study-state', data))
        .then((_) {
          _saveError = null;
        })
        .catchError((Object _) {
          _saveError = '端末に保存できませんでした。再読み込みボタンで保存を再試行してください。';
        })
        .whenComplete(() {
          _saving = false;
          if (!_disposed) notifyListeners();
        });
  }

  @override
  Future<void> flush() async {
    await _saveQueue;
    if (_saveError != null) throw StudyFailure(_saveError!);
  }

  Future<void> syncClassAssignments() async {
    if (assignmentSource == null) return;
    final source = await assignmentSource!.read('study-state');
    for (final raw in source?['assignments'] as List? ?? []) {
      final a = Map<String, dynamic>.from(raw as Map);
      publish(
        DemoAssignment(
          id: a['id'] as String,
          subject: AssignmentSubject.values.byName(a['subject'] as String),
          title: a['title'] as String,
          description: a['description'] as String,
          dueAt: DateTime.parse(a['dueAt'] as String),
        ),
      );
    }
    await flush();
  }

  @override
  Future<void> refresh() async {
    await syncClassAssignments();
    _persist();
    await flush();
  }

  final DateTime Function() _clock;
  final MockGameRepository _game;
  final _studyDailyMs = <String, int>{};
  final _studyCoins = <String, int>{};
  final _advice = <String, StudyAdvice>{};
  @override
  Future<List<StudyAdvice>> loadStudyAdvice({required bool teacher}) async =>
      _advice.values.where((a) => teacher || a.published).toList()
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  @override
  Future<StudyAdvice> generateStudyAdvice(String studentId) async {
    if (!students.any((s) => s.id == studentId)) {
      throw const StudyFailure('生徒が見つかりません');
    }
    final now = _clock();
    final records = _studyRecords.values
        .where(
          (r) =>
              r.studentId == studentId &&
              !r.startedAt.isBefore(now.subtract(const Duration(days: 7))) &&
              !r.endedAt.isAfter(now),
        )
        .toList();
    final minutes = records.fold<int>(0, (sum, r) => sum + r.activeMs) ~/ 60000;
    final missing = records.isEmpty;
    final advice = StudyAdvice(
      id: 'advice_${++_sequence}',
      studentId: studentId,
      createdAt: now,
      summary: missing
          ? '直近7日間の学習モードの記録はありません。未記録の学習については分かりません。'
          : '直近7日間に学習モードを${records.length}回、合計$minutes分利用しています。',
      teacherNote: missing
          ? '記録だけでは判断できません。学習の様子や困りごとを本人に確認してください。'
          : '時間は端末の利用記録です。集中度や理解度は判断せず、取り組んだ内容を本人に確認してください。',
      message: missing
          ? 'べんきょうで、こまっていることはあるかな？ せんせいにおしえてね。'
          : 'べんきょうのじかんをつくれたね！ むずかしかったところがあれば、せんせいにおしえてね。',
      source: 'template',
    );
    _advice[advice.id] = advice;
    _persist();
    await flush();
    return advice;
  }

  @override
  Future<void> publishStudyAdvice(String id, String message) async {
    final a = _advice[id];
    if (a == null) throw const StudyFailure('下書きが見つかりません');
    if (message.trim().isEmpty || message.trim().length > 1000) {
      throw const StudyFailure('1〜1000文字で入力してください');
    }
    if (a.published) {
      if (message.trim() == a.message) return;
      throw const StudyFailure('送信済みのアドバイスは変更できません');
    }
    _advice[id] = StudyAdvice(
      id: a.id,
      studentId: a.studentId,
      createdAt: a.createdAt,
      summary: a.summary,
      teacherNote: a.teacherNote,
      message: message.trim(),
      source: a.source,
      publishedAt: _clock(),
    );
    _persist();
    await flush();
  }

  final _studyRecords = <String, StudyRecord>{};
  @override
  Future<List<StudyRecord>> loadStudyRecords() async =>
      _studyRecords.values
          .map(
            (r) => StudyRecord.fromJson({
              ...r.toJson(),
              'rewardCoins': _studyCoins[r.id] ?? 0,
            }),
          )
          .toList()
        ..sort((a, b) => b.startedAt.compareTo(a.startedAt));
  @override
  Future<int> saveStudyRecord(StudyRecord record) async {
    record = StudyRecord.fromJson({
      ...record.toJson(),
      'studentId': studentId,
      'studentName': studentName,
    });
    record.validate();
    final existing = _studyRecords[record.id];
    if (existing != null &&
        jsonEncode(existing.toJson()) != jsonEncode(record.toJson())) {
      throw const StudyFailure('保存済みの学習記録と一致しません');
    }
    var amount = _studyCoins[record.id] ?? 0;
    if (existing == null) {
      amount = 0;
      for (final entry in record.rewardMsByDay.entries) {
        final before = _studyDailyMs[entry.key] ?? 0;
        final after = before + entry.value;
        amount += studyCoinsFor(after) - studyCoinsFor(before);
        _studyDailyMs[entry.key] = after;
      }
      _studyCoins[record.id] = amount;
      if (amount > 0) {
        final data = snapshot.toJson();
        data['coins'] = snapshot.coins + amount;
        data['revision'] = snapshot.revision + 1;
        data['confirmedAt'] = _clock().toUtc().toIso8601String();
        _game.receiveConfirmedSnapshot(GameSnapshot.fromJson(data));
      }
    }
    _studyRecords[record.id] = record;
    _persist();
    await flush();
    if (!_disposed) notifyListeners();
    return amount;
  }

  final _assignments = <DemoAssignment>[];
  final _submissions = <String, DemoSubmission>{};
  int _sequence = 0;
  @override
  List<DemoAssignment> get assignments => List.unmodifiable(_assignments);
  @override
  DemoSubmission? submissionFor(String id, {String? studentId}) =>
      studentId == null || studentId == this.studentId
      ? _submissions[id]
      : null;
  @override
  List<DemoSubmission> submissionsFor(String id) => [
    if (_submissions[id] != null) _submissions[id]!,
  ];
  GameSnapshot get snapshot => _game.currentSnapshot;
  @override
  int get coins => snapshot.coins;
  @override
  GameConnection get connection => GameConnection.demo;
  @override
  Stream<GameSnapshot> watchGameState() => _game.watchGameState();
  @override
  Future<ShopCatalog> loadCatalog() => _game.loadCatalog();
  @override
  Future<PurchaseReceipt> purchase(PurchaseRequest request) async {
    final previous = _receipts[request.requestId];
    if (previous != null && previous.itemId != request.itemId) {
      throw const PurchaseFailure(PurchaseFailureCode.requestConflict);
    }
    final receipt = previous ?? await _game.purchase(request);
    _receipts[request.requestId] = receipt;
    _persist();
    await flush();
    return receipt;
  }

  @override
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
    if (assignment.id.isNotEmpty &&
        _assignments.any((a) => a.id == assignment.id)) {
      final previous = assignmentFor(assignment.id);
      if (previous.title != assignment.title.trim() ||
          previous.description != assignment.description.trim() ||
          previous.subject != assignment.subject ||
          previous.dueAt != assignment.dueAt) {
        throw const StudyFailure('配布内容が一致しません');
      }
      _persist();
      return;
    }
    _assignments.add(
      DemoAssignment(
        id: assignment.id.isEmpty ? 'assignment_${++_sequence}' : assignment.id,
        subject: assignment.subject,
        title: assignment.title.trim(),
        description: assignment.description.trim(),
        dueAt: assignment.dueAt,
      ),
    );
    _commit();
  }

  @override
  DemoAssignment assignmentFor(String id) => _assignments.firstWhere(
    (a) => a.id == id,
    orElse: () => throw const StudyFailure('課題が見つかりません'),
  );

  @override
  Future<StudyAttachment> addAttachment(
    String assignmentId,
    String name,
    Uint8List bytes,
  ) async {
    assignmentFor(assignmentId);
    final type = validateStudyFile(name, bytes);
    final id = studyFileId(bytes);
    final file = StudyAttachment(
      id: id,
      name: name,
      size: bytes.length,
      contentType: type,
      storagePath: '$assignmentId/$id',
    );
    await _attachmentVault.put(id, bytes);
    validateLoadedAttachment(file, await _attachmentVault.get(id));
    _knownAttachments[file.storagePath] = file;
    _persist();
    await flush();
    return file;
  }

  @override
  Future<Uint8List> readAttachment(StudyAttachment file) async {
    try {
      final bytes = await _attachmentVault.get(file.id);
      validateLoadedAttachment(file, bytes);
      _knownAttachments[file.storagePath] = file;
      return bytes;
    } on StudyFailure {
      rethrow;
    } catch (_) {
      throw const StudyFailure('添付ファイルを読み込めませんでした');
    }
  }

  @override
  int submit(
    String id,
    String answer, {
    required DemoStudyRole role,
    List<StudyAttachment> attachments = const [],
  }) {
    _requireRole(role, DemoStudyRole.student);
    assignmentFor(id);
    final text = answer.trim();
    validateAttachmentList(attachments);
    if ((text.isEmpty && attachments.isEmpty) || answer.length > 5000) {
      throw const StudyFailure('回答を入力するか画像・PDFを添付してください（回答は5000文字以内）');
    }
    for (final file in attachments) {
      if (file.storagePath != '$id/${file.id}') {
        throw const StudyFailure('この課題に添付したファイルを選択してください');
      }
      final known = _knownAttachments[file.storagePath];
      final previouslySubmitted =
          _submissions[id]?.attachments.any(
            (f) => jsonEncode(f.toJson()) == jsonEncode(file.toJson()),
          ) ??
          false;
      if (!previouslySubmitted &&
          (known == null ||
              jsonEncode(known.toJson()) != jsonEncode(file.toJson()))) {
        throw const StudyFailure('添付ファイルを選び直してください');
      }
    }
    final previous = _submissions[id];
    if (previous?.status == AssignmentState.approved) {
      throw const StudyFailure('承認済みの課題は変更できません');
    }
    if (previous?.status == AssignmentState.pendingReview) {
      if (previous!.answerText == text &&
          jsonEncode(previous.attachments.map((f) => f.toJson()).toList()) ==
              jsonEncode(attachments.map((f) => f.toJson()).toList())) {
        return 0;
      }
      throw const StudyFailure('先生の確認待ちです。回答は変更できません');
    }
    final now = _clock();
    _submissions[id] = DemoSubmission(
      studentId: studentId,
      studentName: studentName,
      assignmentId: id,
      answerText: text,
      attachments: List.unmodifiable(attachments),
      status: AssignmentState.pendingReview,
      submittedAt: now,
      updatedAt: now,
      feedback: previous?.feedback ?? '',
      revisionCount: previous == null ? 0 : previous.revisionCount + 1,
      version: (previous?.version ?? 0) + 1,
    );
    final amount = previous == null ? 30 : 0;
    _commit(rewardId: amount == 0 ? null : id, kind: RewardKind.submit);
    return amount;
  }

  @override
  int review(
    String id, {
    required DemoStudyRole role,
    required bool approve,
    String feedback = '',
    String? studentId,
    int? expectedVersion,
  }) {
    _requireRole(role, DemoStudyRole.teacher);
    if (studentId != null && studentId != this.studentId) {
      throw const StudyFailure('対象の生徒が見つかりません');
    }
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
    if (expectedVersion != null && expectedVersion != previous.version) {
      throw const StudyFailure('提出内容が更新されています。もう一度確認してください');
    }
    final now = _clock();
    _submissions[id] = DemoSubmission(
      studentId: this.studentId,
      studentName: studentName,
      assignmentId: id,
      answerText: previous.answerText,
      attachments: previous.attachments,
      status: approve
          ? AssignmentState.approved
          : AssignmentState.needsRevision,
      submittedAt: previous.submittedAt,
      updatedAt: now,
      reviewedAt: now,
      feedback: feedback.trim(),
      revisionCount: previous.revisionCount,
      version: previous.version + 1,
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
    _persist();
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _game.dispose();
    super.dispose();
  }
}
