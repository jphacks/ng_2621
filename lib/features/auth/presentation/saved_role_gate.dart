import 'package:flutter/material.dart';

import '../../../core/storage/draft_storage.dart';
import 'role_selection_screen.dart';

/// Shows role selection on startup unless persistence is explicitly enabled.
class SavedRoleGate extends StatefulWidget {
  const SavedRoleGate({
    super.key,
    required this.teacherPageBuilder,
    required this.studentPageBuilder,
    this.storage,
    this.storageDescription,
    this.rememberRole = false,
  });
  final WidgetBuilder teacherPageBuilder;
  final WidgetBuilder studentPageBuilder;
  final DraftStorage? storage;
  final bool rememberRole;
  final String? storageDescription;
  static const storageKey = 'selected-role';
  @override
  State<SavedRoleGate> createState() => _SavedRoleGateState();
}

class _SavedRoleGateState extends State<SavedRoleGate> {
  bool? _isTeacher;
  bool _loading = false;
  String? _error;
  @override
  void initState() {
    super.initState();
    if (widget.rememberRole && widget.storage != null) {
      _loading = true;
      _restore();
    }
  }

  Future<void> _restore() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final saved = await widget.storage?.read(SavedRoleGate.storageKey);
      if (!mounted) return;
      _isTeacher = switch (saved?['role']) {
        'teacher' => true,
        'student' => false,
        _ => null,
      };
    } catch (_) {
      _error = '前回の役割を読み込めませんでした。再試行してください。';
    }
    if (mounted) setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (_error != null) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(_error!),
              TextButton(onPressed: _restore, child: const Text('再試行')),
            ],
          ),
        ),
      );
    }
    if (_isTeacher != null) {
      return Builder(
        builder: _isTeacher!
            ? widget.teacherPageBuilder
            : widget.studentPageBuilder,
      );
    }
    return RoleSelectionScreen(
      teacherPageBuilder: widget.teacherPageBuilder,
      studentPageBuilder: widget.studentPageBuilder,
      storageDescription: widget.storageDescription,
      onConfirmed: !widget.rememberRole || widget.storage == null
          ? null
          : (teacher) => widget.storage!.write(SavedRoleGate.storageKey, {
              'role': teacher ? 'teacher' : 'student',
            }),
    );
  }
}
