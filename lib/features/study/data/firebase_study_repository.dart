import 'dart:typed_data';

import 'package:firebase_storage/firebase_storage.dart';

import 'dart:async';
import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';

import '../../../core/storage/draft_storage.dart';
import '../../../core/storage/request_id.dart';
import '../../game/domain/game_repository.dart';
import '../../game/domain/game_snapshot.dart';
import '../../shop/data/shop_catalog_loader.dart';
import '../../shop/domain/shop_catalog.dart';
import '../../shop/domain/shop_repository.dart';
import '../study_repository.dart';
import '../study_detector/study_record.dart';

class FirebaseStudyRepository extends StudyRepository {
  FirebaseStudyRepository._(
    this._db,
    this._functions,
    this.identity,
    this._drafts,
    this.emulator,
  );
  final FirebaseFirestore _db;
  final FirebaseFunctions _functions;
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final Map<String, dynamic> identity;
  final DraftStorage _drafts;
  final bool emulator;
  @override
  List<StudyStudent> get students => (identity['students'] as List)
      .map((s) => StudyStudent(s['id'] as String, s['name'] as String))
      .toList();
  String get uid => identity['uid'] as String;
  String get classId => identity['classId'] as String;
  String get organizationId => identity['organizationId'] as String;
  @override
  int get coins => _snapshot?.coins ?? 0;
  bool get isTeacher => identity['role'] == 'teacher';
  final _assignments = <DemoAssignment>[];
  final _submissions = <DemoSubmission>[];
  final _subscriptions = <StreamSubscription<dynamic>>[];
  final _changes = StreamController<GameSnapshot>.broadcast(sync: true);
  final _pending = <String, String>{};
  GameSnapshot? _snapshot;
  bool _loading = true;
  bool _disposed = false;
  String? _error;
  int _generation = 0;
  int _teacherRevision = 0;
  Timer? _refreshTimer;

  static Future<FirebaseStudyRepository> connect({
    required FirebaseFirestore firestore,
    required FirebaseFunctions functions,
    required DraftStorage Function(String namespace) draftFactory,
    required bool emulator,
  }) async {
    final result = await functions
        .httpsCallable('sessionInfo')
        .call<dynamic>()
        .timeout(const Duration(seconds: 20));
    final identity = Map<String, dynamic>.from(result.data as Map);
    final store = FirebaseStudyRepository._(
      firestore,
      functions,
      identity,
      draftFactory(
        '${identity['organizationId']}.${identity['classId']}.${identity['uid']}',
      ),
      emulator,
    );
    try {
      await store.refresh();
      store._listen();
      return store;
    } catch (_) {
      store.dispose();
      rethrow;
    }
  }

  @override
  DraftStorage get drafts => _drafts;
  @override
  bool get loading => _loading;
  @override
  String? get storageError => _error;
  @override
  String get storageLabel => emulator ? 'Firebaseエミュレーターに保存' : 'Firebaseに保存';
  @override
  String get storageExplanation =>
      'ログイン：${identity['displayName']} ／ ${isTeacher ? '先生' : '生徒'}\n課題はサーバーで共有します。未送信の下書きはこの端末だけに保存します。';
  @override
  GameConnection get connection => GameConnection.connected;
  @override
  List<DemoAssignment> get assignments => List.unmodifiable(_assignments);
  @override
  DemoAssignment assignmentFor(String id) => _assignments.firstWhere(
    (a) => a.id == id,
    orElse: () => throw const StudyFailure('課題が見つかりません。再読み込みしてください'),
  );
  @override
  List<DemoSubmission> submissionsFor(String id) =>
      _submissions.where((s) => s.assignmentId == id).toList();
  @override
  DemoSubmission? submissionFor(String id, {String? studentId}) => _submissions
      .where(
        (s) =>
            s.assignmentId == id &&
            s.studentId == (studentId ?? (isTeacher ? s.studentId : uid)),
      )
      .firstOrNull;

  Query<Map<String, dynamic>> _query(String collection) => _db
      .collection(collection)
      .where('classId', isEqualTo: classId)
      .where('organizationId', isEqualTo: organizationId);
  Query<Map<String, dynamic>> get _assignmentQuery =>
      _query('assignments').where('status', isEqualTo: 'published');
  Query<Map<String, dynamic>> get _submissionQuery => isTeacher
      ? _query('submissions')
      : _query('submissions').where('studentId', isEqualTo: uid);
  Query<Map<String, dynamic>> get _rewardQuery =>
      _query('rewardTransactions').where('studentId', isEqualTo: uid);

