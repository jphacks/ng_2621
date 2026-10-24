import 'dart:typed_data';

import 'package:crypto/crypto.dart';

import '../study_models.dart';

const maxStudyAttachments = 3;
const maxStudyFileBytes = 10 * 1024 * 1024;

class StudyAttachment {
  const StudyAttachment({
    required this.id,
    required this.name,
    required this.size,
    required this.contentType,
    required this.storagePath,
    this.generation,
  });
  final String id;
  final String name;
  final int size;
  final String contentType;
  final String storagePath;
  final String? generation;
  bool get isPdf => contentType == 'application/pdf';
  String get sizeLabel => size < 1024 * 1024
      ? '${(size / 1024).ceil()} KB'
      : '${(size / (1024 * 1024)).toStringAsFixed(1)} MB';
  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'size': size,
    'contentType': contentType,
    'storagePath': storagePath,
    if (generation != null) 'generation': generation,
  };
  factory StudyAttachment.fromJson(Map<String, dynamic> json) =>
      StudyAttachment(
        id: json['id'] as String,
        name: json['name'] as String,
        size: json['size'] as int,
        contentType: json['contentType'] as String,
        storagePath: json['storagePath'] as String,
        generation: json['generation'] as String?,
      );
}

String attachmentExtension(String name) => name.split('.').last.toLowerCase();
String validateStudyFile(String name, Uint8List bytes) {
  if (name.trim().isEmpty ||
      name.length > 200 ||
      name.contains(RegExp(r'[/\\\x00-\x1F]'))) {
    throw const StudyFailure('ファイル名を確認してください（200文字以内）');
  }
  if (bytes.isEmpty || bytes.length > maxStudyFileBytes) {
    throw const StudyFailure('ファイルは1件10MB以内で選択してください');
  }
  final extension = attachmentExtension(name);
  bool starts(List<int> signature) =>
      bytes.length >= signature.length &&
      List.generate(
        signature.length,
        (i) => bytes[i] == signature[i],
      ).every((b) => b);
  if (extension == 'pdf' && starts([0x25, 0x50, 0x44, 0x46, 0x2D])) {
    return 'application/pdf';
  }
  if (extension == 'png' && starts([137, 80, 78, 71, 13, 10, 26, 10])) {
    return 'image/png';
  }
  if (['jpg', 'jpeg'].contains(extension) && starts([255, 216, 255])) {
    return 'image/jpeg';
  }
  throw const StudyFailure('JPEG・PNG画像、またはPDFを選択してください。ファイルの内容と拡張子も確認してください。');
}

String studyFileId(Uint8List bytes) => sha256.convert(bytes).toString();
void validateAttachmentList(List<StudyAttachment> files) {
  if (files.length > maxStudyAttachments ||
      files.map((f) => f.id).toSet().length != files.length) {
    throw const StudyFailure('添付は異なるファイルを最大3件までにしてください');
  }
  for (final file in files) {
    if (!RegExp(r'^[a-f0-9]{64}$').hasMatch(file.id) ||
        file.size <= 0 ||
        file.size > maxStudyFileBytes ||
        ![
          'application/pdf',
          'image/jpeg',
          'image/png',
        ].contains(file.contentType)) {
      throw const StudyFailure('添付情報が無効です。ファイルを選び直してください');
    }
  }
}

void validateLoadedAttachment(StudyAttachment file, Uint8List bytes) {
  if (studyFileId(bytes) != file.id ||
      bytes.length != file.size ||
      validateStudyFile(file.name, bytes) != file.contentType) {
    throw const StudyFailure('添付ファイルの内容を確認できませんでした。ファイルを選び直してください');
  }
}
