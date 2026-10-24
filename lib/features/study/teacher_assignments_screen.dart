import 'package:flutter/material.dart';

import 'demo_assignment_store.dart';
import 'assignment_detail_screen.dart';
import '../game/domain/game_snapshot.dart';

class DemoAssignmentList extends StatelessWidget {
  final bool isTeacher;
  const DemoAssignmentList({
    super.key,
    required this.store,
    this.isTeacher = false,
  });
  final DemoAssignmentStore store;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: store,
    builder: (context, _) => Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text('課題配布デモ（共通のデモクラス）'),
        const Text('このアプリ内だけで共有されます。再起動すると消えます。'),
        if (store.assignments.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 24),
            child: Text('追加された課題はありません'),
          ),
        for (final assignment in store.assignments.reversed)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Chip(label: Text(assignment.subject.label)),
                  Text(
                    assignment.title,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  Text(assignment.description),
                  if (isTeacher) ...[
                    const SizedBox(height: 8),
                    const Text('対象生徒：デモ生徒'),
                    if (store.submissionFor(assignment.id) != null) ...[
                      Text(
                        '提出日時：${studyDate(store.submissionFor(assignment.id)!.submittedAt)}',
                      ),
                      Text(
                        store.submissionFor(assignment.id)!.answerText,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                  const SizedBox(height: 8),
                  Text(
                    '状態：${store.submissionFor(assignment.id)?.status.label ?? AssignmentState.notSubmitted.label}',
                  ),
                  TextButton(
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => AssignmentDetailScreen(
                          store: store,
                          assignmentId: assignment.id,
                          isTeacher: isTeacher,
                        ),
                      ),
                    ),
                    child: Text(isTeacher ? '提出内容を確認' : '詳細・回答する'),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '締切：${assignment.dueAt.year}/${assignment.dueAt.month}/${assignment.dueAt.day} 23:59',
                  ),
                ],
              ),
            ),
          ),
      ],
    ),
  );
}

class TeacherAssignmentsScreen extends StatelessWidget {
  const TeacherAssignmentsScreen({super.key, required this.store});
  final DemoAssignmentStore store;

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('課題を配布')),
    body: Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 640),
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            FilledButton.icon(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => _AssignmentForm(store: store),
                ),
              ),
              icon: const Icon(Icons.add),
              label: const Text('課題を作成'),
            ),
            const SizedBox(height: 24),
            DemoAssignmentList(store: store, isTeacher: true),
          ],
        ),
      ),
    ),
  );
}

class _AssignmentForm extends StatefulWidget {
  const _AssignmentForm({required this.store});
  final DemoAssignmentStore store;
  @override
  State<_AssignmentForm> createState() => _AssignmentFormState();
}

class _AssignmentFormState extends State<_AssignmentForm> {
  final _formKey = GlobalKey<FormState>();
  final _title = TextEditingController();
  final _description = TextEditingController();
  DateTime _dueAt = DateTime.now().add(const Duration(days: 7));
  bool _published = false;
  AssignmentSubject? _subject;

  @override
  void dispose() {
    _title.dispose();
    _description.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('新しい課題')),
    body: Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 640),
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(24),
            children: [
              DropdownButtonFormField<AssignmentSubject>(
                decoration: const InputDecoration(
                  labelText: '科目名',
                  hintText: '科目を選択してください',
                  border: OutlineInputBorder(),
                ),
                items: AssignmentSubject.values
                    .map(
                      (subject) => DropdownMenuItem(
                        value: subject,
                        child: Text(subject.label),
                      ),
                    )
                    .toList(),
                onChanged: (subject) => setState(() => _subject = subject),
                validator: (subject) => subject == null ? '科目を選択してください' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _title,
                maxLength: 100,
                decoration: const InputDecoration(
                  labelText: '課題のタイトル',
                  hintText: '例：教科書 第3章の復習',
                  border: OutlineInputBorder(),
                ),
                validator: (value) => value == null || value.trim().isEmpty
                    ? 'タイトルを入力してください'
                    : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _description,
                maxLength: 3000,
                minLines: 4,
                maxLines: 8,
                decoration: const InputDecoration(
                  labelText: '説明・取り組み方',
                  hintText: '例：教科書の20〜22ページを解き、途中式も書いてください。',
                  border: OutlineInputBorder(),
                ),
                validator: (value) => value == null || value.trim().isEmpty
                    ? '説明を入力してください'
                    : null,
              ),
              const SizedBox(height: 16),
              OutlinedButton.icon(
                icon: const Icon(Icons.calendar_month),
                label: Text(
                  '締切：${_dueAt.year}/${_dueAt.month}/${_dueAt.day} 23:59',
                ),
                onPressed: () async {
                  final now = DateUtils.dateOnly(DateTime.now());
                  final date = await showDatePicker(
                    context: context,
                    initialDate: _dueAt.isBefore(now) ? now : _dueAt,
                    firstDate: now,
                    lastDate: DateTime(now.year + 5, 12, 31),
                  );
                  if (date != null && mounted) setState(() => _dueAt = date);
                },
              ),
              const SizedBox(height: 24),
              FilledButton(
                onPressed: () {
                  if (_published || !_formKey.currentState!.validate()) return;
                  _published = true;
                  widget.store.publish(
                    DemoAssignment(
                      subject: _subject!,
                      title: _title.text.trim(),
                      description: _description.text.trim(),
                      dueAt: DateTime(
                        _dueAt.year,
                        _dueAt.month,
                        _dueAt.day,
                        23,
                        59,
                      ),
                    ),
                  );
                  Navigator.of(context).pop();
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('デモクラスに課題を追加しました')),
                  );
                },
                child: const Text('課題を配布する'),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
