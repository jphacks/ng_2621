import 'school_management_screen.dart';
import 'student_code_form.dart';
import 'student_qr_scanner.dart';
import '../data/school_account_api.dart';
import 'account_form.dart';
import '../data/cloud_game_preferences.dart';

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
  String? _message;
  FirebaseStudyRepository? _repository;
  StreamSubscription<User?>? _authSubscription;
  bool _busy = false;
  bool _emailLogin = false;
  bool _restoringAuth = true;
  String? _error;
  @override
  void initState() {
    super.initState();
    _emailLogin = widget.isTeacher;
    _authSubscription = FirebaseAuth.instance.authStateChanges().listen((user) {
      if (_restoringAuth) {
        if (!mounted) return;
        setState(() => _restoringAuth = false);
        if (user != null) _open();
        return;
      }
      if (mounted) setState(() {});
      final repository = _repository;
      if (mounted && repository != null && user?.uid != repository.uid) {
        setState(() {
          _repository = null;
          _error = 'ログイン状態が変わりました。もう一度ログインしてください。';
        });
        repository.dispose();
      }
    });
  }

  Future<void> _open({String? email, String? password}) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    FirebaseStudyRepository? pending;
    try {
      if (FirebaseAuth.instance.currentUser == null) {
        await FirebaseAuth.instance.signInWithEmailAndPassword(
          email: email!,
          password: password!,
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

  Future<void> _loginCode(String code) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final result =
          await FirebaseFunctions.instanceFor(region: 'asia-northeast1')
              .httpsCallable('loginWithStudentCode')
              .call<dynamic>({'code': code})
              .timeout(const Duration(seconds: 25));
      await FirebaseAuth.instance.signInWithCustomToken(
        result.data['token'] as String,
      );
      if (mounted) await _open();
    } on FirebaseFunctionsException catch (e) {
      if (mounted) setState(() => _error = e.message ?? 'コードをかくにんしてね');
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'ログインできませんでした。通信をかくにんして、もういちどためしてね。');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _manageAccounts() async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => SchoolManagementScreen(api: FirebaseSchoolAccountApi()),
      ),
    );
    if (!mounted) return;
    final previous = _repository;
    setState(() => _repository = null);
    previous?.dispose();
    await _open();
  }

  Future<void> _register(
    String email,
    String password,
    String name,
    String code,
  ) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      await _enroll(name, code);
      if (mounted) await _open();
    } on FirebaseAuthException catch (error) {
      if (mounted) {
        setState(
          () => _error = error.code == 'email-already-in-use'
              ? 'このメールアドレスは登録済みです。ログインしてください。'
              : 'アカウントを作成できませんでした。入力と通信を確認してください。',
        );
      }
    } on FirebaseFunctionsException catch (error) {
      if (mounted) {
        setState(
          () => _error = error.message ?? 'クラスに参加できませんでした。招待コードを確認して再試行してください。',
        );
      }
    } catch (_) {
      if (mounted) {
        setState(() => _error = '登録・参加を確認できませんでした。ログイン中なら招待コードで参加を再試行してください。');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _enroll(String name, String code) =>
      FirebaseFunctions.instanceFor(region: 'asia-northeast1')
          .httpsCallable('joinClass')
          .call<dynamic>({'displayName': name, 'invitationCode': code})
          .timeout(const Duration(seconds: 20))
          .then((_) {});
  Future<void> _join(String name, String code) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await _enroll(name, code);
      if (mounted) await _open();
    } on FirebaseFunctionsException catch (error) {
      if (mounted) setState(() => _error = error.message ?? 'クラスに参加できませんでした');
    } catch (_) {
      if (mounted) setState(() => _error = 'クラスに参加できませんでした。通信を確認してください。');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _resetPassword(String email) async {
    if (_busy) return;
    if (!RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(email)) {
      setState(() => _error = 'メールアドレスを入力してください');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await FirebaseAuth.instance.sendPasswordResetEmail(email: email);
      if (mounted) {
        setState(() => _message = '登録されている場合は再設定メールが送信されます。メールをご確認ください。');
      }
    } on FirebaseAuthException catch (error) {
      if (mounted) {
        setState(() {
          if (error.code == 'user-not-found') {
            _message = '登録されている場合は再設定メールが送信されます。メールをご確認ください。';
          } else {
            _error = '送信できませんでした。通信を確認してください。';
          }
        });
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  void dispose() {
    _authSubscription?.cancel();
    _repository?.dispose();

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final repository = _repository;
    if (repository != null) {
      return ZooScreen(
        key: ValueKey(repository.uid),
        gameRepository: repository,
        gamePreferences: CloudGamePreferences(
          uid: repository.uid,
          organizationId: repository.organizationId,
        ),
        accountName: repository.identity['displayName'] as String?,
        accountClassName: repository.identity['className'] as String?,
        accountEmail: FirebaseAuth.instance.currentUser?.email,
        assignmentStore: repository,
        isTeacher: repository.isTeacher,
        onManageAccounts: repository.isTeacher ? _manageAccounts : null,
        onSignOut: () async {
          await FirebaseAuth.instance.signOut();
        },
      );
    }
    if (_restoringAuth) {
      return const Scaffold(
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text('前回のログインを確認しています…'),
            ],
          ),
        ),
      );
    }
    return Scaffold(
      appBar: AppBar(title: const Text('アカウントにログイン')),
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
                  '先生：teacher@example.test\n生徒：student@example.test\nデモ専用パスワード：ZooStudyDemo123!\n新規登録の招待コード：0123456789abcdef0123456789abcdef',
                ),
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  child: Text(_error!),
                ),
              if (_message != null) Text(_message!),
              if (FirebaseAuth.instance.currentUser != null)
                FilledButton(
                  onPressed: _busy ? null : () => _open(),
                  child: const Text('登録済みのアカウントで続ける'),
                ),
              if (FirebaseAuth.instance.currentUser == null) ...[
                SegmentedButton<bool>(
                  segments: const [
                    ButtonSegment(value: false, label: Text('生徒（コード）')),
                    ButtonSegment(value: true, label: Text('先生・メール')),
                  ],
                  selected: {_emailLogin},
                  onSelectionChanged: _busy
                      ? null
                      : (value) => setState(() {
                          _emailLogin = value.single;
                          _error = null;
                        }),
                ),
                const SizedBox(height: 20),
              ],
              if (FirebaseAuth.instance.currentUser == null && !_emailLogin)
                StudentCodeForm(
                  busy: _busy,
                  onLogin: _loginCode,
                  onScan: supportsStudentQrScanner
                      ? () => Navigator.of(context).push<String>(
                          MaterialPageRoute(
                            builder: (_) => const StudentQrScanner(),
                          ),
                        )
                      : null,
                ),
              if (_emailLogin || FirebaseAuth.instance.currentUser != null)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text('先生のアカウントは管理者が用意します。役割は登録済みの権限から判定します。'),
                    AccountForm(
                      isTeacher: widget.isTeacher,
                      busy: _busy,
                      signedInEmail: FirebaseAuth.instance.currentUser == null
                          ? null
                          : FirebaseAuth.instance.currentUser!.email ?? 'アカウント',
                      onSignIn: (email, password) =>
                          _open(email: email, password: password),
                      onRegister: _register,
                      onJoin: _join,
                      onReset: _resetPassword,
                      onSignOut: () async {
                        await FirebaseAuth.instance.signOut();
                        if (mounted) {
                          setState(() {
                            _error = null;
                            _message = null;
                          });
                        }
                      },
                    ),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }
}
