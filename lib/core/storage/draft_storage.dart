import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

abstract interface class DraftStorage {
  Future<Map<String, dynamic>?> read(String key);
  Future<void> write(String key, Map<String, dynamic> value);
  Future<void> remove(String key);
}

/// Only drafts and explicitly labelled local demo data, never cloud authority.
class PreferencesDraftStorage implements DraftStorage {
  PreferencesDraftStorage(this.preferences, this.namespace);
  final SharedPreferences preferences;
  final String namespace;
  String _key(String key) => 'zoostudy.v1.$namespace.$key';
  @override
  Future<Map<String, dynamic>?> read(String key) async {
    final value = preferences.getString(_key(key));
    return value == null
        ? null
        : Map<String, dynamic>.from(jsonDecode(value) as Map);
  }

  @override
  Future<void> write(String key, Map<String, dynamic> value) async {
    if (!await preferences.setString(_key(key), jsonEncode(value))) {
      throw StateError('端末内への保存に失敗しました');
    }
  }

  @override
  Future<void> remove(String key) async {
    if (!await preferences.remove(_key(key))) {
      throw StateError('下書きを削除できませんでした');
    }
  }
}

/// Serializes writes so earlier autosaves cannot overwrite newer input or a clear.
class DraftSession {
  DraftSession(this.storage, this.key, {this.onStatus});
  final DraftStorage? storage;
  final String key;
  final void Function(String? error)? onStatus;
  Future<void> _queue = Future.value();
  String? error;
  Future<Map<String, dynamic>?> read() async => storage?.read(key);
  void save(Map<String, dynamic> data) {
    if (storage == null) return;
    _queue = _queue
        .then((_) => storage!.write(key, data))
        .then((_) {
          error = null;
          onStatus?.call(null);
        })
        .catchError((Object _) {
          error = '下書きを保存できませんでした';
          onStatus?.call(error);
        });
  }

  Future<void> clear() async {
    await _queue;
    await storage?.remove(key);
  }
}
