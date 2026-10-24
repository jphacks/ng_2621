import '../../../core/storage/draft_storage.dart';
import 'study_record.dart';

/// Account-scoped checkpoint/outbox. Never add time while the process is absent.
class StudyRecordJournal {
  StudyRecordJournal(this.storage);
  final DraftStorage? storage;
  static const key = 'active-study-session';
  Future<void> _queue = Future.value();
  Future<void> write(StudyRecord record) {
    final operation = _queue.then((_) => storage?.write(key, record.toJson()));
    _queue = operation.catchError((Object _) {});
    return operation;
  }

  Future<StudyRecord?> read() async {
    await _queue;
    final json = await storage?.read(key);
    return json == null ? null : StudyRecord.fromJson(json);
  }

  Future<void> clear() async {
    await _queue;
    await storage?.remove(key);
  }
}
