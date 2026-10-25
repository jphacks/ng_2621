import 'package:flutter/material.dart';

import '../study_repository.dart';

class StudyAdvicePanel extends StatefulWidget {
  const StudyAdvicePanel({
    super.key,
    required this.store,
    required this.teacher,
  });
  final StudyRepository store;
  final bool teacher;
  @override
  State<StudyAdvicePanel> createState() => _StudyAdvicePanelState();
}

class _StudyAdvicePanelState extends State<StudyAdvicePanel> {
  late Future<List<StudyAdvice>> _items = _load();
  String? _student;
  bool _busy = false;
  String? _error;
  Future<List<StudyAdvice>> _load() =>
      widget.store.loadStudyAdvice(teacher: widget.teacher);
  void _refresh() => setState(() {
    _items = _load();
  });
  Future<void> _generate() async {
    final student = _student ?? widget.store.students.firstOrNull?.id;
    if (student == null) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final advice = await widget.store.generateStudyAdvice(student);
      if (!mounted) return;
      _refresh();
      await _review(advice);
    } catch (e) {
      if (mounted) {
        setState(
          () => _error = e is StudyFailure
              ? e.message
              : '作成できませんでした。通信を確認して再試行してください。',
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _review(StudyAdvice advice) async {
    var message = advice.message;
    String? error;
    bool saving = false;
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, update) => AlertDialog(
          title: const Text('内容を確認して生徒へ送る'),
          content: SizedBox(
            width: 540,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    advice.source == 'template'
                        ? '定型文プレビュー（AI未使用）'
                        : 'AIの下書き・先生のみ表示',
                  ),
                  const SizedBox(height: 12),
                  const Text('記録の振り返り'),
                  Text(advice.summary),
                  const SizedBox(height: 12),
                  const Text('先生への確認ポイント'),
                  Text(advice.teacherNote),
                  const SizedBox(height: 16),
                  TextFormField(
                    initialValue: advice.message,
                    onChanged: (value) => message = value,
                    enabled: !saving,
                    minLines: 3,
                    maxLines: 7,
                    maxLength: 1000,
                    decoration: const InputDecoration(
                      labelText: '生徒へ届ける文章',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const Text('振り返りと確認ポイントは生徒に表示されません。確認した文章だけが届きます。'),
                  if (error != null)
                    Text(
                      error!,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: saving ? null : () => Navigator.pop(dialogContext),
              child: const Text('編集を破棄して閉じる'),
            ),
            FilledButton(
              onPressed: saving
                  ? null
                  : () async {
                      if (message.trim().isEmpty) {
                        update(() => error = '文章を入力してください');
                        return;
                      }
                      update(() {
                        saving = true;
                        error = null;
                      });
                      try {
                        await widget.store.publishStudyAdvice(
                          advice.id,
                          message,
                        );
                        if (!dialogContext.mounted) return;
                        Navigator.pop(dialogContext);
                        if (mounted) {
                          _refresh();
                          ScaffoldMessenger.of(this.context).showSnackBar(
                            const SnackBar(content: Text('生徒へアドバイスを送りました')),
                          );
                        }
                      } catch (e) {
                        if (dialogContext.mounted) {
                          update(() {
                            saving = false;
                            error = e is StudyFailure
                                ? e.message
                                : '送信できませんでした。再試行してください。';
                          });
                        }
                      }
                    },
              child: Text(saving ? '送信中…' : '確認して生徒へ送る'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            widget.teacher ? '学習アドバイス' : 'せんせいからのアドバイス',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          if (widget.teacher) ...[
            const Text('直近7日間を振り返り、先生が内容を確認してから届けます。'),
            DropdownButtonFormField<String>(
              initialValue: _student ?? widget.store.students.firstOrNull?.id,
              decoration: const InputDecoration(labelText: '対象の生徒'),
              items: widget.store.students
                  .map(
                    (s) => DropdownMenuItem(value: s.id, child: Text(s.name)),
                  )
                  .toList(),
              onChanged: _busy
                  ? null
                  : (value) => setState(() => _student = value),
            ),
            const SizedBox(height: 8),
            FilledButton.icon(
              onPressed: _busy ? null : _generate,
              icon: const Icon(Icons.auto_awesome),
              label: Text(_busy ? '作成中…' : 'アドバイス案を作成'),
            ),
            if (_error != null)
              Text(
                _error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
          ],
          FutureBuilder<List<StudyAdvice>>(
            future: _items,
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return TextButton(
                  onPressed: _refresh,
                  child: const Text('アドバイスを読み込めませんでした・再試行'),
                );
              }
              if (!snapshot.hasData) return const LinearProgressIndicator();
              final items = snapshot.data!;
              if (items.isEmpty) {
                return Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Text(
                    widget.teacher
                        ? '作成した下書きはここに残ります。'
                        : 'アドバイスがとどくと、ここにひょうじされるよ。',
                  ),
                );
              }
              return Column(
                children: [
                  for (final a in items)
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(
                        widget.teacher
                            ? (widget.store.students
                                          .where((s) => s.id == a.studentId)
                                          .firstOrNull
                                          ?.name ??
                                      '生徒') +
                                  (a.published ? '・送信済み' : '・下書き')
                            : 'せんせいからのメッセージ',
                      ),
                      subtitle: Text(
                        widget.teacher && !a.published ? a.summary : a.message,
                      ),
                      trailing: widget.teacher && !a.published
                          ? TextButton(
                              onPressed: _busy ? null : () => _review(a),
                              child: const Text('確認・編集'),
                            )
                          : null,
                    ),
                ],
              );
            },
          ),
        ],
      ),
    ),
  );
}
