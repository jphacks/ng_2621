import 'dart:typed_data';

abstract interface class AttachmentVault {
  Future<void> put(String id, Uint8List bytes);
  Future<Uint8List> get(String id);
}

class MemoryAttachmentVault implements AttachmentVault {
  final _files = <String, Uint8List>{};
  @override
  Future<void> put(String id, Uint8List bytes) async {
    _files[id] = Uint8List.fromList(bytes);
  }

  @override
  Future<Uint8List> get(String id) async {
    final bytes = _files[id];
    if (bytes == null) throw StateError('添付ファイルが見つかりません');
    return Uint8List.fromList(bytes);
  }
}
