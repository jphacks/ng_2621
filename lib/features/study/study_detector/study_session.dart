enum StudyMode {
  desk('手元モード'),
  face('顔モード（テスト）');

  final String label;
  const StudyMode(this.label);
  List<StudyState> get states => this == StudyMode.face
      ? const [
          StudyState.facePosture,
          StudyState.faceCheck,
          StudyState.unknown,
          StudyState.suspended,
        ]
      : const [
          StudyState.studying,
          StudyState.material,
          StudyState.device,
          StudyState.unknown,
          StudyState.suspended,
        ];
}

enum StudyState {
  studying('学習推定'),
  facePosture('顔モード・姿勢継続推定'),
  faceCheck('顔モード・姿勢確認中'),
  material('教材あり・行動確認中'),
  device('端末の用途未確認'),
  unknown('判定保留'),
  suspended('画面外・計測停止');

  final String label;
  const StudyState(this.label);
}

class StudyDecision {
  final StudyState state;
  final String reason;
  final int score;
  final bool observed;
  const StudyDecision(
    this.state,
    this.reason, [
    this.score = 0,
    this.observed = true,
  ]);
  bool get rewardEvidence =>
      state != StudyState.unknown && state != StudyState.suspended;
}

class ActivitySample {
  final Duration at;
  final bool paper;
  final bool computer;
  final bool phone;
  final bool handAvailable;
  final bool handNearText;
  final bool handMoving;
  final bool recognitionAvailable;
  const ActivitySample(
    this.at, {
    this.paper = false,
    this.computer = false,
    this.phone = false,
    this.handAvailable = false,
    this.handNearText = false,
    this.handMoving = false,
    this.recognitionAvailable = true,
  });
}

class ActivityClassifier {
  final List<ActivitySample> _recent = [];
  void reset() => _recent.clear();

  StudyDecision classify(ActivitySample sample) {
    _recent.removeWhere(
      (item) => sample.at - item.at > const Duration(seconds: 15),
    );
    _recent.add(sample);
    if (_recent.length > 4) _recent.removeAt(0);
    if (!sample.recognitionAvailable) {
      reset();
      return const StudyDecision(
        StudyState.unknown,
        '認識に失敗したため学習時間へ加算しません',
        0,
        false,
      );
    }
    // A device may itself be the source of OCR text. Do not call that paper study.
    if ((sample.computer || sample.phone) &&
        (!sample.paper || !sample.handNearText)) {
      final device = sample.phone && sample.computer
          ? 'スマホとPC'
          : sample.phone
          ? 'スマホ'
          : 'PC';
      return StudyDecision(StudyState.device, '$deviceを検出：調べ学習か他の用途かは確認できません');
    }
    if (!sample.paper) {
      return const StudyDecision(
        StudyState.unknown,
        '教材を確認できません（非学習との断定ではありません）',
      );
    }
    if (!sample.handAvailable) {
      return const StudyDecision(
        StudyState.material,
        '教材はありますが、手の認識を利用できません',
        25,
      );
    }
    final related = _recent
        .where((item) => item.paper && item.handNearText && item.handAvailable)
        .toList();
    final motion = related
        .where(
          (item) =>
              item.handMoving &&
              sample.at - item.at <= const Duration(seconds: 12),
        )
        .isNotEmpty;
    final sustained =
        related.length >= 3 &&
        related.last.at - related.first.at >= const Duration(seconds: 5);
    final score =
        25 +
        (sample.handNearText ? 20 : 0) +
        (motion ? 30 : 0) +
        (sustained ? 25 : 0);
    if (sample.handNearText && motion && sustained) {
      return StudyDecision(
        StudyState.studying,
        '本または文字付近で手を継続検出し、最近の位置変化を確認（筆記・理解の断定ではありません）',
        score,
      );
    }
    return StudyDecision(
      StudyState.material,
      sample.handNearText ? '教材付近に手を検出：動きと継続を確認中' : '教材のみ確認：読書・思考・放置をまだ区別できません',
      score,
    );
  }
}

class StudySegment {
  final Duration start;
  final Duration end;
  final StudyDecision decision;
  const StudySegment(this.start, this.end, this.decision);
  Duration get duration => end - start;
}

class RewardInterval {
  const RewardInterval(this.start, this.end);
  final Duration start, end;
}

