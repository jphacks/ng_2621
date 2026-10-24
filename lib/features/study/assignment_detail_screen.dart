import 'dart:async';

import '../../core/storage/draft_storage.dart';

import 'package:flutter/material.dart';

import '../game/domain/game_snapshot.dart';
import 'study_repository.dart';

String studyDate(DateTime value) {
  final date = value.toLocal();
  String two(int n) => n.toString().padLeft(2, '0');
  return '${date.year}/${two(date.month)}/${two(date.day)} ${two(date.hour)}:${two(date.minute)}';
}

class AssignmentDetailScreen extends StatefulWidget {
  const AssignmentDetailScreen({
    super.key,
    required this.store,
    required this.assignmentId,
    required this.isTeacher,
    this.studentId,
  });
  final StudyRepository store;
  final String assignmentId;
  final bool isTeacher;
  final String? studentId;
  @override
  State<AssignmentDetailScreen> createState() => _AssignmentDetailScreenState();
}

class _AssignmentDetailScreenState extends State<AssignmentDetailScreen> {
  late final TextEditingController _answer;
  late final TextEditingController _feedback;
  final _formKey = GlobalKey<FormState>();
  bool _busy = false;
  String? _message;
  String? _draftError;
  late final DraftSession _draft;
  bool _draftLoading = true;

  @override
  void initState() {
    super.initState();
    final submission = widget.store.submissionFor(
      widget.assignmentId,
      studentId: widget.studentId,
    );
    _answer = TextEditingController(text: submission?.answerText ?? '');
    _feedback = TextEditingController(text: submission?.feedback ?? '');
    _draft = DraftSession(
      widget.store.drafts,
      '${widget.isTeacher ? 'review' : 'answer'}-${widget.assignmentId}-${widget.studentId ?? 'self'}',
      onStatus: (error) {
        if (mounted && _draftError != error) {
          setState(() => _draftError = error);
        }
      },
    );
    _loadDraft();
  }

  Future<void> _loadDraft() async {
    try {
      final data = await _draft.read();
      if (!mounted) return;
      if (data != null) {
        if (widget.isTeacher) {
          _feedback.text = data['feedback'] as String? ?? _feedback.text;
        } else {
          _answer.text = data['answer'] as String? ?? _answer.text;
        }
      }
    } catch (_) {
      _message = '下書きを読み込めませんでした';
    }
    if (mounted) setState(() => _draftLoading = false);
  }

  @override
  void dispose() {
    _answer.dispose();
    _feedback.dispose();
    super.dispose();
  }

