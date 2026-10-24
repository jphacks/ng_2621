import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/storage/draft_storage.dart';
import '../../study/data/firebase_study_repository.dart';
import '../../zoo/presentation/zoo_screen.dart';

class FirebaseLoginScreen extends StatefulWidget {
  const FirebaseLoginScreen({
    super.key,
    required this.isTeacher,
    required this.emulator,
  });
  final bool isTeacher;
  final bool emulator;
  @override
  State<FirebaseLoginScreen> createState() => _FirebaseLoginScreenState();
}

class _FirebaseLoginScreenState extends State<FirebaseLoginScreen> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  FirebaseStudyRepository? _repository;
  StreamSubscription<User?>? _authSubscription;
  bool _busy = false;
  String? _error;
  @override
  void initState() {
    super.initState();
    _authSubscription = FirebaseAuth.instance.authStateChanges().listen((user) {
      final repository = _repository;
      if (mounted && repository != null && user?.uid != repository.uid) {
        setState(() {
          _repository = null;
          _error = 'ログイン状態が変わりました。もう一度ログインしてください。';
        });
        repository.dispose();
      }
    });
    if (FirebaseAuth.instance.currentUser != null) _open();
  }

  Future<void> _open() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    FirebaseStudyRepository? pending;
    try {
      if (FirebaseAuth.instance.currentUser == null) {
        await FirebaseAuth.instance.signInWithEmailAndPassword(
          email: _email.text.trim(),
          password: _password.text,
        );
      }
      final preferences = await SharedPreferences.getInstance();
      pending = await FirebaseStudyRepository.connect(
        firestore: FirebaseFirestore.instance,
        functions: FirebaseFunctions.instanceFor(region: 'asia-northeast1'),
        emulator: widget.emulator,
        draftFactory: (namespace) =>
            PreferencesDraftStorage(preferences, 'firebase.$namespace'),
      );
      if (FirebaseAuth.instance.currentUser?.uid != pending.uid) {
        pending.dispose();
        pending = null;
        throw StateError('ログイン状態が変わりました。再試行してください。');
      }
      if (pending.isTeacher != widget.isTeacher) {
        pending.dispose();
        pending = null;
        throw StateError('アカウントの役割と選択が異なります。戻って選び直すか、ログアウトしてください。');
      }
      if (!mounted) {
        pending.dispose();
        return;
      }
      setState(() => _repository = pending);
    } on FirebaseAuthException catch (error) {
      if (mounted) {
        setState(
          () => _error = switch (error.code) {
            'network-request-failed' => '通信を確認してください',
            'too-many-requests' => 'しばらく待ってから再試行してください',
            _ => 'ログインできませんでした。メールアドレスとパスワードを確認してください。',
          },
        );
      }
    } catch (error) {
      if (mounted) setState(() => _error = '接続できませんでした：$error');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  void dispose() {
    _authSubscription?.cancel();
    _repository?.dispose();
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final repository = _repository;
    if (repository != null) {
      return ZooScreen(
        gameRepository: repository,
        assignmentStore: repository,
        isTeacher: repository.isTeacher,
        onSignOut: () async {
          await FirebaseAuth.instance.signOut();
        },
      );
    }
    return Scaffold(
      appBar: AppBar(title: Text('${widget.isTeacher ? '先生' : '生徒'}としてログイン')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 440),
          child: ListView(
            shrinkWrap: true,
            padding: const EdgeInsets.all(24),
            children: [
              Text(
                widget.emulator ? 'Firebaseエミュレーター（ローカルサーバー）' : 'Firebaseに接続',
              ),
              if (widget.emulator)
                const Text(
                  '先生：teacher@example.test\n生徒：student@example.test\nデモ専用パスワード：ZooStudyDemo123!',
                ),
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  child: Text(_error!),
                ),
              if (FirebaseAuth.instance.currentUser == null) ...[
                TextField(
                  controller: _email,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(labelText: 'メールアドレス'),
                ),
                TextField(
                  controller: _password,
                  obscureText: true,
                  decoration: const InputDecoration(labelText: 'パスワード'),
                ),
              ] else
                Text('ログイン中：${FirebaseAuth.instance.currentUser!.email}'),
              const SizedBox(height: 24),
              FilledButton(
                onPressed: _busy ? null : _open,
                child: Text(_busy ? '接続中…' : 'ログイン'),
              ),
              if (FirebaseAuth.instance.currentUser != null)
                TextButton(
                  onPressed: _busy
                      ? null
                      : () async {
                          await FirebaseAuth.instance.signOut();
                          if (mounted) setState(() => _error = null);
                        },
                  child: const Text('ログアウトして別のアカウントで入る'),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