class SessionReport {
  final DateTime startedAt;
  final Duration elapsed;
  final List<StudySegment> segments;
  final StudyMode mode;
  final List<RewardInterval> rewardIntervals;
  const SessionReport(
    this.startedAt,
    this.elapsed,
    this.segments, {
    this.mode = StudyMode.desk,
    this.rewardIntervals = const [],
  });
  Duration total(StudyState state) => segments
      .where((item) => item.decision.state == state)
      .fold(Duration.zero, (sum, item) => sum + item.duration);
}

// All accounting uses elapsed monotonic time, independent of the wall clock.
class StudySession {
  final StudyMode mode;
  final DateTime startedAt;
  final List<StudySegment> _segments = [];
  Duration _cursor = Duration.zero;
  Duration? _validUntil;
  Duration? _rewardUntil, _lastEvidence;
  final _rewardIntervals = <RewardInterval>[];
  Duration? _finishedAt;
  StudyDecision _current = const StudyDecision(
    StudyState.unknown,
    '開始直後：最初の分析を待っています',
    0,
    false,
  );
  static const stale = StudyDecision(
    StudyState.unknown,
    '新しい認識結果がないため判定保留',
    0,
    false,
  );

  StudySession(this.startedAt, {this.mode = StudyMode.desk});

  void _append(Duration end) {
    if (end <= _cursor) return;
    final rewardEnd = _rewardUntil == null
        ? _cursor
        : (end < _rewardUntil! ? end : _rewardUntil!);
    if (rewardEnd > _cursor) {
      if (_rewardIntervals.isNotEmpty && _rewardIntervals.last.end == _cursor) {
        final previous = _rewardIntervals.removeLast();
        _rewardIntervals.add(RewardInterval(previous.start, rewardEnd));
      } else {
        _rewardIntervals.add(RewardInterval(_cursor, rewardEnd));
      }
    }
    if (_segments.isNotEmpty &&
        _segments.last.decision.state == _current.state &&
        _segments.last.decision.reason == _current.reason) {
      final old = _segments.removeLast();
      _segments.add(StudySegment(old.start, end, _current));
    } else {
      _segments.add(StudySegment(_cursor, end, _current));
    }
    _cursor = end;
  }

  void _advance(Duration now) {
    if (now < _cursor) throw ArgumentError('Elapsed time must be monotonic');
    if (_validUntil != null && now >= _validUntil!) {
      _append(_validUntil!);
      _current = stale;
      _lastEvidence = null;
      _validUntil = null;
    }
    _append(now);
  }

  void record(Duration now, StudyDecision decision, {bool expires = true}) {
    if (_finishedAt != null) return;
    _advance(now);
    _current = decision;
    _rewardUntil = null;
    if (!decision.observed || decision.state == StudyState.suspended) {
      _lastEvidence = null;
    }
    if (decision.rewardEvidence && decision.observed) {
      _lastEvidence = now;
      _rewardUntil = now + const Duration(seconds: 8);
    } else if (decision.state == StudyState.unknown &&
        decision.observed &&
        _lastEvidence != null) {
      final grace = _lastEvidence! + const Duration(seconds: 30);
      final fresh = now + const Duration(seconds: 8);
      if (grace > now) _rewardUntil = grace < fresh ? grace : fresh;
    }
    // A frozen/failed inference must never keep granting study time indefinitely.
    _validUntil = expires ? now + const Duration(seconds: 8) : null;
  }

  SessionReport snapshot(Duration now) {
    final at = _finishedAt ?? now;
    _advance(at);
    return SessionReport(
      startedAt,
      at,
      List.unmodifiable(_segments),
      mode: mode,
      rewardIntervals: List.unmodifiable(_rewardIntervals),
    );
  }

  bool rewardCounting(Duration now) {
    snapshot(now);
    return _rewardUntil != null && now < _rewardUntil!;
  }

  StudyDecision current(Duration now) {
    snapshot(now);
    return _current;
  }

  SessionReport finish(Duration now) {
    if (_finishedAt == null) {
      _advance(now);
      _finishedAt = now;
    }
    return snapshot(_finishedAt!);
  }
}

String formatDuration(Duration duration) {
  final seconds = duration.inSeconds;
  return '${(seconds ~/ 3600).toString().padLeft(2, '0')}:'
      '${(seconds ~/ 60 % 60).toString().padLeft(2, '0')}:'
      '${(seconds % 60).toString().padLeft(2, '0')}';
}

String formatClock(DateTime time) =>
    '${time.hour.toString().padLeft(2, '0')}:'
    '${time.minute.toString().padLeft(2, '0')}:${time.second.toString().padLeft(2, '0')}';