  Future<void> _act(FutureOr<String> Function() action) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final message = await action();
      await widget.store.flush();
      await _draft.clear();
      _message = message;
    } on StudyFailure catch (error) {
      _message = error.message;
    } catch (_) {
      _message = '処理結果を確認できませんでした。通信を確認して再試行してください。入力内容は保持しています。';
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(widget.isTeacher ? '提出内容の確認' : '課題の詳細・提出')),
    body: _draftLoading
        ? const Center(child: CircularProgressIndicator())
        : Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 700),
              child: ListenableBuilder(
                listenable: widget.store,
                builder: (context, _) {
                  final assignment = widget.store.assignmentFor(
                    widget.assignmentId,
                  );
                  final submission = widget.store.submissionFor(
                    widget.assignmentId,
                    studentId: widget.studentId,
                  );
                  final status =
                      submission?.status ?? AssignmentState.notSubmitted;
                  final canSubmit =
                      status == AssignmentState.notSubmitted ||
                      status == AssignmentState.needsRevision;
                  final isLate =
                      submission?.submittedAt.isAfter(assignment.dueAt) ??
                      false;
                  return Form(
                    key: _formKey,
                    child: ListView(
                      padding: const EdgeInsets.all(24),
                      children: [
                        if (_draftError != null) Text(_draftError!),
                        if (_message != null)
                          Card(
                            child: Padding(
                              padding: const EdgeInsets.all(12),
                              child: Text(_message!, semanticsLabel: _message),
                            ),
                          ),
                        Text(
                          '${assignment.subject.label}・${assignment.title}',
                          style: Theme.of(context).textTheme.headlineSmall,
                        ),
                        const SizedBox(height: 16),
                        Text(assignment.description),
                        const SizedBox(height: 16),
                        Text('締切：${studyDate(assignment.dueAt)}'),
                        Text('状態：${status.label}${isLate ? '（期限後提出）' : ''}'),
                        const Text('提出で+30コイン ／ 承認で+70コイン'),
                        const SizedBox(height: 16),
                        if (submission != null) ...[
                          Text('生徒：${submission.studentName}'),
                          Text('提出日時：${studyDate(submission.submittedAt)}'),
                          Text('再提出回数：${submission.revisionCount}'),
                          if (submission.reviewedAt != null)
                            Text('確認日時：${studyDate(submission.reviewedAt!)}'),
                          const SizedBox(height: 8),
                          const Text('提出した回答'),
                          SelectableText(submission.answerText),
                          if (submission.feedback.isNotEmpty) ...[
                            const SizedBox(height: 12),
                            Text('先生から：${submission.feedback}'),
                          ],
                          const SizedBox(height: 16),
                        ],
                        if (status == AssignmentState.pendingReview)
                          const Text('先生の確認でさらに +70コイン'),
                        if (status == AssignmentState.needsRevision)
                          const Text('もう一度チャレンジ！ 前回の30コインはそのまま'),
                        if (status == AssignmentState.approved)
                          const Text('先生が確認済みです。提出30＋承認70＝100コイン獲得済み'),
                        if (widget.isTeacher &&
                            status == AssignmentState.pendingReview) ...[
                          const SizedBox(height: 16),
                          TextFormField(
                            controller: _feedback,
                            onChanged: (_) =>
                                _draft.save({'feedback': _feedback.text}),
                            maxLength: 1000,
                            minLines: 2,
                            maxLines: 5,
                            decoration: const InputDecoration(
                              labelText: '生徒へのコメント（任意）',
                              border: OutlineInputBorder(),
                            ),
                          ),
                          const SizedBox(height: 16),
                          FilledButton(
                            onPressed: _busy
                                ? null
                                : () => _act(() async {
                                    final amount = await widget.store.review(
                                      widget.assignmentId,
                                      role: DemoStudyRole.teacher,
                                      approve: true,
                                      studentId: widget.studentId,
                                      expectedVersion: submission!.version,
                                      feedback: _feedback.text,
                                    );
                                    return amount == 0
                                        ? 'すでに承認済みです'
                                        : '承認しました。生徒に+70コイン';
                                  }),
                            child: const Text('内容を確認して承認'),
                          ),
                          const SizedBox(height: 12),
                          OutlinedButton(
                            onPressed: _busy
                                ? null
                                : () => _act(() async {
                                    await widget.store.review(
                                      widget.assignmentId,
                                      role: DemoStudyRole.teacher,
                                      approve: false,
                                      studentId: widget.studentId,
                                      expectedVersion: submission!.version,
                                      feedback: _feedback.text,
                                    );
                                    return '再提出を依頼しました。提出時の30コインは維持されます';
                                  }),
                            child: const Text('再提出を依頼'),
                          ),
                        ],
                        if (widget.isTeacher && submission == null)
                          const Text('生徒の提出を待っています'),
                        if (!widget.isTeacher && canSubmit) ...[
                          const SizedBox(height: 16),
                          if (DateTime.now().isAfter(assignment.dueAt))
                            const Text('期限を過ぎていますが、提出できます。報酬は変わりません。'),
                          TextFormField(
                            controller: _answer,
                            onChanged: (_) =>
                                _draft.save({'answer': _answer.text}),
                            maxLength: 5000,
                            minLines: 5,
                            maxLines: 12,
                            decoration: const InputDecoration(
                              labelText: '回答',
                              hintText: '取り組んだ内容や答えを入力してください',
                              border: OutlineInputBorder(),
                            ),
                            validator: (value) =>
                                value == null || value.trim().isEmpty
                                ? '回答を入力してください'
                                : null,
                          ),
                          const SizedBox(height: 16),
                          FilledButton(
                            onPressed: _busy
                                ? null
                                : () {
                                    if (!_formKey.currentState!.validate()) {
                                      return;
                                    }
                                    _act(() async {
                                      final amount = await widget.store.submit(
                                        widget.assignmentId,
                                        _answer.text,
                                        role: DemoStudyRole.student,
                                      );
                                      return amount == 30
                                          ? '課題を提出！ +30コイン'
                                          : '再提出しました。追加の提出報酬はありません';
                                    });
                                  },
                            child: Text(
                              status == AssignmentState.needsRevision
                                  ? '再提出する'
                                  : '課題を提出する',
                            ),
                          ),
                        ],
                        const SizedBox(height: 24),
                        Text(widget.store.storageExplanation),
                      ],
                    ),
                  );
                },
              ),
            ),
          ),
  );
}
