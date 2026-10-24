import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/storage/request_id.dart';
import '../study_repository.dart';
import 'automatic_study_mode.dart';
import 'detector_engine.dart';
import 'platform_detector_engine.dart';
import 'study_session.dart';
import 'study_record.dart';
import 'study_record_journal.dart';

Future<void> recoverStudyRecord(StudyRepository store) async {
  final journal = StudyRecordJournal(store.drafts);
  final pending = await journal.read();
  if (pending != null) {
    await store.saveStudyRecord(pending);
    await journal.clear();
  }
}

class StudyModeScreen extends StatefulWidget {
  const StudyModeScreen({super.key, required this.store, this.engine});
  final StudyRepository store;
  final StudyDetectorEngine? engine;
  @override
  State<StudyModeScreen> createState() => _StudyModeScreenState();
}

class _StudyModeScreenState extends State<StudyModeScreen>
    with WidgetsBindingObserver {
  late final StudyDetectorEngine _engine =
      widget.engine ?? createStudyDetectorEngine();
  late final StudyRecordJournal _journal = StudyRecordJournal(
    widget.store.drafts,
  );
  final _selector = AutomaticStudyMode();
  final _clock = Stopwatch();
  final _setupClock = Stopwatch()..start();
  StudySession? _session;
  StudyMode? _mode;
  StudyRecord? _pending, _saved;
  String _id = newRequestId();
  String _subject = 'その他';
  String? _error;
  bool _ready = false, _reading = false, _working = false, _closing = false;
  bool _preparing = false;
  Duration get _elapsed => _clock.elapsed > const Duration(hours: 24)
      ? const Duration(hours: 24)
      : _clock.elapsed;
  bool _foreground = true, _consented = false, _recovering = true;
  int _generation = 0, _samples = 0, _lastCheckpoint = 0;
  Timer? _analysisTimer, _checkpointTimer;
  Future<void>? _inference;
  Future<void> _resource = Future.value();

  void _update(VoidCallback update) {
    if (mounted && !_closing) setState(update);
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _recover();
    _analysisTimer = Timer.periodic(
      const Duration(seconds: 3),
      (_) => _analyze(),
    );
    _checkpointTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (_session != null &&
          _pending == null &&
          _clock.isRunning &&
          !_working &&
          _elapsed.inSeconds - _lastCheckpoint >= 15) {
        _lastCheckpoint = _elapsed.inSeconds;
        _checkpoint();
      }
      if (_session != null &&
          _pending == null &&
          _elapsed >= const Duration(hours: 24)) {
        _finish();
      }
    });
  }

  Future<void> _recover() async {
    try {
      await recoverStudyRecord(widget.store);
      _update(() {
        _recovering = false;
        _error = null;
      });
    } catch (_) {
      _update(() => _error = '前回の学習記録を保存できませんでした。通信を確認して再試行してください。');
    }
  }

  Future<void> _queueCamera(Future<void> Function() action) {
    final next = _resource.then((_) => action());
    _resource = next.catchError((Object _) {});
    return next;
  }

  Future<void> _open({bool switchCamera = false}) async {
    if (_working || _recovering || _preparing) return;
    _update(() {
      _preparing = true;
      _consented = true;
      _ready = false;
      _error = null;
    });
    _generation++;
    try {
      await _queueCamera(() async {
        await _inference;
        if (_closing || !_foreground) return;
        if (switchCamera) {
          await _engine.switchCamera();
        } else {
          await _engine.suspend();
          await _engine.initialize();
        }
        if (_closing || !_foreground) {
          await _engine.suspend();
          return;
        }
        _update(() => _ready = true);
      });
      if (_session != null && _foreground) {
        await _engine.keepAwake(true);
        _session!.record(
          _elapsed,
          const StudyDecision(StudyState.unknown, '再開後の観測を確認中'),
        );
      }
      _analyze();
    } catch (_) {
      _update(() {
        _ready = false;
        _error = 'カメラ・判定モデルを準備できませんでした。カメラの許可と通信を確認して再試行してください。';
      });
    } finally {
      _update(() => _preparing = false);
    }
  }

  void _analyze() {
    if (!_ready ||
        !_foreground ||
        _closing ||
        _reading ||
        _working ||
        _pending != null ||
        _saved != null) {
      return;
    }
    _reading = true;
    final generation = _generation;
    final running = _session != null;
    final at = running ? _elapsed : _setupClock.elapsed;
    final latency = Stopwatch()..start();
    _inference = () async {
      try {
        final sample = await _engine.analyze(at, _mode);
        if (_closing || !mounted || !_foreground || generation != _generation) {
          return;
        }
        if (latency.elapsed > const Duration(seconds: 8)) {
          if (running) {
            _session?.record(
              _elapsed,
              const StudyDecision(StudyState.unknown, '観測結果が古いため判定保留'),
            );
          } else {
            _selector.reset();
          }
          return;
        }
        if (running) {
          _samples++;
          _session?.record(_elapsed, sample.decision);
        } else if (_mode == null) {
          final mode = _selector.observe(face: sample.face, desk: sample.desk);
          _update(() => _mode = mode);
        }
      } catch (_) {
        if (!_closing && generation == _generation && _foreground) {
          if (running) {
            _session?.record(
              _elapsed,
              const StudyDecision(StudyState.unknown, '撮影・判定を確認できませんでした'),
            );
          } else {
            _selector.reset();
            _update(() => _error = '映り方を確認できません。顔または教材と手元が映るように位置を調整してください。');
          }
        }
      } finally {
        _reading = false;
        _update(() {});
      }
    }();
  }

  Future<void> _start() async {
    if (!_ready || _mode == null || _reading || _working) return;
    _update(() => _working = true);
    try {
      await _engine.reset();
      if (!_foreground || _closing) return;
      _id = newRequestId();
      _samples = 0;
      _lastCheckpoint = 0;
      _clock.reset();
      _session = StudySession(DateTime.now(), mode: _mode!);
      await _journal.write(_record(completed: false));
      await _engine.keepAwake(true);
      _clock.start();
      _update(() => _error = null);
    } catch (_) {
      _session = null;
      _update(() => _error = '開始状態を保存できませんでした。再試行してください。');
    } finally {
      _update(() => _working = false);
    }
    _analyze();
  }

  StudyRecord _record({required bool completed}) => StudyRecord.fromReport(
    _id,
    _session!.snapshot(_elapsed),
    subject: _subject,
    samples: _samples,
    completed: completed,
  );
  Future<void> _checkpoint() async {
    final session = _session;
    if (session == null || _working || _pending != null || !_clock.isRunning) {
      return;
    }
    try {
      await _journal.write(_record(completed: false));
    } catch (_) {
      _update(() => _error = '途中の記録を保存できません。終了時にもう一度保存します。');
    }
  }

  Future<void> _finish({bool exit = false}) async {
    if (_working) return;
    if (_session == null && _pending == null) return;
    _update(() => _working = true);
    _generation++;
    _clock.stop();
    if (_pending == null) {
      _session!.finish(_elapsed);
      _pending = _record(completed: true);
    }
    try {
      try {
        await _journal.write(_pending!);
      } finally {
        // Ending a session always stops the camera, even when disk saving fails.
        await _queueCamera(() async {
          await _inference;
          await _engine.suspend();
        });
      }
      await widget.store.saveStudyRecord(_pending!);
      await _journal.clear();
      _update(() {
        _saved = _pending;
        _pending = null;
        _session = null;
        _ready = false;
        _error = null;
      });
      if (exit && mounted) {
        _update(() => _working = false);
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) Navigator.pop(context);
        });
      }
    } catch (_) {
      _update(() => _error = '記録を保存できませんでした。通信を確認して「保存を再試行」を押してください。');
    } finally {
      _update(() => _working = false);
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.inactive && _session == null && _preparing) {
      return;
    }
    final active = state == AppLifecycleState.resumed;
    if (active == _foreground) return;
    _foreground = active;
    _generation++;
    if (!active) {
      _ready = false;
      if (_session != null && _pending == null) {
        _session!.record(
          _elapsed,
          const StudyDecision(StudyState.suspended, 'アプリが画面外'),
          expires: false,
        );
        _checkpoint();
      }
      unawaited(
        _queueCamera(() async {
          await _inference;
          await _engine.suspend();
        }).catchError((Object _) {}),
      );
    } else if (_consented && _saved == null && _pending == null) {
      unawaited(
        _resource.then((_) async {
          if (_foreground && !_closing && _saved == null && _pending == null) {
            await _open();
          }
        }),
      );
    }
  }

  @override
  void dispose() {
    if (_session != null && _pending == null) {
      _clock.stop();
      unawaited(
        _journal.write(_record(completed: false)).catchError((Object _) {}),
      );
    }
    _engine.cancel();
    _setupClock.stop();
    _closing = true;
    _generation++;
    _analysisTimer?.cancel();
    _checkpointTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    unawaited(
      _queueCamera(() async {
        await _inference;
        await _engine.close();
      }).catchError((Object _) {}),
    );
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: _session == null && _pending == null && !_working,
    onPopInvokedWithResult: (didPop, _) {
      if (!didPop) _finish(exit: true);
    },
    child: Scaffold(
      appBar: AppBar(title: const Text('勉強モード')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 640),
          child: ListView(
            padding: const EdgeInsets.all(24),
            children: [
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: Text(_error!),
                ),
              if (_working || _recovering || _preparing)
                const LinearProgressIndicator(),
              if (_recovering && _error != null)
                TextButton(onPressed: _recover, child: const Text('再試行')),
              if (_saved != null) ...[
                const Text('学習記録を保存しました', style: TextStyle(fontSize: 24)),
                Text(
                  '学習モードの利用時間：${formatDuration(Duration(milliseconds: _saved!.activeMs))}',
                ),
                FilledButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('戻る'),
                ),
              ] else if (_session != null || _pending != null) ...[
                const SizedBox(height: 80),
                const Center(child: Icon(Icons.menu_book_outlined, size: 64)),
                const SizedBox(height: 24),
                Center(
                  child: Text(
                    _pending != null
                        ? '保存待ち'
                        : !_foreground || !_ready
                        ? '計測一時停止中'
                        : '勉強中',
                    style: const TextStyle(
                      fontSize: 36,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(height: 48),
                FilledButton(
                  onPressed: _working ? null : () => _finish(),
                  child: Text(_pending != null ? '保存を再試行' : '終了して保存'),
                ),
                if (!_ready && _pending == null && !_working)
                  TextButton(
                    onPressed: () => _open(),
                    child: const Text('カメラを再接続'),
                  ),
              ] else ...[
                const Text(
                  'はじめに映り方を確認します',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                const Text('カメラで顔または教材と手元を確認し、判定方式を自動で選びます。勉強中は映像を表示しません。'),
                const SizedBox(height: 12),
                const Text(
                  '映像・写真・音声は記録として保存・送信しません。端末内で判定し、科目・開始日時・利用時間・判定の集計を保存します。先生は記録を確認できます。',
                ),
                const SizedBox(height: 8),
                const Text(
                  '姿勢や手の動きは参考情報で、理解度・集中度の評価ではありません。画面を閉じた間は計測を一時停止します。初回は判定モデルのダウンロードが必要です。',
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  initialValue: _subject,
                  decoration: const InputDecoration(labelText: '取り組む科目'),
                  items: [
                    for (final s in AssignmentSubject.values)
                      DropdownMenuItem(value: s.label, child: Text(s.label)),
                  ],
                  onChanged: _working
                      ? null
                      : (value) => _update(() => _subject = value!),
                ),
                const SizedBox(height: 16),
                if (!_engine.supported)
                  const Text('カメラによる勉強判定は現在Android版で利用できます。')
                else if (!_ready)
                  FilledButton(
                    onPressed: _recovering || _preparing ? null : () => _open(),
                    child: Text(_preparing ? 'カメラ・判定モデルを準備中…' : '確認してカメラを準備'),
                  )
                else ...[
                  SizedBox(
                    height: 260,
                    child: ClipRect(child: _engine.preview()),
                  ),
                  Text(
                    _mode == null
                        ? '顔または教材と手元が映る位置で数秒お待ちください。両方が映る場合は、どちらかを中心に映してください。'
                        : '自動選択：${_mode == StudyMode.face ? "顔モード" : "手元モード"}',
                  ),
                  if (_engine.canSwitchCamera)
                    TextButton(
                      onPressed: _reading
                          ? null
                          : () {
                              _mode = null;
                              _selector.reset();
                              _open(switchCamera: true);
                            },
                      child: const Text('前後のカメラを切り替える'),
                    ),
                  TextButton(
                    onPressed: _reading
                        ? null
                        : () {
                            _selector.reset();
                            _update(() {
                              _mode = null;
                              _error = null;
                            });
                          },
                    child: const Text('映り方を再確認'),
                  ),
                  FilledButton(
                    onPressed: _mode == null || _reading || _working
                        ? null
                        : _start,
                    child: const Text('勉強を開始'),
                  ),
                ],
              ],
            ],
          ),
        ),
      ),
    ),
  );
}
