import 'package:flutter/material.dart';

import '../../../core/storage/draft_storage.dart';
import '../../../core/ui/zoo_ui.dart';
import '../../study/assignment_detail_screen.dart';
import '../../study/study_detector/study_records_screen.dart';
import '../../study/study_detector/study_record.dart';
import '../../study/study_detector/study_session.dart';
import '../domain/game_snapshot.dart';
import '../../study/demo_assignment_store.dart';
import '../../study/study_repository.dart';
import '../../study/teacher_assignments_screen.dart';
import 'presentation_scenario.dart';

/// Reuses the production teacher UI. Only its data source is a disposable script.
class TeacherDemoScreen extends StatefulWidget {
  const TeacherDemoScreen({super.key});
  @override
  State<TeacherDemoScreen> createState() => _TeacherDemoScreenState();
}

class _TeacherDemoScreenState extends State<TeacherDemoScreen> {
  late final _store = TeacherPresentationStore();
  int _step = 0;
  bool _complete = false;
  bool _opening = false;
  late final Future<void> _ready = _seed();

  Future<void> _seed() => _store
      .saveStudyRecord(
        StudyRecord.fromReport(
          'teacher-demo-study',
          SessionReport(
            DateTime.now().subtract(const Duration(minutes: 30)),
            const Duration(minutes: 20),
            [
              const StudySegment(
                Duration.zero,
                Duration(minutes: 20),
                StudyDecision(StudyState.material, '教材で学習'),
              ),
            ],
          ),
          subject: '算数',
          samples: 120,
          completed: true,
        ),
      )
      .then((_) {});

  Future<void> _open() async {
    if (_opening) return;
    setState(() => _opening = true);
    try {
      await _ready;
      if (!mounted) return;
      await Navigator.of(context).push<void>(
        MaterialPageRoute(
          builder: (_) => switch (_step) {
            0 => TeacherAssignmentsScreen(store: _store),
            1 => AssignmentDetailScreen(
              store: _store,
              assignmentId: _store.assignments.last.id,
              isTeacher: true,
              studentId: _store.studentId,
            ),
            _ => StudyRecordsScreen(store: _store, isTeacher: true),
          },
        ),
      );
      if (!mounted) return;
      if (_step == 0 && _store.assignments.isNotEmpty) {
        setState(() => _step = 1);
      } else if (_step == 1 &&
          _store.submissionFor(_store.assignments.last.id)?.status ==
              AssignmentState.approved) {
        setState(() => _step = 2);
      } else if (_step == 2) {
        final advice = await _store.loadStudyAdvice(teacher: true);
        if (mounted && advice.any((a) => a.published)) {
          setState(() => _complete = true);
        }
      }
    } finally {
      if (mounted) setState(() => _opening = false);
    }
  }

  @override
  void dispose() {
    _store.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('先生の発表デモ')),
    body: TerrainTexture(
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 600),
            child: SpritePanel(
              style: SpritePanelStyle.creamRound,
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Center(
                      child: ZooUiSprite(
                        part: ZooUiPart.encyclopediaRed,
                        scale: 4,
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      '先生として学びをサポート',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    const Text('課題を配り、提出を確認し、学習記録をもとにメッセージを届ける流れを体験します。'),
                    const SizedBox(height: 16),
                    for (final entry in [
                      '課題配布',
                      '提出の承認',
                      '学習記録・アドバイス',
                    ].asMap().entries)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        child: Row(
                          children: [
                            Icon(
                              entry.key < _step || _complete
                                  ? Icons.check_circle
                                  : entry.key == _step
                                  ? Icons.play_circle_outline
                                  : Icons.circle_outlined,
                              color: const Color(0xFF79664F),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                entry.value,
                                style: TextStyle(
                                  fontSize: 17,
                                  fontWeight: entry.key == _step
                                      ? FontWeight.bold
                                      : FontWeight.normal,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    const SizedBox(height: 16),
                    Text(
                      _complete
                          ? '先生のデモは完了です。生徒の頑張りを確認し、アドバイスを届けられました。'
                          : switch (_step) {
                              0 =>
                                '「課題を作成」から、入力済みの例を確認して配布します。配布後はこの案内へ戻ってください。',
                              1 => '生徒の回答例を確認し、承認します。承認後はこの案内へ戻ってください。',
                              _ => 'サンプルの学習記録を確認し、「アドバイス案を作成」から文章を確認して生徒へ送ります。送信後はこの案内へ戻ってください。',
                            },
                      style: const TextStyle(height: 1.7),
                    ),
                    const SizedBox(height: 16),
                    if (!_complete)
                      FilledButton(
                        onPressed: _opening ? null : _open,
                        child: Text(
                          _opening
                              ? '準備中…'
                              : switch (_step) {
                                  0 => '課題配布を体験する',
                                  1 => '提出を確認・承認する',
                                  _ => '学習記録とアドバイスを見る',
                                },
                        ),
                      ),
                    if (_complete)
                      OutlinedButton(
                        onPressed: () => Navigator.of(context).pushReplacement(
                          MaterialPageRoute<void>(
                            builder: (_) => const TeacherDemoScreen(),
                          ),
                        ),
                        child: const Text('最初から体験する'),
                      ),
                    const SizedBox(height: 12),
                    const Text(
                      '発表用のサンプルです。生徒の回答・学習記録はデモ用で、別端末とは通信しません。通常データには保存しません。',
                      style: TextStyle(fontSize: 12, height: 1.5),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

/// Local fixtures let the existing detail and advice screens work without a server.
class TeacherPresentationStore extends DemoAssignmentStore {
  TeacherPresentationStore()
    : super(studentId: 'presentation_student', studentName: 'デモ生徒');
  final _drafts = _PresentationDrafts();
  @override
  DraftStorage get drafts => _drafts;
  @override
  String get storageLabel => '発表デモ・保存しません';
  @override
  String get storageExplanation => '別端末とは通信しません。提出には生徒の回答例を使用します。';
  @override
  void publish(
    DemoAssignment assignment, {
    DemoStudyRole role = DemoStudyRole.teacher,
  }) {
    super.publish(assignment, role: role);
    final id = assignment.id.isEmpty ? assignments.last.id : assignment.id;
    if (submissionFor(id) == null) {
      super.submit(
        id,
        PresentationScenario.answer,
        role: DemoStudyRole.student,
      );
    }
  }

  @override
  Future<StudyAdvice> generateStudyAdvice(String studentId) async {
    final draft = await super.generateStudyAdvice(studentId);
    return StudyAdvice(
      id: draft.id,
      studentId: draft.studentId,
      createdAt: draft.createdAt,
      summary: draft.summary,
      teacherNote: draft.teacherNote,
      message: PresentationScenario.advice,
      source: draft.source,
    );
  }
}

/// Prefills the existing assignment form through its existing draft interface.
class _PresentationDrafts implements DraftStorage {
  final _values = <String, Map<String, dynamic>>{
    'new-assignment': {
      'title': PresentationScenario.title,
      'description': PresentationScenario.description,
      'subject': AssignmentSubject.other.name,
      'dueAt': PresentationScenario.assignment().dueAt.toIso8601String(),
      'requestId': PresentationScenario.assignmentId,
    },
  };
  @override
  Future<Map<String, dynamic>?> read(String key) async =>
      _values[key] == null ? null : Map.of(_values[key]!);
  @override
  Future<void> write(String key, Map<String, dynamic> value) async {
    _values[key] = Map.of(value);
  }

  @override
  Future<void> remove(String key) async {
    _values.remove(key);
  }
}
