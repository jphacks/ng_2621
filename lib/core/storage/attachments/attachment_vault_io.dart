import 'dart:io';
import 'dart:typed_data';

import 'package:path_provider/path_provider.dart';

import '../request_id.dart';
import 'attachment_vault.dart';

Future<AttachmentVault> openAttachmentVault() async {
  final directory = await getApplicationSupportDirectory();
  final files = Directory('${directory.path}/zoostudy/attachments');
  await files.create(recursive: true);
  return FileAttachmentVault(files.path);
}

class FileAttachmentVault implements AttachmentVault {
  FileAttachmentVault(this.directory);
  final String directory;
  File _file(String id) {
    if (!RegExp(r'^[a-f0-9]{64}$').hasMatch(id)) {
      throw ArgumentError('Invalid file ID');
    }
    return File('$directory/$id');
  }

  @override
  Future<void> put(String id, Uint8List bytes) async {
    final file = _file(id);
    if (await file.exists()) return;
    final temporary = File('${file.path}.${newRequestId()}.part');
    try {
      await temporary.writeAsBytes(bytes, flush: true);
      if (!await file.exists()) await temporary.rename(file.path);
    } finally {
      if (await temporary.exists()) await temporary.delete();
    }
  }

  @override
  Future<Uint8List> get(String id) => _file(id).readAsBytes();
}
