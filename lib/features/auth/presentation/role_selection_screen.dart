import 'package:flutter/material.dart';

/// The caller supplies destinations so this screen stays independent of each role's features.
class RoleSelectionScreen extends StatefulWidget {
  const RoleSelectionScreen({
    super.key,
    required this.teacherPageBuilder,
    required this.studentPageBuilder,
    this.storageDescription,
    this.onConfirmed,
  });

  final WidgetBuilder teacherPageBuilder;
  final WidgetBuilder studentPageBuilder;
  final String? storageDescription;
  final Future<void> Function(bool isTeacher)? onConfirmed;

  @override
  State<RoleSelectionScreen> createState() => _RoleSelectionScreenState();
}

class _RoleSelectionScreenState extends State<RoleSelectionScreen> {
  bool? _isTeacher;
  bool _saving = false;
  String? _error;

  Future<void> _confirm() async {
    final teacher = _isTeacher;
    if (teacher == null || _saving) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      if (widget.onConfirmed != null) await widget.onConfirmed!(teacher);
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute<void>(
          builder: teacher
              ? widget.teacherPageBuilder
              : widget.studentPageBuilder,
        ),
      );
    } catch (_) {
      if (mounted) setState(() => _error = '選択を保存できませんでした。もう一度確定してください。');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F9F3),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Icon(
                    Icons.park_rounded,
                    size: 64,
                    color: Color(0xFF39785A),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'ZooっとStudy',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.headlineLarge
                        ?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  const Text('宿題が、動物園を育てる。', textAlign: TextAlign.center),
                  if (widget.storageDescription != null) ...[
                    const SizedBox(height: 16),
                    Text(
                      widget.storageDescription!,
                      textAlign: TextAlign.center,
                    ),
                  ],
                  const SizedBox(height: 40),
                  _RoleCard(
                    title: '先生はこちら',
                    description: '課題を配布・提出を確認',
                    icon: Icons.school_outlined,
                    selected: _isTeacher == true,
                    onTap: () {
                      if (!_saving) setState(() => _isTeacher = true);
                    },
                  ),
                  const SizedBox(height: 16),
                  _RoleCard(
                    title: '生徒はこちら',
                    description: '宿題を提出・動物園を育成',
                    icon: Icons.pets_outlined,
                    selected: _isTeacher == false,
                    onTap: () {
                      if (!_saving) setState(() => _isTeacher = false);
                    },
                  ),
                  if (_error != null) Text(_error!),
                  const SizedBox(height: 32),
                  FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFF39785A),
                    ),
                    onPressed: _isTeacher == null || _saving ? null : _confirm,
                    child: const Padding(
                      padding: EdgeInsets.symmetric(vertical: 14),
                      child: Text('確定'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _RoleCard extends StatelessWidget {
  const _RoleCard({
    required this.title,
    required this.description,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final String title;
  final String description;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    const color = Color(0xFF39785A);
    return Semantics(
      selected: selected,
      child: Card(
        color: selected ? const Color(0xFFE0EEDC) : Colors.white,
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
            child: Row(
              children: [
                Icon(icon, size: 32, color: color),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: Theme.of(context).textTheme.titleLarge
                            ?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 6),
                      Text(description),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Icon(
                  selected ? Icons.check_circle : Icons.circle_outlined,
                  color: color,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
