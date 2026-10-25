import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../data/school_account_api.dart';
import '../../study/study_repository.dart' show StudyFailure;

class SchoolManagementScreen extends StatefulWidget {
  const SchoolManagementScreen({super.key, required this.api});
  final SchoolAccountApi api;
  @override
  State<SchoolManagementScreen> createState() => _SchoolManagementScreenState();
}

class _SchoolManagementScreenState extends State<SchoolManagementScreen> {
  List<Map<String, dynamic>> _classes = [], _students = [];
  String? _selected, _current, _error;
  bool _busy = true;
  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final result = await widget.api.call('listManagedClasses');
      final classes = (result['classes'] as List)
          .map((c) => Map<String, dynamic>.from(c as Map))
          .toList();
      _current = result['currentClassId'] as String;
      _selected = classes.any((c) => c['id'] == _selected)
          ? _selected
          : classes.any((c) => c['id'] == _current)
          ? _current
          : classes.firstOrNull?['id'] as String?;
      _classes = classes;
      await _loadStudents();
    } catch (e) {
      _error = _message(e);
    }
    if (mounted) setState(() => _busy = false);
  }

  String _message(Object e) =>
      e is StudyFailure ? e.message : '処理できませんでした。通信を確認して再試行してください';
  Future<void> _loadStudents() async {
    if (_selected == null) {
      _students = [];
      return;
    }
    _students = [];
    final result = await widget.api.call('listManagedStudents', {
      'classId': _selected,
    });
    _students = (result['students'] as List)
        .map((s) => Map<String, dynamic>.from(s as Map))
        .toList();
  }

  Future<void> _perform(Future<void> Function() action) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await action();
    } catch (e) {
      _error = _message(e);
    }
    if (mounted) setState(() => _busy = false);
  }

  Future<String?> _askName(String title) => showDialog<String>(
    context: context,
    builder: (context) {
      var value = '';
      final form = GlobalKey<FormState>();
      return AlertDialog(
        title: Text(title),
        content: Form(
          key: form,
          child: TextFormField(
            autofocus: true,
            maxLength: 40,
            decoration: const InputDecoration(labelText: '名前'),
            onChanged: (text) => value = text.trim(),
            validator: (text) =>
                text == null || text.trim().isEmpty ? '名前を入力してください' : null,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('キャンセル'),
          ),
          FilledButton(
            onPressed: () {
              if (form.currentState!.validate()) Navigator.pop(context, value);
            },
            child: const Text('登録'),
          ),
        ],
      );
    },
  );
  Future<void> _createClass() async {
    final name = await _askName('クラスを作成');
    if (name == null || !mounted) return;
    await _perform(() async {
      final result = await widget.api.call('createManagedClass', {
        'name': name,
      });
      final classId = result['classId'] as String;
      if (!_classes.any((c) => c['id'] == classId)) {
        _classes.add({'id': classId, 'name': name, 'prefix': result['prefix']});
      }
      _selected = classId;
      _students = [];
      await _load();
    });
  }

  Future<void> _createStudent() async {
    final name = await _askName('生徒を登録');
    if (name == null || !mounted) return;
    await _perform(() async {
      final result = await widget.api.call('createManagedStudent', {
        'classId': _selected,
        'name': name,
      });
      await _load();
      if (mounted) await _showCode(name, result);
    });
  }

  Future<void> _reissue(Map<String, dynamic> student) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('コードを発行・再発行'),
        content: Text(
          student['name'] + 'さんのコードを発行します。以前のコードは使えなくなります。課題やコインは引き継がれます。',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('キャンセル'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('発行する'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    await _perform(() async {
      final result = await widget.api.call('reissueStudentCode', {
        'classId': _selected,
        'studentId': student['id'],
      });
      await _load();
      if (mounted) await _showCode(student['name'] as String, result);
    });
  }

  Future<void> _showCode(
    String studentName,
    Map<String, dynamic> result,
  ) async {
    final code = result['loginCode'] as String?;
    setState(() => _busy = false);
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('$studentNameさんのログインコード'),
        content: SizedBox(
          width: 360,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (code == null)
                  const Text('登録は完了しています。コードは再表示できないため、一覧から再発行してください。')
                else ...[
                  Text(
                    _classes.where((c) => c['id'] == _selected).first['name']
                        as String,
                  ),
                  const SizedBox(height: 12),
                  QrImageView(
                    data: code,
                    size: 220,
                    backgroundColor: Colors.white,
                  ),
                  SelectableText(
                    code,
                    style: const TextStyle(
                      fontSize: 20,
                      fontFamily: 'monospace',
                    ),
                  ),
                  TextButton.icon(
                    onPressed: () async {
                      await Clipboard.setData(ClipboardData(text: code));
                    },
                    icon: const Icon(Icons.copy),
                    label: const Text('コードをコピー'),
                  ),
                  Text(
                    widget.api.preview
                        ? 'この端末の生徒ログインで使えます。本人にだけ渡してください。'
                        : '本人にだけ渡してください。この画面を閉じると再表示できません。',
                  ),
                ],
              ],
            ),
          ),
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('閉じる'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('クラス・生徒管理'),
      actions: [
        IconButton(
          tooltip: '再読み込み',
          onPressed: _busy ? null : () => _perform(_load),
          icon: const Icon(Icons.refresh),
        ),
      ],
    ),
    body: Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 680),
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            if (widget.api.preview)
              const Card(
                child: Padding(
                  padding: EdgeInsets.all(12),
                  child: Text(
                    '端末内モードです。発行したコードは、この端末の「生徒はこちら」から使えます。別端末とは同期しません。',
                  ),
                ),
              ),
            if (_busy) const LinearProgressIndicator(),
            if (_error != null)
              Text(
                _error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            OutlinedButton.icon(
              onPressed: _busy ? null : _createClass,
              icon: const Icon(Icons.add),
              label: const Text('クラスを作成'),
            ),
            if (_classes.isNotEmpty) ...[
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                key: ValueKey(_selected),
                initialValue: _selected,
                isExpanded: true,
                decoration: const InputDecoration(labelText: '生徒を登録・管理するクラス'),
                items: _classes
                    .map(
                      (c) => DropdownMenuItem<String>(
                        value: c['id'] as String,
                        child: Text(
                          c['name'] as String,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    )
                    .toList(),
                onChanged: _busy
                    ? null
                    : (value) => _perform(() async {
                        _selected = value;
                        await _loadStudents();
                      }),
              ),
              const SizedBox(height: 8),
              Text(
                'クラス識別子：${_classes.where((c) => c['id'] == _selected).first['prefix'] as String? ?? ''}',
              ),
              Text(
                widget.api.preview
                    ? 'このクラスの生徒を登録・管理しています'
                    : _selected == _current
                    ? 'このクラスの課題・学習記録を利用中'
                    : '課題・学習記録で使うには、下のボタンで切り替えてください。',
              ),
              if (!widget.api.preview && _selected != _current)
                TextButton(
                  onPressed: _busy
                      ? null
                      : () => _perform(() async {
                          await widget.api.call('selectManagedClass', {
                            'classId': _selected,
                          });
                          _current = _selected;
                        }),
                  child: const Text('このクラスで課題・学習記録を開く'),
                ),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: _busy ? null : _createStudent,
                icon: const Icon(Icons.person_add),
                label: const Text('生徒を登録'),
              ),
              const SizedBox(height: 16),
              const Text('登録した生徒'),
              if (_students.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(16),
                  child: Text('生徒はまだ登録されていません'),
                ),
              for (final student in _students)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(student['name'] as String),
                  subtitle: Text(
                    student['hasCode'] == true ? '専用コード発行済み' : '専用コード未発行',
                  ),
                  trailing: TextButton(
                    onPressed: _busy ? null : () => _reissue(student),
                    child: const Text('コード発行'),
                  ),
                ),
            ] else if (!_busy)
              const Text('最初にクラスを作成してください。'),
          ],
        ),
      ),
    ),
  );
}
