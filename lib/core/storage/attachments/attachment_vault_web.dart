import 'dart:typed_data';

import 'package:idb_shim/idb_browser.dart';

import 'attachment_vault.dart';

Future<AttachmentVault> openAttachmentVault() async {
  final factory = getIdbFactory();
  if (factory == null) throw StateError('このブラウザーでは添付ファイルを保存できません');
  final db = await factory.open(
    'zoostudy-attachments-v1',
    version: 1,
    onUpgradeNeeded: (event) {
      event.database.createObjectStore('files');
    },
  );
  return IndexedAttachmentVault(db);
}

class IndexedAttachmentVault implements AttachmentVault {
  IndexedAttachmentVault(this.database);
  final Database database;
  @override
  Future<void> put(String id, Uint8List bytes) async {
    final tx = database.transaction('files', idbModeReadWrite);
    await tx.objectStore('files').put(bytes, id);
    await tx.completed;
  }

  @override
  Future<Uint8List> get(String id) async {
    final tx = database.transaction('files', idbModeReadOnly);
    final bytes = await tx.objectStore('files').getObject(id);
    await tx.completed;
    if (bytes is! List) throw StateError('添付ファイルが見つかりません');
    return Uint8List.fromList(bytes.cast<int>());
  }
}
