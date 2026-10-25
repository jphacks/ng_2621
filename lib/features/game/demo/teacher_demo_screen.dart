import 'package:flutter/material.dart';

import '../../../core/storage/draft_storage.dart';
import '../../../core/ui/zoo_ui.dart';
import '../../auth/data/school_account_api.dart';
import '../../zoo/presentation/zoo_screen.dart';
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
  late final _store = TeacherPresentationStore()..onProgress = _progress;
  final _accounts = LocalSchoolAccountApi(null);
  late final Future<void> _ready = _prepare();
  int _step = 0;

  Future<void> _prepare() async {
    await _accounts.call('createManagedClass', {'name': 'ひまわり組'});
    await _store.saveStudyRecord(
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
    );
  }

  void _progress() {
    if (!mounted) return;
    setState(() {
      _step = _store.adviceSent
          ? 3
          : _store.assignments.any(
              (a) =>
                  _store.submissionFor(a.id)?.status ==
                  AssignmentState.approved,
            )
          ? 2
          : _store.assignments.isNotEmpty
          ? 1
          : 0;
    });
  }

  void _restart() => Navigator.of(context).pushReplacement(
    MaterialPageRoute<void>(builder: (_) => const TeacherDemoScreen()),
  );
  @override
  void dispose() {
    _store.onProgress = null;
    _store.dispose();
    super.dispose();
  }

  Widget _assignments(BuildContext context) => Column(
    children: [
      Padding(
        padding: const EdgeInsets.all(12),
        child: DropdownButtonFormField<String>(
          initialValue: 'demo-class',
          isExpanded: true,
          decoration: const InputDecoration(
            labelText: '課題・学習記録の対象クラス',
            border: OutlineInputBorder(),
          ),
          items: const [
            DropdownMenuItem(value: 'demo-class', child: Text('ひまわり組')),
          ],
          onChanged: (_) {},
        ),
      ),
      Expanded(child: TeacherAssignmentsScreen(store: _store)),
    ],
  );

  @override
  Widget build(BuildContext context) => FutureBuilder<void>(
    future: _ready,
    builder: (context, snapshot) {
      if (snapshot.connectionState != ConnectionState.done) {
        return const Scaffold(body: Center(child: CircularProgressIndicator()));
      }
      if (snapshot.hasError) {
        return Scaffold(
          body: Center(
            child: TextButton(
              onPressed: _restart,
              child: const Text('デモを準備し直す'),
            ),
          ),
        );
      }
      return Scaffold(
        body: SafeArea(
          bottom: false,
          child: Column(
            children: [
              ConstrainedBox(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.sizeOf(context).height * .18,
                ),
                child: SingleChildScrollView(
                  child: WoodPanel(
                    originalSheet: true,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 10,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            _step == 3
                                ? '先生の発表デモ・完了'
                                : '先生の発表デモ ${_step + 1}/3',
                            style: const TextStyle(fontSize: 11),
                          ),
                          Text(
                            [
                              '① 課題を配布する',
                              '② 提出を確認して承認する',
                              '③ 学習記録を見てアドバイスを送る',
                              '先生のサポートを体験できました',
                            ][_step],
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            [
                              '下の「課題」→ クラスを選択 →「課題を作成」。例文を確認して配布しましょう。',
                              '配布した課題の「提出内容を確認」から、回答例を読んで承認しましょう。',
                              '「課題」→「生徒の学習記録」から記録を確認し、アドバイス案を編集・送信しましょう。',
                              '通常データには保存していません。下の画面はそのまま操作できます。',
                            ][_step],
                            style: const TextStyle(fontSize: 11, height: 1.5),
                          ),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              if (_step == 3)
                                TextButton(
                                  onPressed: _restart,
                                  child: const Text('最初から'),
                                ),
                              TextButton(
                                onPressed: () =>
                                    Navigator.of(context).maybePop(),
                                child: const Text('デモを終了'),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              Expanded(
                child: ZooScreen(
                  isTeacher: true,
                  gameRepository: _store,
                  assignmentStore: _store,
                  schoolAccountApi: _accounts,
                  teacherAssignmentsBuilder: _assignments,
                  accountName: 'デモ先生',
                  accountClassName: 'ひまわり組',
                  accountStorageDescription:
                      '発表用の回答・学習記録です。別端末とは通信せず、保存データには影響しません。',
                  onSignOut: () async {
                    await Navigator.of(context).maybePop();
                  },
                ),
              ),
            ],
          ),
        ),
      );
    },
  );
}

/// Local fixtures let the existing detail and advice screens work without a server.
class TeacherPresentationStore extends DemoAssignmentStore {
  TeacherPresentationStore()
    : super(studentId: 'presentation_student', studentName: 'デモ生徒');
  final _drafts = _PresentationDrafts();
  VoidCallback? onProgress;
  bool adviceSent = false;
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
    onProgress?.call();
  }

  @override
  int review(
    String id, {
    required DemoStudyRole role,
    required bool approve,
    String feedback = '',
    String? studentId,
    int? expectedVersion,
  }) {
    final result = super.review(
      id,
      role: role,
      approve: approve,
      feedback: feedback,
      studentId: studentId,
      expectedVersion: expectedVersion,
    );
    onProgress?.call();
    return result;
  }

  @override
  Future<void> publishStudyAdvice(String id, String message) async {
    await super.publishStudyAdvice(id, message);
    adviceSent = true;
    onProgress?.call();
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
