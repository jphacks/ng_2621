import 'attachments/study_file_picker.dart';
import 'attachments/attachment_preview_screen.dart';

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
    this.pickFiles,
    this.pickPhotos,
  });
  final StudyRepository store;
  final String assignmentId;
  final bool isTeacher;
  final String? studentId;
  final Future<List<PickedStudyFile>> Function()? pickFiles;
  final Future<List<PickedStudyFile>> Function()? pickPhotos;
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
  bool _selectingFiles = false;
  final _files = <StudyAttachment>[];

  void _saveAnswerDraft() => _draft.save({
    'answer': _answer.text,
    'attachments': _files.map((f) => f.toJson()).toList(),
  });

  Future<void> _selectFiles({bool photos = false}) async {
    if (_selectingFiles || _busy) return;
    setState(() {
      _selectingFiles = true;
      _message = null;
    });
    try {
      final picker = photos
          ? (widget.pickPhotos ?? pickStudyPhotos)
          : (widget.pickFiles ?? pickStudyFiles);
      final picked = await picker();
      if (!mounted) return;
      if (_files.length + picked.length > maxStudyAttachments) {
        throw const StudyFailure('添付は最大3件までにしてください');
      }
      for (final pickedFile in picked) {
        final file = await widget.store.addAttachment(
          widget.assignmentId,
          pickedFile.name,
          pickedFile.bytes,
        );
        if (!mounted) return;
        if (!_files.any((f) => f.id == file.id)) _files.add(file);
        _saveAnswerDraft();
      }
    } on StudyFailure catch (error) {
      _message = error.message;
    } catch (_) {
      _message = 'ファイルを保存・アップロードできませんでした。もう一度選択してください。';
    } finally {
      if (mounted) setState(() => _selectingFiles = false);
    }
  }

  Widget _fileTile(StudyAttachment file, {bool removable = false}) => ListTile(
    leading: Icon(
      file.isPdf ? Icons.picture_as_pdf_outlined : Icons.image_outlined,
    ),
    title: Text(file.name),
    subtitle: Text(file.sizeLabel),
    onTap: () => Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) =>
            AttachmentPreviewScreen(store: widget.store, file: file),
      ),
    ),
    trailing: removable
        ? IconButton(
            tooltip: '添付を外す',
            icon: const Icon(Icons.close),
            onPressed: _busy || _selectingFiles
                ? null
                : () {
                    setState(() => _files.remove(file));
                    _saveAnswerDraft();
                  },
          )
        : const Icon(Icons.open_in_new),
  );

  @override
  void initState() {
    super.initState();
    final submission = widget.store.submissionFor(
      widget.assignmentId,
      studentId: widget.studentId,
    );
    _answer = TextEditingController(text: submission?.answerText ?? '');
    _files.addAll(submission?.attachments ?? []);
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
          if (data['attachments'] != null) {
            _files.clear();
            _files.addAll(
              (data['attachments'] as List).map(
                (f) => StudyAttachment.fromJson(
                  Map<String, dynamic>.from(f as Map),
                ),
              ),
            );
          }
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
                          if (submission.answerText.isNotEmpty)
                            SelectableText(submission.answerText),
                          for (final file in submission.attachments)
                            _fileTile(file),
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
                          const Text('画像・PDFで提出できます（最大3件・1件10MB）。回答文は任意です。'),
                          OutlinedButton.icon(
                            onPressed: _busy || _selectingFiles
                                ? null
                                : () => _selectFiles(photos: true),
                            icon: const Icon(Icons.photo_library_outlined),
                            label: const Text('フォトから選ぶ'),
                          ),
                          OutlinedButton.icon(
                            onPressed: _busy || _selectingFiles
                                ? null
                                : () => _selectFiles(),
                            icon: const Icon(Icons.attach_file),
                            label: const Text('画像・PDFを添付'),
                          ),
                          if (_selectingFiles)
                            const Column(
                              children: [
                                LinearProgressIndicator(),
                                Text('ファイルを準備しています…'),
                              ],
                            ),
                          for (final file in _files)
                            _fileTile(file, removable: true),
                          const SizedBox(height: 16),
                          TextFormField(
                            controller: _answer,
                            enabled: !_busy && !_selectingFiles,
                            onChanged: (_) => _saveAnswerDraft(),
                            maxLength: 5000,
                            minLines: 5,
                            maxLines: 12,
                            decoration: const InputDecoration(
                              labelText: '回答・補足（添付がある場合は任意）',
                              hintText: '取り組んだ内容や答えを入力してください',
                              border: OutlineInputBorder(),
                            ),
                            validator: (value) =>
                                (value == null || value.trim().isEmpty) &&
                                    _files.isEmpty
                                ? '回答を入力するか画像・PDFを添付してください'
                                : null,
                          ),
                          const SizedBox(height: 16),
                          FilledButton(
                            onPressed: _busy || _selectingFiles
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
                                        attachments: List.of(_files),
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
