import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../../core/storage/game_preferences_storage.dart';

/// Only cosmetic game settings; wallets and ownership remain server-only.
class CloudGamePreferences implements GamePreferencesStorage {
  CloudGamePreferences({
    required this.uid,
    required this.organizationId,
    FirebaseFirestore? firestore,
    FirebaseAuth? auth,
  }) : _db = firestore ?? FirebaseFirestore.instance,
       _auth = auth ?? FirebaseAuth.instance;
  final String uid, organizationId;
  final FirebaseFirestore _db;
  final FirebaseAuth _auth;
  DocumentReference<Map<String, dynamic>> _document(String key) {
    if (_auth.currentUser?.uid != uid ||
        key != 'game.experience.v1.${jsonEncode([organizationId, uid])}') {
      throw StateError('アカウントが変更されました');
    }
    return _db.collection('gamePreferences').doc(uid);
  }

  @override
  Future<Map<String, dynamic>?> read(String key) async {
    final result = await _document(key)
        .get(const GetOptions(source: Source.server))
        .timeout(const Duration(seconds: 20));
    if (_auth.currentUser?.uid != uid) throw StateError('アカウントが変更されました');
    final value = result.data();
    return value == null
        ? null
        : {'goalId': value['goalId'], 'seen': _seenIds(value['seen'])};
  }

  @override
  Future<void> write(String key, Map<String, dynamic> value) async {
    final incoming = _seenIds(value['seen']);
    final reference = _document(key);
    await _db
        .runTransaction((tx) async {
          final saved = await tx.get(reference);
          final seen = <String>{
            ..._seenIds(saved.data()?['seen']),
            ...incoming,
          }.toList();
          tx.set(reference, {
            'goalId': saved.data()?['goalId'],
            'seen': seen
                .skip(seen.length > 2000 ? seen.length - 2000 : 0)
                .toList(),
          });
        })
        .timeout(const Duration(seconds: 20));
  }

  @override
  Future<void> writeGoal(String key, String? goalId) async {
    final reference = _document(key);
    await _db
        .runTransaction((tx) async {
          final saved = await tx.get(reference);
          tx.set(reference, {
            'goalId': goalId,
            'seen': _seenIds(saved.data()?['seen']),
          });
        })
        .timeout(const Duration(seconds: 20));
  }

  List<String> _seenIds(Object? value) {
    final ids = value is List
        ? value.whereType<String>().where((id) => id.length <= 512).toList()
        : <String>[];
    return ids.length > 2000 ? ids.sublist(ids.length - 2000) : ids;
  }

  @override
  Future<void> remove(String key) => _document(key).delete();
}
