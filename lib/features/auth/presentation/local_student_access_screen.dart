import 'package:flutter/material.dart';

import '../../../core/storage/draft_storage.dart';
import '../../../core/storage/attachments/platform_attachment_vault.dart';
import '../../study/demo_assignment_store.dart';
import '../../zoo/presentation/zoo_screen.dart';
import '../data/school_account_api.dart';
import '../data/account_scoped_storage.dart';
export '../data/account_scoped_storage.dart' show StudentAccountStorage;
import 'student_code_form.dart';
import 'student_qr_scanner.dart';

class LocalStudentAccessScreen extends StatefulWidget {
  const LocalStudentAccessScreen({
    super.key,
    required this.api,
    required this.storage,
    this.attachmentVaultFactory,
    this.onExit,
  });
  final VoidCallback? onExit;
  final SchoolAccountApi api;
  final DraftStorage storage;
  final Future<AttachmentVault> Function()? attachmentVaultFactory;
  @override
  State<LocalStudentAccessScreen> createState() =>
      _LocalStudentAccessScreenState();
}

class _LocalStudentAccessScreenState extends State<LocalStudentAccessScreen> {
  DemoAssignmentStore? _store;
  Map<String, dynamic>? _student;
  bool _busy = true;
  String? _error;
  @override
  void initState() {
    super.initState();
    _restore();
  }

  Future<void> _restore() async {
    try {
      final saved = await widget.storage.read('student-session');
      if (saved != null) {
        final result = await widget.api.call('restoreStudentSession', {
          'studentId': saved['studentId'],
        });
        await _open(Map<String, dynamic>.from(result['student'] as Map));
      }
    } catch (_) {
      _error = 'せんせいにもらったコードで、もういちどはいってね';
    }
    if (mounted) setState(() => _busy = false);
  }

  Future<void> _open(Map<String, dynamic> student) async {
    final store = await DemoAssignmentStore.open(
      StudentAccountStorage(widget.storage, student['id'] as String),
      assignmentSource: ClassAccountStorage(
        widget.storage,
        student['classId'] as String,
      ),
      studentId: student['id'] as String,
      studentName: student['name'] as String,
      attachmentVault:
          await (widget.attachmentVaultFactory ?? openAttachmentVault)(),
    );
    try {
      await widget.storage.write('student-session', {
        'studentId': student['id'],
      });
    } catch (_) {
      store.dispose();
      rethrow;
    }
    if (!mounted) {
      store.dispose();
      return;
    }
    setState(() {
      _store = store;
      _student = student;
    });
  }

  Future<void> _login(String code) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final result = await widget.api.call('loginWithStudentCode', {
        'code': code,
      });
      await _open(Map<String, dynamic>.from(result['student'] as Map));
    } catch (e) {
      _error = e is StudyFailure ? e.message : 'はじめられませんでした。もういちどためしてね。';
    }
    if (mounted) setState(() => _busy = false);
  }

  Future<void> _signOut() async {
    try {
      await _store?.flush();
      await widget.storage.remove('student-session');
      final previous = _store;
      if (!mounted) return;
      setState(() {
        _store = null;
        _student = null;
      });
      previous?.dispose();
      widget.onExit?.call();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('保存できませんでした。もういちどためしてね。')));
      }
    }
  }

  @override
  void dispose() {
    _store?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final store = _store;
    if (store != null) {
      return ZooScreen(
        key: ValueKey(_student!['id']),
        accountName: _student!['name'] as String,
        accountClassName: _student!['className'] as String?,
        accountStorageDescription:
            'この生徒のデータをこの端末に保存します。同じ端末の先生から課題を受け取れます。別端末との同期はありません。',
        gameRepository: store,
        assignmentStore: store,
        gamePreferences: StudentAccountStorage(
          widget.storage,
          _student!['id'] as String,
        ),
        onSignOut: _signOut,
      );
    }
    return Scaffold(
      appBar: AppBar(title: const Text('生徒のとうろく・ログイン')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 440),
          child: ListView(
            shrinkWrap: true,
            padding: const EdgeInsets.all(24),
            children: [
              const Text('先生がこの端末で発行したコードを入力してください。メールアドレスは必要ありません。'),
              const SizedBox(height: 16),
              if (_busy) const LinearProgressIndicator(),
              if (_error != null)
                Text(
                  _error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              StudentCodeForm(
                busy: _busy,
                onLogin: _login,
                onScan: supportsStudentQrScanner
                    ? () => Navigator.of(context).push<String>(
                        MaterialPageRoute(
                          builder: (_) => const StudentQrScanner(),
                        ),
                      )
                    : null,
              ),
              const SizedBox(height: 16),
              if (widget.onExit != null)
                TextButton(
                  onPressed: _busy ? null : widget.onExit,
                  child: const Text('先生・生徒の選択に戻る'),
                ),
              const Text('端末内モードです。ほかのスマホから同じコードで入る場合はFirebase接続が必要です。'),
            ],
          ),
        ),
      ),
    );
  }
}
