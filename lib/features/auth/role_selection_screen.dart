import 'package:flutter/material.dart';

import 'role_home_screen.dart';

class RoleSelectionScreen extends StatefulWidget {
  const RoleSelectionScreen({super.key});

  @override
  State<RoleSelectionScreen> createState() => _RoleSelectionScreenState();
}

class _RoleSelectionScreenState extends State<RoleSelectionScreen> {
  bool? _isTeacher;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
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
                  const SizedBox(height: 48),
                  _RoleCard(
                    title: '先生はこちら',
                    description: '課題を配布・提出を確認',
                    icon: Icons.school_outlined,
                    selected: _isTeacher == true,
                    onTap: () => setState(() => _isTeacher = true),
                  ),
                  const SizedBox(height: 16),
                  _RoleCard(
                    title: '生徒はこちら',
                    description: '宿題を提出・動物園を育成',
                    icon: Icons.pets_outlined,
                    selected: _isTeacher == false,
                    onTap: () => setState(() => _isTeacher = false),
                  ),
                  const SizedBox(height: 32),
                  FilledButton(
                    onPressed: _isTeacher == null
                        ? null
                        : () => Navigator.of(context).push(
                            MaterialPageRoute<void>(
                              builder: (_) =>
                                  RoleHomeScreen(isTeacher: _isTeacher!),
                            ),
                          ),
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
    required this.onTap,
    required this.selected,
  });

  final String title;
  final String description;
  final IconData icon;
  final VoidCallback onTap;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.primary;
    return Card(
      color: selected
          ? Theme.of(context).colorScheme.primaryContainer
          : Colors.white,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
          child: Row(
            children: [
              Icon(icon, size: 36, color: color),
              const SizedBox(width: 20),
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
              Icon(
                selected ? Icons.check_circle : Icons.circle_outlined,
                color: color,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
