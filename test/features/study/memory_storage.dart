import 'dart:convert';

import 'package:zoo_study/core/storage/draft_storage.dart';

class MemoryStorage implements DraftStorage {
  final data = <String, String>{};
  bool fail = false;
  int writes = 0;
  @override
  Future<Map<String, dynamic>?> read(String key) async =>
      data[key] == null ? null : jsonDecode(data[key]!) as Map<String, dynamic>;
  @override
  Future<void> write(String key, Map<String, dynamic> value) async {
    if (fail) throw StateError('Disk full');
    writes++;
    data[key] = jsonEncode(value);
  }

  @override
  Future<void> remove(String key) async {
    data.remove(key);
  }
}