  void _listen() {
    void changed(Object? _) {
      _refreshTimer?.cancel();
      _refreshTimer = Timer(const Duration(milliseconds: 80), () {
        if (!_disposed) refresh().catchError((Object _) {});
      });
    }

    void failed(Object error) {
      _error = '通信を確認して再読み込みしてください';
      if (!_disposed) {
        _changes.addError(error);
        notifyListeners();
      }
    }

    _subscriptions.add(
      _assignmentQuery.snapshots().listen(changed, onError: failed),
    );
    _subscriptions.add(
      _submissionQuery.snapshots().listen(changed, onError: failed),
    );
    _subscriptions.add(
      _db
          .collection('zoos')
          .doc(uid)
          .snapshots()
          .listen(changed, onError: failed),
    );
    if (!isTeacher) {
      _subscriptions.add(
        _rewardQuery.snapshots().listen(changed, onError: failed),
      );
    }
  }

  @override
  Future<void> refresh() async {
    final generation = ++_generation;
    _loading = true;
    if (!_disposed) notifyListeners();
    try {
      const server = GetOptions(source: Source.server);
      final results = await Future.wait<dynamic>([
        _assignmentQuery.get(server),
        _submissionQuery.get(server),
        _db.collection('zoos').doc(uid).get(server),
        isTeacher ? Future.value(null) : _rewardQuery.get(server),
      ]).timeout(const Duration(seconds: 20));
      if (_disposed || generation != _generation) return;
      final assignmentDocs = results[0] as QuerySnapshot<Map<String, dynamic>>;
      final submissionDocs = results[1] as QuerySnapshot<Map<String, dynamic>>;
      final zoo = (results[2] as DocumentSnapshot<Map<String, dynamic>>).data();
      final rewardDocs = results[3] as QuerySnapshot<Map<String, dynamic>>?;
      _assignments.clear();
      _assignments.addAll(
        assignmentDocs.docs.map((doc) {
          final a = doc.data();
          return DemoAssignment(
            id: doc.id,
            subject: AssignmentSubject.values.byName(a['subject'] as String),
            title: a['title'] as String,
            description: a['description'] as String,
            dueAt: (a['dueAt'] as Timestamp).toDate(),
          );
        }),
      );
      _assignments.sort((a, b) => b.dueAt.compareTo(a.dueAt));
      _submissions.clear();
      _submissions.addAll(
        submissionDocs.docs.map((doc) {
          final s = doc.data();
          return DemoSubmission(
            assignmentId: s['assignmentId'] as String,
            studentId: s['studentId'] as String,
            studentName: s['studentName'] as String? ?? '生徒',
            answerText: s['answerText'] as String,
            status: AssignmentState.parse(s['status'] as String),
            submittedAt: (s['submittedAt'] as Timestamp).toDate(),
            updatedAt: (s['updatedAt'] as Timestamp).toDate(),
            reviewedAt: (s['reviewedAt'] as Timestamp?)?.toDate(),
            feedback: s['feedback'] as String? ?? '',
            revisionCount: s['revisionCount'] as int,
            version: s['version'] as int,
            attachments: (s['attachments'] as List? ?? [])
                .map(
                  (f) => StudyAttachment.fromJson(
                    Map<String, dynamic>.from(f as Map),
                  ),
                )
                .toList(),
          );
        }),
      );
      final currentIds = _assignments.map((a) => a.id).toSet();
      final rewards =
          rewardDocs?.docs
              .map((doc) {
                final r = doc.data();
                return RewardReceipt(
                  assignmentId: r['assignmentId'] as String,
                  studentId: uid,
                  kind: RewardKind.values.byName(r['kind'] as String),
                  amount: r['amount'] as int,
                  confirmedAt: (r['confirmedAt'] as Timestamp).toDate(),
                );
              })
              .where((r) => currentIds.contains(r.assignmentId))
              .toList() ??
          <RewardReceipt>[];
      final next = GameSnapshot(
        organizationId: organizationId,
        studentId: uid,
        classIds: [classId],
        revision: isTeacher
            ? ++_teacherRevision
            : zoo?['revision'] as int? ?? 0,
        coins: isTeacher ? 0 : zoo?['coins'] as int? ?? 0,
        confirmedAt:
            (zoo?['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
        ownedAnimalIds: List<String>.from(
          zoo?['ownedAnimalIds'] as List? ?? [],
        ),
        ownedFacilityIds: List<String>.from(
          zoo?['ownedFacilityIds'] as List? ?? [],
        ),
        rewards: rewards,
        assignments: isTeacher
            ? []
            : _assignments.map((a) {
                final s = submissionFor(a.id);
                return AssignmentSummary(
                  id: a.id,
                  organizationId: organizationId,
                  classId: classId,
                  title: a.title,
                  description: a.description,
                  dueAt: a.dueAt,
                  state: s?.status ?? AssignmentState.notSubmitted,
                  submittedAt: s?.submittedAt,
                  feedback: s?.feedback,
                  revisionCount: s?.revisionCount ?? 0,
                );
              }),
      );
      if (_snapshot == null || next.revision >= _snapshot!.revision) {
        _snapshot = next;
        _changes.add(next);
      }
      _error = null;
    } catch (error) {
      if (!_disposed && generation == _generation) {
        _error = '保存データを取得できません。通信・ログイン状態を確認して再読み込みしてください。';
        if (_changes.hasListener) _changes.addError(error);
      }
      throw StudyFailure(_error ?? '通信結果を確認できませんでした');
    } finally {
      if (!_disposed && generation == _generation) {
        _loading = false;
        notifyListeners();
      }
    }
  }

  @override
  Future<List<StudyRecord>> loadStudyRecords() async {
    final query = isTeacher
        ? _query('studySessions')
        : _query('studySessions').where('studentId', isEqualTo: uid);
    final result = await query
        .get(const GetOptions(source: Source.server))
        .timeout(const Duration(seconds: 20));
    final records = result.docs.map((doc) {
      final data = doc.data();
      return StudyRecord.fromJson({
        ...Map<String, dynamic>.from(data['record'] as Map),
        'studentId': data['studentId'],
        'studentName': data['studentName'],
        'rewardCoins': data['rewardAmount'] ?? 0,
      });
    }).toList()..sort((a, b) => b.startedAt.compareTo(a.startedAt));
    return records;
  }

  @override
  Future<int> saveStudyRecord(StudyRecord record) async {
    if (isTeacher) throw const StudyFailure('生徒だけが学習記録を保存できます');
    record.validate();
    final result = await _call('saveStudySession', {
      'record': record.toJson(),
    }, requestId: record.id);
    return result['rewardAmount'] as int? ?? 0;
  }

  Future<Map<String, dynamic>> _call(
    String name,
    Map<String, dynamic> payload, {
    String? requestId,
  }) async {
    final key = '$name:${jsonEncode(payload)}';
    final operationId = requestId ?? _pending.putIfAbsent(key, newRequestId);
    try {
      final result = await _functions
          .httpsCallable(name)
          .call<dynamic>({...payload, 'requestId': operationId})
          .timeout(const Duration(seconds: 25));
      await refresh();
      _pending.remove(key);
      return Map<String, dynamic>.from(result.data as Map);
    } on FirebaseFunctionsException catch (error) {
      throw StudyFailure(error.message ?? 'サーバーで処理できませんでした', code: error.code);
    } on TimeoutException {
      throw const StudyFailure('処理結果を確認できませんでした。再試行しても報酬は重複しません。');
    }
  }

  @override
  Future<void> publish(
    DemoAssignment assignment, {
    DemoStudyRole role = DemoStudyRole.teacher,
  }) async {
    if (!isTeacher || role != DemoStudyRole.teacher) {
      throw const StudyFailure('先生だけが課題を配布できます');
    }
    await _call('publishAssignment', {
      'subject': assignment.subject.name,
      'title': assignment.title,
      'description': assignment.description,
      'dueAt': assignment.dueAt.toUtc().toIso8601String(),
    }, requestId: assignment.id.isEmpty ? null : assignment.id);
  }

  @override
  Future<int> submit(
    String id,
    String answer, {
    required DemoStudyRole role,
    List<StudyAttachment> attachments = const [],
  }) async {
    if (isTeacher || role != DemoStudyRole.student) {
      throw const StudyFailure('生徒としてログインしてください');
    }
    validateAttachmentList(attachments);
    if ((answer.trim().isEmpty && attachments.isEmpty) ||
        answer.length > 5000) {
      throw const StudyFailure('回答を入力するか画像・PDFを添付してください');
    }
    return (await _call('submitAssignment', {
          'assignmentId': id,
          'answerText': answer,
          'attachments': attachments.map((f) => f.toJson()).toList(),
        }))['rewardAmount']
        as int;
  }

  @override
  Future<StudyAttachment> addAttachment(
    String assignmentId,
    String name,
    Uint8List bytes,
  ) async {
    if (isTeacher) throw const StudyFailure('ファイルを提出できるのは生徒だけです');
    assignmentFor(assignmentId);
    final type = validateStudyFile(name, bytes);
    final hash = studyFileId(bytes);
    final extension = switch (type) {
      'application/pdf' => 'pdf',
      'image/png' => 'png',
      _ => 'jpg',
    };
    final path =
        'submissionFiles/$organizationId/$classId/$assignmentId/$uid/$hash.$extension';
    final reference = _storage.ref(path);
    try {
      FullMetadata? metadata;
      try {
        metadata = await reference.getMetadata();
      } on FirebaseException catch (error) {
        if (error.code != 'object-not-found') rethrow;
      }
      metadata ??= (await reference.putData(
        bytes,
        SettableMetadata(contentType: type, customMetadata: {'sha256': hash}),
      )).metadata;
      if (metadata?.size != bytes.length || metadata?.contentType != type) {
        throw const StudyFailure('アップロードしたファイルを確認できませんでした');
      }
      return StudyAttachment(
        id: hash,
        name: name,
        size: bytes.length,
        contentType: type,
        storagePath: path,
        generation: metadata?.generation,
      );
    } on FirebaseException catch (error) {
      throw StudyFailure(
        'ファイルのアップロードに失敗しました。通信やStorage設定を確認してください（${error.code}）',
      );
    }
  }

  @override
  Future<Uint8List> readAttachment(StudyAttachment file) async {
    if (!file.storagePath.startsWith(
      'submissionFiles/$organizationId/$classId/',
    )) {
      throw const StudyFailure('このクラスのファイルではありません');
    }
    try {
      final bytes = await _storage
          .ref(file.storagePath)
          .getData(maxStudyFileBytes);
      if (bytes == null) throw const StudyFailure('ファイルが見つかりません');
      validateLoadedAttachment(file, bytes);
      return bytes;
    } on FirebaseException catch (error) {
      throw StudyFailure('ファイルを読み込めませんでした（${error.code}）');
    }
  }

  @override
  Future<int> review(
    String id, {
    required DemoStudyRole role,
    required bool approve,
    String feedback = '',
    String? studentId,
    int? expectedVersion,
  }) async {
    if (!isTeacher || role != DemoStudyRole.teacher || studentId == null) {
      throw const StudyFailure('確認する生徒を選択してください');
    }
    final submission = submissionFor(id, studentId: studentId);
    if (submission == null) throw const StudyFailure('未提出です');
    return (await _call('reviewSubmission', {
          'assignmentId': id,
          'studentId': studentId,
          'approve': approve,
          'feedback': feedback,
          'expectedVersion': expectedVersion ?? submission.version,
        }))['rewardAmount']
        as int;
  }

  @override
  Future<ShopCatalog> loadCatalog() => loadShopCatalog();
  @override
  Future<PurchaseReceipt> purchase(PurchaseRequest request) async {
    try {
      final r = await _call('purchaseItem', {
        'itemId': request.itemId,
      }, requestId: request.requestId);
      return PurchaseReceipt(
        requestId: r['requestId'] as String,
        itemId: r['itemId'] as String,
        price: r['price'] as int,
        revision: r['revision'] as int,
      );
    } on StudyFailure catch (error) {
      final code = switch (error.code) {
        'resource-exhausted' => PurchaseFailureCode.insufficientCoins,
        'already-exists' =>
          error.message.contains('一致')
              ? PurchaseFailureCode.requestConflict
              : PurchaseFailureCode.alreadyOwned,
        'failed-precondition' => PurchaseFailureCode.locked,
        'not-found' => PurchaseFailureCode.unknownItem,
        'permission-denied' ||
        'unauthenticated' => PurchaseFailureCode.unavailable,
        _ => null,
      };
      if (code != null) throw PurchaseFailure(code);
      rethrow;
    }
  }

  @override
  Stream<GameSnapshot> watchGameState() => Stream.multi((controller) {
    final subscription = _changes.stream.listen(
      controller.addSync,
      onError: controller.addErrorSync,
    );
    if (_snapshot != null) controller.addSync(_snapshot!);
    controller.onCancel = subscription.cancel;
  });
  @override
  void dispose() {
    _disposed = true;
    _generation++;
    _refreshTimer?.cancel();
    for (final subscription in _subscriptions) {
      subscription.cancel();
    }
    _changes.close();
    super.dispose();
  }
}
