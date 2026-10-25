import 'package:flutter/material.dart';

import '../../../core/storage/draft_storage.dart';
import '../../auth/data/school_account_api.dart';
import '../../game/domain/game_snapshot.dart';
import '../data/zoo_repository.dart';
import 'zoo_chrome.dart';
import 'zoo_controller.dart';
import 'zoo_viewport.dart';

/// Teacher home. Class zoos are separate from personal student zoos.
class TeacherClassHome extends StatefulWidget {
  const TeacherClassHome({
    super.key,
    required this.api,
    this.storage,
    this.onManage,
    this.onClassChanged,
  });
  final SchoolAccountApi api;
  final ValueChanged<String?>? onClassChanged;
  final DraftStorage? storage;
  final Future<void> Function()? onManage;

  @override
  State<TeacherClassHome> createState() => _TeacherClassHomeState();
}

class _TeacherClassHomeState extends State<TeacherClassHome> {
  List<Map<String, dynamic>> _classes = [];
  String? _selected;
  ZooController? _controller;
  String? _error;
  bool _loading = true;
  int _request = 0;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  @override
  void dispose() {
    _request++;
    _controller?.dispose();
    super.dispose();
  }

  Future<void> _reload() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final result = await widget.api.call('listManagedClasses');
      if (!mounted) return;
      _classes = (result['classes'] as List)
          .map((c) => Map<String, dynamic>.from(c as Map))
          .toList();
      final current = result['currentClassId'] as String?;
      final preferred = _selected ?? current;
      final id = _classes.any((c) => c['id'] == preferred)
          ? preferred
          : _classes.firstOrNull?['id'] as String?;
      if (id == null) {
        widget.onClassChanged?.call(null);
        _controller?.dispose();
        setState(() {
          _selected = null;
          _controller = null;
          _loading = false;
        });
      } else {
        await _select(id);
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _error = 'クラスを読み込めませんでした。再読み込みしてください。';
          _loading = false;
        });
      }
    }
  }

  Future<void> _select(String id) async {
    final request = ++_request;
    widget.onClassChanged?.call(
      _classes.where((c) => c['id'] == id).first['name'] as String,
    );
    _controller?.dispose();
    setState(() {
      _selected = id;
      _controller = null;
      _loading = true;
      _error = null;
    });
    try {
      if (!widget.api.preview) {
        throw StateError('Cloud class zoo is not configured');
      }
      // Keep a stable class ID as the key, independent of the display name.
      final saved = await widget.storage?.read('class-zoo.$id');
      final snapshot = saved == null ? null : GameSnapshot.fromJson(saved);
      final world = await ZooRepository().load();
      if (!mounted || request != _request) return;
      final controller = ZooController(
        world,
        layout: snapshot?.layout,
        ownedAnimalIds: snapshot?.ownedAnimalIds ?? {},
        ownedFacilityIds: snapshot?.ownedFacilityIds ?? {},
      );
      setState(() {
        _controller = controller;
        _loading = false;
      });
    } catch (_) {
      if (mounted && request == _request) {
        setState(() {
          _error = widget.api.preview
              ? 'このクラスの動物園を読み込めませんでした。'
              : 'クラスの動物園はクラウド側の接続設定が必要です。';
          _loading = false;
        });
      }
    }
  }

  Future<void> _manage() async {
    await widget.onManage?.call();
    if (mounted) await _reload();
  }

  @override
  Widget build(BuildContext context) {
    final name =
        _classes.where((c) => c['id'] == _selected).firstOrNull?['name']
            as String?;
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 8, 8),
          child: Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<String>(
                  key: ValueKey(_selected),
                  initialValue: _selected,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: '表示するクラス',
                    border: OutlineInputBorder(),
                  ),
                  hint: const Text('クラスを選択'),
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
                  onChanged: _loading
                      ? null
                      : (id) {
                          if (id != null) _select(id);
                        },
                ),
              ),
              IconButton(
                tooltip: '再読み込み',
                onPressed: _loading ? null : _reload,
                icon: const Icon(Icons.refresh),
              ),
              if (widget.onManage != null)
                IconButton(
                  tooltip: 'クラス・生徒管理',
                  onPressed: _loading ? null : _manage,
                  icon: const Icon(Icons.groups),
                ),
            ],
          ),
        ),
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : _error != null
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(_error!),
                      TextButton(
                        onPressed: _reload,
                        child: const Text('再読み込み'),
                      ),
                    ],
                  ),
                )
              : _selected == null
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text('クラスを登録すると、ここに動物園が表示されます。'),
                      if (widget.onManage != null)
                        FilledButton(
                          onPressed: _manage,
                          child: const Text('クラスを登録する'),
                        ),
                    ],
                  ),
                )
              : Stack(
                  children: [
                    Positioned.fill(
                      child: ZooViewport(
                        key: ValueKey(_selected),
                        controller: _controller!,
                        title: '$nameの動物園',
                        showAnimalList: false,
                        onAnimals: () {},
                      ),
                    ),
                    if (_controller!.ownedAnimals.isEmpty)
                      const Positioned(
                        left: 16,
                        right: 16,
                        bottom: 64,
                        child: Card(
                          child: Padding(
                            padding: EdgeInsets.all(12),
                            child: Text(
                              'このクラスの動物はまだいません。\n生徒個人の動物園とは別の、クラス共通の表示です。',
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
        ),
        if (widget.api.preview)
          const Padding(
            padding: EdgeInsets.all(6),
            child: Text(
              '端末内のクラス動物園・別端末との同期は未接続',
              style: TextStyle(fontSize: 11, color: zooGreen),
            ),
          ),
      ],
    );
  }
}
