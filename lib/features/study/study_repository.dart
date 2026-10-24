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
  FutureOr<void> publish(
    DemoAssignment assignment, {
    DemoStudyRole role = DemoStudyRole.teacher,
  });
  FutureOr<int> submit(String id, String answer, {required DemoStudyRole role});
  FutureOr<int> review(
    String id, {
    required DemoStudyRole role,
    required bool approve,
    String feedback = '',
    String? studentId,
    int? expectedVersion,
  });
}
