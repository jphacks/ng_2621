import 'package:flutter/material.dart';

String normalizeStudentCode(String input) =>
    input.toUpperCase().replaceAll(RegExp(r'[\s-]'), '');
bool validStudentCode(String input) =>
    RegExp(r'^[2-9A-HJ-NP-Z]{22}$').hasMatch(normalizeStudentCode(input));

class StudentCodeForm extends StatefulWidget {
  const StudentCodeForm({
    super.key,
    required this.busy,
    required this.onLogin,
    this.onScan,
  });
  final bool busy;
  final Future<void> Function(String code) onLogin;
  final Future<String?> Function()? onScan;
  @override
  State<StudentCodeForm> createState() => _StudentCodeFormState();
}

class _StudentCodeFormState extends State<StudentCodeForm> {
  final _form = GlobalKey<FormState>();
  final _code = TextEditingController();
  bool _submitting = false;
  @override
  void dispose() {
    _code.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (widget.busy || _submitting || !_form.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    setState(() => _submitting = true);
    try {
      await widget.onLogin(normalizeStudentCode(_code.text));
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
        const Text('せんせいにもらったコードで はじめよう'),
        const SizedBox(height: 16),
        TextFormField(
          key: const ValueKey('student-login-code'),
          controller: _code,
          enabled: !widget.busy && !_submitting,
          autocorrect: false,
          enableSuggestions: false,
          textCapitalization: TextCapitalization.characters,
          maxLength: 60,
          decoration: const InputDecoration(
            labelText: 'ログインコード',
            hintText: 'ABC234-XXXX-XXXX-XXXX-XXXX',
            border: OutlineInputBorder(),
          ),
          validator: (value) =>
              validStudentCode(value ?? '') ? null : 'コードをもういちど かくにんしてね',
          onFieldSubmitted: (_) => _submit(),
        ),
        FilledButton(
          onPressed: widget.busy || _submitting ? null : _submit,
          child: Text(widget.busy || _submitting ? 'かくにんちゅう…' : 'このコードで はじめる'),
        ),
        if (widget.onScan != null)
          OutlinedButton.icon(
            onPressed: widget.busy || _submitting
                ? null
                : () async {
                    final code = await widget.onScan!();
                    if (code == null || !mounted) return;
                    _code.text = code;
                  },
            icon: const Icon(Icons.qr_code_scanner),
            label: const Text('QRコードを よみとる'),
          ),
        const Text('コードをなくしたら、せんせいにきいてね。'),
      ],
    ),
  );
}
