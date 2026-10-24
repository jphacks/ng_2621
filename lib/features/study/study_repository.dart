import 'attachments/study_attachment.dart';
import 'study_detector/study_record.dart';
export 'attachments/study_attachment.dart';

import 'dart:async';

import 'package:flutter/foundation.dart';

import '../game/domain/game_repository.dart';
import '../shop/domain/shop_repository.dart';
import '../../core/storage/draft_storage.dart';
import 'study_models.dart';
export 'study_models.dart';

abstract class StudyRepository extends ChangeNotifier
    implements GameRepository, ShopRepository {
  List<StudyStudent> get students => const [
    StudyStudent('demo_student', 'デモ生徒'),
  ];
  int get coins;
  List<DemoAssignment> get assignments;
  DemoSubmission? submissionFor(String id, {String? studentId});
  List<DemoSubmission> submissionsFor(String id);
  DemoAssignment assignmentFor(String id);
  String get storageLabel => 'メモリ内デモ';
  String get storageExplanation => '同じ端末内で共有します。再起動すると消えます。';
  String? get storageError => null;
  bool get loading => false;
  DraftStorage? get drafts => null;
  Future<void> flush() async {}
  Future<void> refresh() async {}
  Future<List<StudyRecord>> loadStudyRecords() async => [];
  Future<void> saveStudyRecord(StudyRecord record) async =>
      throw const StudyFailure('学習記録の保存に未対応です');
  FutureOr<void> publish(
    DemoAssignment assignment, {
    DemoStudyRole role = DemoStudyRole.teacher,
  });
  FutureOr<int> submit(
    String id,
    String answer, {
    required DemoStudyRole role,
    List<StudyAttachment> attachments = const [],
  });
  Future<StudyAttachment> addAttachment(
    String assignmentId,
    String name,
    Uint8List bytes,
  ) async => throw const StudyFailure('ファイル提出には未対応です');
  Future<Uint8List> readAttachment(StudyAttachment file) async =>
      throw const StudyFailure('添付ファイルを開けません');
  FutureOr<int> review(
    String id, {
    required DemoStudyRole role,
    required bool approve,
    String feedback = '',
    String? studentId,
    int? expectedVersion,
  });
}
