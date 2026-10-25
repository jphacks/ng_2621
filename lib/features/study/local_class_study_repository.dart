import 'dart:typed_data';

import '../../core/storage/draft_storage.dart';
import '../../core/storage/request_id.dart';
import '../../core/storage/attachments/attachment_vault.dart';
import '../auth/data/account_scoped_storage.dart';
import '../auth/data/school_account_api.dart';
import '../game/domain/game_repository.dart';
import '../game/domain/game_snapshot.dart';
import '../shop/domain/shop_catalog.dart';
import '../shop/domain/shop_repository.dart';
import 'demo_assignment_store.dart';
import 'study_repository.dart';
import 'study_detector/study_record.dart';

/// One teacher view of a class. Reads each student's actual persisted state.
class LocalClassStudyRepository extends StudyRepository {
  LocalClassStudyRepository._(
    this.storage,
    this.api,
    this.classId,
    this.vault,
    this._catalog,
  );
  final DraftStorage storage;
  final SchoolAccountApi api;
  final String classId;
  final AttachmentVault vault;
  final DemoAssignmentStore _catalog;
  Map<String, DemoAssignmentStore> _stores = {};

  static Future<LocalClassStudyRepository> open({
    required DraftStorage storage,
    required SchoolAccountApi api,
    required String classId,
    required AttachmentVault vault,
  }) async {
    final catalog = await DemoAssignmentStore.open(
      ClassAccountStorage(storage, classId),
      attachmentVault: vault,
    );
    final repository = LocalClassStudyRepository._(
      storage,
      api,
      classId,
      vault,
      catalog,
    );
    try {
      await repository.refresh();
      return repository;
    } catch (_) {
      repository.dispose();
      rethrow;
    }
  }

  @override
  List<StudyStudent> get students => _stores.values
      .map((s) => StudyStudent(s.studentId, s.studentName))
      .toList();
  @override
  List<DemoAssignment> get assignments => _catalog.assignments;
  @override
  DemoAssignment assignmentFor(String id) => _catalog.assignmentFor(id);
  @override
  int get coins => 0;
  @override
  DraftStorage get drafts => ClassAccountStorage(storage, classId);
  @override
  String get storageLabel => 'このクラスの端末内データ';
  @override
  String get storageExplanation =>
      '選択したクラスの生徒に課題を配布し、この端末に保存された提出・学習記録を表示します。別端末との同期はありません。';
  @override
  GameConnection get connection => GameConnection.demo;
  @override
  Stream<GameSnapshot> watchGameState() => _catalog.watchGameState();
  @override
  Future<ShopCatalog> loadCatalog() => _catalog.loadCatalog();
  @override
  Future<PurchaseReceipt> purchase(PurchaseRequest request) =>
      throw const StudyFailure('先生画面では購入できません');

  DemoAssignmentStore _student(String? id) {
    if (id == null && _stores.length == 1) return _stores.values.single;
    final store = _stores[id];
    if (store == null) throw const StudyFailure('このクラスの生徒を選んでください');
    return store;
  }

  @override
  Future<void> refresh() async {
    final roster = await api.call('listManagedStudents', {'classId': classId});
    final next = <String, DemoAssignmentStore>{};
    try {
      for (final raw in roster['students'] as List) {
        final id = raw['id'] as String;
        next[id] = await DemoAssignmentStore.open(
          StudentAccountStorage(storage, id),
          studentId: id,
          studentName: raw['name'] as String,
          assignmentSource: ClassAccountStorage(storage, classId),
          attachmentVault: vault,
        );
      }
    } catch (_) {
      for (final store in next.values) {
        store.dispose();
      }
      rethrow;
    }
    for (final store in _stores.values) {
      store.dispose();
    }
    _stores = next;
    notifyListeners();
  }

  @override
  Future<void> publish(
    DemoAssignment assignment, {
    DemoStudyRole role = DemoStudyRole.teacher,
  }) async {
    _catalog.publish(
      DemoAssignment(
        id: assignment.id.isEmpty ? newRequestId() : assignment.id,
        subject: assignment.subject,
        title: assignment.title,
        description: assignment.description,
        dueAt: assignment.dueAt,
      ),
      role: role,
    );
    // Save the class feed before delivery; retry/login safely completes delivery.
    await _catalog.flush();
    await refresh();
  }

  @override
  DemoSubmission? submissionFor(String id, {String? studentId}) =>
      studentId == null
      ? _stores.values
            .map((s) => s.submissionFor(id))
            .whereType<DemoSubmission>()
            .firstOrNull
      : _stores[studentId]?.submissionFor(id);
  @override
  List<DemoSubmission> submissionsFor(String id) => _stores.values
      .map((s) => s.submissionFor(id))
      .whereType<DemoSubmission>()
      .toList();
  @override
  Future<int> submit(
    String id,
    String answer, {
    required DemoStudyRole role,
    List<StudyAttachment> attachments = const [],
  }) => throw const StudyFailure('生徒画面から提出してください');
  @override
  Future<int> review(
    String id, {
    required DemoStudyRole role,
    required bool approve,
    String feedback = '',
    String? studentId,
    int? expectedVersion,
  }) async {
    final store = _student(studentId);
    final amount = store.review(
      id,
      role: role,
      approve: approve,
      feedback: feedback,
      studentId: store.studentId,
      expectedVersion: expectedVersion,
    );
    await store.flush();
    notifyListeners();
    return amount;
  }

  @override
  Future<Uint8List> readAttachment(StudyAttachment file) =>
      _catalog.readAttachment(file);
  @override
  Future<List<StudyRecord>> loadStudyRecords() async {
    await refresh();
    final records = <StudyRecord>[];
    for (final store in _stores.values) {
      records.addAll(await store.loadStudyRecords());
    }
    return records..sort((a, b) => b.startedAt.compareTo(a.startedAt));
  }

  StudyAdvice _scopedAdvice(StudyAdvice advice) => StudyAdvice.fromJson({
    ...advice.toJson(),
    'id': '${advice.studentId}:${advice.id}',
  });
  @override
  Future<List<StudyAdvice>> loadStudyAdvice({required bool teacher}) async {
    final result = <StudyAdvice>[];
    for (final store in _stores.values) {
      result.addAll(
        (await store.loadStudyAdvice(teacher: teacher)).map(_scopedAdvice),
      );
    }
    return result..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  }

  @override
  Future<StudyAdvice> generateStudyAdvice(String studentId) async =>
      _scopedAdvice(await _student(studentId).generateStudyAdvice(studentId));
  @override
  Future<void> publishStudyAdvice(String id, String message) async {
    final separator = id.indexOf(':');
    if (separator < 1) throw const StudyFailure('アドバイスが見つかりません');
    await _student(id.substring(0, separator))
        .publishStudyAdvice(id.substring(separator + 1), message);
    notifyListeners();
  }

  @override
  Future<void> flush() async {
    await _catalog.flush();
    for (final store in _stores.values) {
      await store.flush();
    }
  }

  @override
  void dispose() {
    for (final store in _stores.values) {
      store.dispose();
    }
    _catalog.dispose();
    super.dispose();
  }
}
