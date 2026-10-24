import 'dart:async';

import 'package:flutter/foundation.dart';

import '../domain/game_repository.dart';
import '../domain/game_snapshot.dart';
import '../domain/game_notice.dart';

class GameSession extends ChangeNotifier {
  GameSession(this.repository) {
    refresh();
  }

  final GameRepository repository;
  GameSnapshot? snapshot;
  bool loading = true;
  bool failed = false;
  StreamSubscription<GameSnapshot>? _subscription;
  int _generation = 0;
  bool _disposed = false;
  final _noticeTracker = GameNoticeTracker();
  final _notices = <GameNotice>[];

  List<GameNotice> get pendingNotices => List.unmodifiable(_notices);
  GameNotice? get currentNotice => _notices.isEmpty ? null : _notices.first;

  void dismissNotice(String id) {
    if (_notices.isEmpty || _notices.first.id != id) return;
    _notices.removeAt(0);
    notifyListeners();
  }

  void refresh() {
    final generation = ++_generation;
    _subscription?.cancel();
    loading = true;
    failed = false;
    notifyListeners();
    void fail() {
      if (_disposed || generation != _generation) return;
      loading = false;
      failed = true;
      notifyListeners();
    }

    try {
      _subscription = repository.watchGameState().listen(
        (incoming) {
          if (_disposed || generation != _generation) return;
          final current = snapshot;
          if (current != null) {
            if (incoming.organizationId != current.organizationId ||
                incoming.studentId != current.studentId) {
              fail();
              return;
            }
            if (incoming.revision <= current.revision) {
              loading = false;
              failed = false;
              notifyListeners();
              return;
            }
          }
          _notices.addAll(_noticeTracker.receive(incoming));
          snapshot = incoming;
          loading = false;
          failed = false;
          notifyListeners();
        },
        onError: (Object error, StackTrace stackTrace) => fail(),
        onDone: () {
          if (_disposed || generation != _generation) return;
          loading = false;
          notifyListeners();
        },
      );
    } catch (_) {
      fail();
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _generation++;
    _subscription?.cancel();
    super.dispose();
  }
}
