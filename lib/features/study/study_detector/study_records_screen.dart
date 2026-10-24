import 'package:flutter/material.dart';

import '../study_repository.dart';
import 'study_mode_screen.dart' show recoverStudyRecord;
import 'study_record.dart';
import 'study_session.dart';

class StudyRecordsScreen extends StatefulWidget {
  const StudyRecordsScreen({
    super.key,
    required this.store,
    this.isTeacher = false,
  });
  final StudyRepository store;
  final bool isTeacher;
  @override
  State<StudyRecordsScreen> createState() => _StudyRecordsScreenState();
}

class _StudyRecordsScreenState extends State<StudyRecordsScreen> {
  late Future<List<StudyRecord>> _records = _load();
  Future<List<StudyRecord>> _load() async {
    if (!widget.isTeacher) await recoverStudyRecord(widget.store);
    return widget.store.loadStudyRecords();
  }

  void _refresh() => setState(() => _records = _load());
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(widget.isTeacher ? '生徒の学習記録' : '学習記録'),
      actions: [
        IconButton(
          onPressed: _refresh,
          tooltip: '再読み込み',
          icon: const Icon(Icons.refresh),
        ),
      ],
    ),
    body: FutureBuilder<List<StudyRecord>>(
      future: _records,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('学習記録を読み込めませんでした'),
                TextButton(onPressed: _refresh, child: const Text('再試行')),
              ],
            ),
          );
        }
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final records = snapshot.data!;
        return Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 700),
            child: ListView(
              padding: const EdgeInsets.all(24),
              children: [
                Text(widget.store.storageExplanation),
                const SizedBox(height: 12),
                if (widget.isTeacher)
                  const Text(
                    '時間と判定は生徒の端末からの記録です。姿勢・手の動きは参考情報で、学習内容や集中度の評価ではありません。',
                  ),
                if (records.isEmpty)
                  const Padding(
                    padding: EdgeInsets.all(24),
                    child: Text('学習記録はまだありません'),
                  ),
                for (final record in records)
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (widget.isTeacher)
                            Text(
                              record.studentName,
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                          Text(
                            '${record.startedAt.toLocal().toString().substring(0, 16)}・${record.subject}',
                          ),
                          Text(
                            '学習モードの利用時間：${formatDuration(Duration(milliseconds: record.activeMs))}',
                          ),
                          Text(record.completed ? '終了して保存' : '中断時点までの記録'),
                          if (widget.isTeacher) ...[
                            Text(
                              '判定方式：${record.mode == StudyMode.face ? "顔の姿勢" : "教材と手元"}',
                            ),
                            Text('観測回数：${record.samples}回'),
                            for (final state in StudyState.values)
                              if ((record.stateMs[state.name] ?? 0) > 0)
                                Text(
                                  '${state.label}：${formatDuration(Duration(milliseconds: record.stateMs[state.name]!))}',
                                ),
                          ],
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    ),
  );
}
