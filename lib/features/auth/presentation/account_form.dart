import 'package:flutter/material.dart';

/// The form is independent of Firebase, so validation and callbacks are testable.
class AccountForm extends StatefulWidget {
  const AccountForm({
    super.key,
    required this.isTeacher,
    required this.busy,
    this.signedInEmail,
    required this.onSignIn,
    required this.onRegister,
    required this.onJoin,
    required this.onReset,
    required this.onSignOut,
  });
  final bool isTeacher, busy;
  final String? signedInEmail;
  final Future<void> Function(String, String) onSignIn;
  final Future<void> Function(String, String, String, String) onRegister;
  final Future<void> Function(String, String) onJoin;
  final Future<void> Function(String) onReset;
  final Future<void> Function() onSignOut;
  @override
  State<AccountForm> createState() => _AccountFormState();
}

class _AccountFormState extends State<AccountForm> {
  final _form = GlobalKey<FormState>();
  final _email = TextEditingController(),
      _password = TextEditingController(),
      _name = TextEditingController(),
      _invite = TextEditingController();
  bool _register = false, _submitting = false;
  @override
  void dispose() {
    for (final c in [_email, _password, _name, _invite]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _submit() async {
    if (widget.busy || _submitting || !_form.currentState!.validate()) return;
    setState(() => _submitting = true);
    try {
      FocusScope.of(context).unfocus();
      if (widget.signedInEmail != null) {
        await widget.onJoin(_name.text.trim(), _invite.text.trim());
      } else if (_register) {
        await widget.onRegister(
          _email.text.trim(),
          _password.text,
          _name.text.trim(),
          _invite.text.trim(),
        );
      } else {
        await widget.onSignIn(_email.text.trim(), _password.text);
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) => Form(
    key: _form,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (widget.signedInEmail == null) ...[
          TextFormField(
            key: const ValueKey('account-email'),
            controller: _email,
            enabled: !widget.busy,
            keyboardType: TextInputType.emailAddress,
            autofillHints: const [AutofillHints.email],
            decoration: const InputDecoration(labelText: 'メールアドレス'),
            validator: (value) =>
                value != null &&
                    RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(value.trim())
                ? null
                : 'メールアドレスを入力してください',
          ),
          const SizedBox(height: 12),
          TextFormField(
            key: const ValueKey('account-password'),
            controller: _password,
            enabled: !widget.busy,
            obscureText: true,
            enableSuggestions: false,
            autocorrect: false,
            autofillHints: [
              _register ? AutofillHints.newPassword : AutofillHints.password,
            ],
            decoration: InputDecoration(
              labelText: _register ? 'パスワード（8文字以上）' : 'パスワード',
            ),
            validator: (value) =>
                value == null ||
                    value.trim().isEmpty ||
                    (_register && value.length < 8)
                ? 'パスワードを確認してください'
                : null,
          ),
        ] else
          Text('ログイン中：${widget.signedInEmail}'),
        if (!widget.isTeacher &&
            (_register || widget.signedInEmail != null)) ...[
          const SizedBox(height: 12),
          const Text('先生・管理者から受け取った招待コードでクラスに参加します。'),
          TextFormField(
            key: const ValueKey('account-name'),
            controller: _name,
            enabled: !widget.busy,
            maxLength: 40,
            decoration: const InputDecoration(labelText: '表示名'),
            validator: (value) =>
                value == null ||
                    value.trim().isEmpty ||
                    value.trim().length > 40
                ? '表示名を入力してください'
                : null,
          ),
          TextFormField(
            key: const ValueKey('account-invite'),
            controller: _invite,
            enabled: !widget.busy,
            autocorrect: false,
            decoration: const InputDecoration(labelText: '招待コード'),
            validator: (value) =>
                value == null ||
                    !RegExp(r'^[a-fA-F0-9]{32}$').hasMatch(value.trim())
                ? '32桁の招待コードを確認してください'
                : null,
          ),
        ],
        const SizedBox(height: 24),
        if (!widget.isTeacher || widget.signedInEmail == null)
          FilledButton(
            key: const ValueKey('account-submit'),
            onPressed: widget.busy || _submitting ? null : _submit,
            child: Text(
              widget.busy
                  ? '処理中…'
                  : widget.signedInEmail != null
                  ? 'クラスに参加'
                  : _register
                  ? 'アカウントを作成して参加'
                  : 'ログイン',
            ),
          ),
        if (!widget.isTeacher && widget.signedInEmail == null)
          TextButton(
            onPressed: widget.busy
                ? null
                : () => setState(() => _register = !_register),
            child: Text(_register ? 'ログインへ戻る' : '生徒アカウントを新規作成'),
          ),
        if (widget.isTeacher)
          const Text('先生アカウントは管理者が用意します。自分で先生権限を設定することはできません。'),
        if (widget.signedInEmail == null)
          TextButton(
            onPressed: widget.busy
                ? null
                : () => widget.onReset(_email.text.trim()),
            child: const Text('パスワードを再設定'),
          ),
        if (widget.signedInEmail != null)
          TextButton(
            onPressed: widget.busy ? null : widget.onSignOut,
            child: const Text('ログアウトして別のアカウントで入る'),
          ),
      ],
    ),
  );
}
