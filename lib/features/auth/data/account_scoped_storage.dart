import '../../../core/storage/draft_storage.dart';

class StudentAccountStorage implements DraftStorage {
  StudentAccountStorage(this.parent, this.studentId);
  final DraftStorage parent;
  final String studentId;
  String _key(String key) => 'student.$studentId.$key';
  @override
  Future<Map<String, dynamic>?> read(String key) => parent.read(_key(key));
  @override
  Future<void> write(String key, Map<String, dynamic> value) =>
      parent.write(_key(key), value);
  @override
  Future<void> remove(String key) => parent.remove(_key(key));
}

class ClassAccountStorage implements DraftStorage {
  ClassAccountStorage(this.parent, this.classId);
  final DraftStorage parent;
  final String classId;
  String _key(String key) => 'class.$classId.$key';
  @override
  Future<Map<String, dynamic>?> read(String key) => parent.read(_key(key));
  @override
  Future<void> write(String key, Map<String, dynamic> value) =>
      parent.write(_key(key), value);
  @override
  Future<void> remove(String key) => parent.remove(_key(key));
}
