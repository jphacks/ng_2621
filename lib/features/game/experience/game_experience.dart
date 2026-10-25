import '../../../core/storage/game_preferences_storage.dart';

import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../../../core/storage/draft_storage.dart';
import '../domain/game_snapshot.dart';

/// Presentation event only. The producer must supply an authoritative receipt.
class ConfirmedGameReward {
  ConfirmedGameReward({
    required this.organizationId,
    required this.studentId,
    required this.transactionId,
    required this.amount,
    required this.source,
  }) {
    if ([
          organizationId,
          studentId,
          transactionId,
          source,
        ].any((s) => s.isEmpty) ||
        amount <= 0) {
      throw const FormatException('Invalid confirmed reward');
    }
  }
  final String organizationId, studentId, transactionId, source;
  final int amount;
}

/// UI preferences and receipt deduplication, never a currency ledger.
class GameExperience extends ChangeNotifier {
  GameExperience({this.storage});
  final DraftStorage? storage;
  String? goalId, persistenceError;
  final List<ConfirmedGameReward> _pending = [];
  final Set<String> _seen = {};
  String? _organization, _student;
  GameSnapshot? _snapshot;
  bool _disposed = false, _historyReady = false;
  Future<void> _queue = Future.value();
  ConfirmedGameReward? get reward => _pending.isEmpty ? null : _pending.first;
  String get _key =>
      'game.experience.v1.${jsonEncode([_organization, _student])}';
  bool get ready => _snapshot != null;
  Future<void> _serial(Future<void> Function() action) {
    final result = _queue.then((_) async {
      if (!_disposed) await action();
    });
    _queue = result.catchError((Object _) {});
    return result;
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  Future<void> _persist() async {
    try {
      await storage?.write(_key, {'goalId': goalId, 'seen': _seen.toList()});
      persistenceError = null;
    } catch (_) {
      persistenceError = 'ゲームの目標・通知設定を保存できませんでした';
    }
  }

  Future<void> receive(GameSnapshot snapshot) => _serial(() async {
    if (_snapshot != null &&
        (snapshot.organizationId != _organization ||
            snapshot.studentId != _student)) {
      throw const FormatException('Experience identity changed');
    }
    if (_snapshot != null && snapshot.revision <= _snapshot!.revision) return;
    final initial = _snapshot == null;
    if (initial) {
      _organization = snapshot.organizationId;
      _student = snapshot.studentId;
      try {
        final data = await storage?.read(_key);
        goalId = data?['goalId'] as String?;
        _seen.addAll(List<String>.from(data?['seen'] as List? ?? []));
      } catch (_) {
        persistenceError = 'ゲーム設定を読み込めませんでした';
        _notify();
        return;
      }
    }
    _snapshot = snapshot;
    for (final receipt in snapshot.rewards) {
      final event = ConfirmedGameReward(
        organizationId: snapshot.organizationId,
        studentId: receipt.studentId,
        transactionId: 'assignment:${receipt.transactionId}',
        amount: receipt.amount,
        source: '課題',
      );
      _accept(event, baseline: initial);
    }
    await _persist();
    _notify();
  });
  void _accept(ConfirmedGameReward event, {required bool baseline}) {
    if (event.organizationId != _organization || event.studentId != _student) {
      throw const FormatException('Reward identity mismatch');
    }
    if (!_seen.add(event.transactionId) || baseline) return;
    _pending.add(event);
  }

  /// The first successful history fetch establishes a baseline, even after errors.
  Future<void> receiveStudyHistory(List<ConfirmedGameReward> events) =>
      _serial(() async {
        if (_snapshot == null) return;
        // Validate the whole batch before changing the deduplication state.
        for (final event in events) {
          if (event.organizationId != _organization ||
              event.studentId != _student) {
            throw const FormatException('Reward identity mismatch');
          }
        }
        for (final event in events) {
          _accept(event, baseline: !_historyReady);
        }
        _historyReady = true;
        await _persist();
        _notify();
      });
  Future<void> setGoal(String? id) => _serial(() async {
    if (_snapshot == null) return;
    goalId = id;
    final target = storage;
    if (target is GamePreferencesStorage) {
      try {
        await target.writeGoal(_key, id);
        persistenceError = null;
      } catch (_) {
        persistenceError = '目標を保存できませんでした。再試行してください';
      }
    } else {
      await _persist();
    }
    _notify();
  });
  void dismissReward(String id) {
    if (reward?.transactionId != id) return;
    _pending.removeAt(0);
    _notify();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
