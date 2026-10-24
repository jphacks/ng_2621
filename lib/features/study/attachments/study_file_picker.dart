import 'package:file_selector/file_selector.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../study_models.dart';
import 'study_attachment.dart';

class PickedStudyFile {
  const PickedStudyFile(this.name, this.bytes);
  final String name;
  final Uint8List bytes;
}

Future<List<PickedStudyFile>> pickStudyFiles() async {
  final files = await openFiles(
    acceptedTypeGroups: [
      const XTypeGroup(
        label: '画像・PDF',
        extensions: ['jpg', 'jpeg', 'png', 'pdf'],
        mimeTypes: ['image/jpeg', 'image/png', 'application/pdf'],
      ),
    ],
  );
  return readPickedStudyFiles(files);
}

Future<List<PickedStudyFile>> pickStudyPhotos() async {
  if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
    try {
      final photo = await const MethodChannel('zoostudy/photos')
          .invokeMapMethod<String, dynamic>('pickPhoto');
      if (photo == null) return [];
      final name = photo['name'] as String;
      final bytes = photo['bytes'] as Uint8List;
      validateStudyFile(name, bytes);
      return [PickedStudyFile(name, bytes)];
    } on PlatformException catch (error) {
      throw StudyFailure(error.message ?? '写真を選択できませんでした');
    }
  }
  final files = await ImagePicker().pickMultiImage(
    limit: maxStudyAttachments,
    requestFullMetadata: false,
  );
  return readPickedStudyFiles(files);
}

Future<List<PickedStudyFile>> readPickedStudyFiles(List<XFile> files) async {
  if (files.length > maxStudyAttachments) {
    throw const StudyFailure('ファイルは最大3件まで選択してください');
  }
  final selected = <PickedStudyFile>[];
  for (final file in files) {
    if (await file.length() > maxStudyFileBytes) {
      throw const StudyFailure('ファイルは1件10MB以内で選択してください');
    }
    final bytes = await file.readAsBytes();
    validateStudyFile(file.name, bytes);
    selected.add(PickedStudyFile(file.name, bytes));
  }
  return selected;
}
