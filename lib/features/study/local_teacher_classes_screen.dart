import 'package:flutter/material.dart';

import '../../core/storage/draft_storage.dart';
import '../../core/storage/attachments/platform_attachment_vault.dart';
import '../auth/data/school_account_api.dart';
import 'local_class_study_repository.dart';
import 'teacher_assignments_screen.dart';
import 'study_repository.dart';

class LocalTeacherClassesScreen extends StatefulWidget {
  const LocalTeacherClassesScreen({
    super.key,
    required this.api,
    required this.storage,
    this.legacyStore,
    this.attachmentVaultFactory,
  });
  final SchoolAccountApi api;
  final DraftStorage storage;
  final StudyRepository? legacyStore;
  final Future<AttachmentVault> Function()? attachmentVaultFactory;
  @override
  State<LocalTeacherClassesScreen> createState() =>
      _LocalTeacherClassesScreenState();
}

class _LocalTeacherClassesScreenState extends State<LocalTeacherClassesScreen> {
  List<Map<String, dynamic>> _classes = [];
  String? _selected, _error;
  LocalClassStudyRepository? _store;
  bool _busy = true;
  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final result = await widget.api.call('listManagedClasses');
      if (!mounted) return;
      _classes = (result['classes'] as List)
          .map((c) => Map<String, dynamic>.from(c as Map))
          .toList();
      if (_classes.isEmpty) {
        setState(() => _busy = false);
        return;
      }
      final preferred = _selected ?? result['currentClassId'];
      await _select(
        _classes.any((c) => c['id'] == preferred)
            ? preferred as String
            : _classes.first['id'] as String,
      );
    } catch (_) {
      if (mounted) {
        setState(() {
          _error = 'クラスを読み込めませんでした。';
          _busy = false;
        });
      }
    }
  }

  Future<void> _select(String id) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final next = await LocalClassStudyRepository.open(
        storage: widget.storage,
        api: widget.api,
        classId: id,
        vault: await (widget.attachmentVaultFactory ?? openAttachmentVault)(),
      );
      if (!mounted) {
        next.dispose();
        return;
      }
      final previous = _store;
      setState(() {
        _store = next;
        _selected = id;
        _busy = false;
      });
      previous?.dispose();
    } catch (_) {
      if (mounted) {
        setState(() {
          _error = 'クラスの課題・学習記録を読み込めませんでした。保存データを確認してください。';
          _busy = false;
        });
      }
    }
  }

  Future<void> _importLegacy() async {
    final target = _store!;
    setState(() => _busy = true);
    try {
      for (final a in widget.legacyStore!.assignments) {
        await target.publish(
          DemoAssignment(
            id: 'legacy_${a.id}',
            subject: a.subject,
            title: a.title,
            description: a.description,
            dueAt: a.dueAt,
          ),
        );
      }
    } catch (_) {
      if (mounted) setState(() => _error = '以前の課題を配布できませんでした。再試行してください。');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  void dispose() {
    _store?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<String>(
                    key: ValueKey(_selected),
                    initialValue: _selected,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: '課題・学習記録の対象クラス',
                      border: OutlineInputBorder(),
                    ),
                    items: _classes
                        .map(
                          (c) => DropdownMenuItem(
                            value: c['id'] as String,
                            child: Text(c['name'] as String),
                          ),
                        )
                        .toList(),
                    onChanged: _busy
                        ? null
                        : (id) {
                            if (id != null) _select(id);
                          },
                  ),
                ),
                IconButton(
                  tooltip: 'クラスの最新データを読み込む',
                  onPressed: _busy ? null : _load,
                  icon: const Icon(Icons.refresh),
                ),
              ],
            ),
          ),
          if (!_busy &&
              _store != null &&
              widget.legacyStore?.assignments.isNotEmpty == true)
            TextButton(
              onPressed: _importLegacy,
              child: const Text('以前の課題をこのクラスに配布'),
            ),
          if (_busy)
            const Expanded(child: Center(child: CircularProgressIndicator()))
          else if (_error != null)
            Expanded(
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(_error!),
                    TextButton(onPressed: _load, child: const Text('再試行')),
                  ],
                ),
              ),
            )
          else if (_classes.isEmpty)
            const Expanded(
              child: Center(child: Text('「その他 → クラス・生徒管理」でクラスと生徒を登録してください。')),
            )
          else
            Expanded(
              child: TeacherAssignmentsScreen(
                key: ValueKey(_store),
                store: _store!,
              ),
            ),
        ],
      ),
    ),
  );
}
