import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import 'student_code_form.dart';

bool get supportsStudentQrScanner =>
    kIsWeb ||
    {
      TargetPlatform.android,
      TargetPlatform.iOS,
      TargetPlatform.macOS,
    }.contains(defaultTargetPlatform);

class StudentQrScanner extends StatefulWidget {
  const StudentQrScanner({super.key});
  @override
  State<StudentQrScanner> createState() => _StudentQrScannerState();
}

class _StudentQrScannerState extends State<StudentQrScanner>
    with WidgetsBindingObserver {
  final _controller = MobileScannerController(
    autoStart: false,
    formats: const [BarcodeFormat.qrCode],
  );
  bool _finished = false;
  bool _active = true;
  String? _message;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) => _start());
  }

  Future<void> _start() async {
    if (!mounted || _finished) return;
    try {
      await _controller.start();
      if (!_active) await _controller.stop();
    } catch (_) {
      if (mounted) {
        setState(() => _message = 'カメラを利用できません。権限を確認するか、コードを入力してください。');
      }
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _active = state == AppLifecycleState.resumed;
    if (!_controller.value.hasCameraPermission) return;
    if (state == AppLifecycleState.resumed) {
      unawaited(_start());
    } else {
      unawaited(_controller.stop());
    }
  }

  Future<void> _detect(BarcodeCapture capture) async {
    if (_finished || !_active) return;
    final code = capture.barcodes
        .map((b) => b.rawValue)
        .whereType<String>()
        .where(validStudentCode)
        .firstOrNull;
    if (code == null) {
      if (mounted) setState(() => _message = 'せんせいにもらったQRコードをうつしてね');
      return;
    }
    _finished = true;
    await _controller.stop();
    if (mounted) Navigator.pop(context, code);
  }

  @override
  void dispose() {
    _finished = true;
    WidgetsBinding.instance.removeObserver(this);
    unawaited(_controller.dispose());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('QRコードを よみとる')),
    body: Column(
      children: [
        const Padding(
          padding: EdgeInsets.all(16),
          child: Text('せんせいにもらったQRコードを、わくのなかにうつしてね。'),
        ),
        Expanded(
          child: MobileScanner(
            controller: _controller,
            onDetect: _detect,
            errorBuilder: (context, error) =>
                const Center(child: Text('カメラを利用できません。戻ってコードを入力してください。')),
          ),
        ),
        if (_message != null)
          Padding(padding: const EdgeInsets.all(16), child: Text(_message!)),
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('コードをにゅうりょくする'),
        ),
      ],
    ),
  );
}
