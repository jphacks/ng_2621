import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:pdfrx/pdfrx.dart';

import '../study_repository.dart';

class AttachmentPreviewScreen extends StatefulWidget {
  const AttachmentPreviewScreen({
    super.key,
    required this.store,
    required this.file,
  });
  final StudyRepository store;
  final StudyAttachment file;
  @override
  State<AttachmentPreviewScreen> createState() =>
      _AttachmentPreviewScreenState();
}

class _AttachmentPreviewScreenState extends State<AttachmentPreviewScreen> {
  late Future<Uint8List> _bytes = widget.store.readAttachment(widget.file);
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(widget.file.name)),
    body: FutureBuilder<Uint8List>(
      future: _bytes,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('添付ファイルを開けませんでした。通信または保存データを確認してください。'),
                  TextButton(
                    onPressed: () => setState(
                      () => _bytes = widget.store.readAttachment(widget.file),
                    ),
                    child: const Text('再試行'),
                  ),
                ],
              ),
            ),
          );
        }
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        if (widget.file.isPdf) {
          return PdfViewer.data(
            snapshot.data!,
            sourceName: '${widget.file.id}/${widget.file.name}',
          );
        }
        return InteractiveViewer(
          minScale: 0.5,
          maxScale: 8,
          child: Center(
            child: Image.memory(
              snapshot.data!,
              fit: BoxFit.contain,
              errorBuilder: (_, _, _) => const Text('画像を表示できませんでした'),
            ),
          ),
        );
      },
    ),
  );
}
