import 'package:flutter/foundation.dart';

import '../../study/study_repository.dart';
import '../domain/game_snapshot.dart';
import 'presentation_repository.dart';

enum DemoStep {
  assign,
  submit,
  approve,
  buyRabbit,
  placeRabbit,
  expand,
  pond,
  research,
  evolve,
  placeEvolution,
  collection,
  grown,
  complete,
}

class DemoTutorialController extends ChangeNotifier {
  DemoTutorialController(this.repository) {
    repository.addListener(_changed);
  }
  final PresentationRepository repository;
  static const assignmentId = 'presentation_assignment';
  bool _collectionSeen = false;
  bool get hasFox => repository.snapshot.ownedAnimalIds.contains('fox');
  bool get hasLab =>
      repository.snapshot.ownedFacilityIds.contains('laboratory');
  bool get labPlaced =>
      repository.snapshot.layout.facilities.containsKey('laboratory');
  bool get hasPond => repository.snapshot.ownedFacilityIds.contains('pond');
  DemoStep get step {
    if (repository.grownShown) return DemoStep.complete;
    final data = repository.snapshot;
    if (!repository.assignments.any((a) => a.id == assignmentId)) {
      return DemoStep.assign;
    }
    final submitted = repository.submissionFor(assignmentId);
    if (submitted == null) return DemoStep.submit;
    if (submitted.status != AssignmentState.approved) return DemoStep.approve;
    if (!data.ownedAnimalIds.contains('rabbit')) return DemoStep.buyRabbit;
    if (!data.layout.animalEnclosures.containsKey('rabbit')) {
      return DemoStep.placeRabbit;
    }
    if (!repository.budgetGranted) return DemoStep.expand;
    if (!data.layout.facilities.containsKey('pond')) return DemoStep.pond;
    if (!hasFox || !hasLab || !labPlaced) return DemoStep.research;
    if (!data.ownedAnimalIds.contains('fire_fox')) return DemoStep.evolve;
    if (!data.layout.animalEnclosures.containsKey('fire_fox')) {
      return DemoStep.placeEvolution;
    }
    if (!_collectionSeen) return DemoStep.collection;
    return DemoStep.grown;
  }

  String get title => switch (step) {
    DemoStep.assign => '先生役：課題を配布',
    DemoStep.submit => '生徒役：回答を提出して＋30',
    DemoStep.approve => '先生役：確認・承認して＋70',
    DemoStep.buyRabbit => '100コインでウサギを迎える',
    DemoStep.placeRabbit => '無料の最初の囲いに配置',
    DemoStep.expand => '動物園が育ちました！次は施設へ',
    DemoStep.pond => hasPond ? '池をマップに配置' : '施設の購入を体験',
    DemoStep.research =>
      !hasFox
          ? '進化元のキツネを迎える'
          : !hasLab
          ? '研究所を購入'
          : '研究所をマップに配置',
    DemoStep.evolve => '研究所で炎狐を解放',
    DemoStep.placeEvolution => '炎狐も囲いに配置',
    DemoStep.collection => '図鑑で次の目標を見つける',
    DemoStep.grown => '完成イメージ：育った動物園へ',
    DemoStep.complete => '学びの先に、こんな動物園が待っている',
  };
  String get actionLabel => switch (step) {
    DemoStep.assign => '課題を配布',
    DemoStep.submit => '回答する',
    DemoStep.approve => '回答を確認',
    DemoStep.buyRabbit => 'ショップへ',
    DemoStep.placeRabbit || DemoStep.placeEvolution => '配置する',
    DemoStep.expand => '施設体験へ',
    DemoStep.pond => hasPond ? '配置する' : '池を見る',
    DemoStep.research =>
      !hasFox
          ? 'キツネを見る'
          : !hasLab
          ? '研究所を見る'
          : '配置する',
    DemoStep.evolve => '研究所へ',
    DemoStep.collection => '図鑑を見る',
    DemoStep.grown => '育った園を見る',
    DemoStep.complete => '全景を表示',
  };
  String get explanation => switch (step) {
    DemoStep.assign => '先生役と生徒役を、この端末で交代しながら体験します。まずデモ課題を配布します。',
    DemoStep.submit => '用意した回答をそのまま使えます。初回提出で30コインが届きます。',
    DemoStep.approve => '提出された回答を読んで承認します。追加70コイン、合計100コインになります。',
    DemoStep.buyRabbit => 'ウサギのアイコンを選び、詳細画面で購入を確認してください。',
    DemoStep.placeRabbit => '最初の囲いはデモ用に無料で用意済みです。区画を選ぶと動物園で動き始めます。',
    DemoStep.expand => 'ここからは施設と進化を試すため、体験用1,500コインを追加します。課題の報酬とは別のデモ資金です。',
    DemoStep.pond =>
      hasPond ? '配置画面で位置を選び、確定してください。選択枠はドラッグできます。' : '施設へ分類を切り替え、池を購入しましょう。',
    DemoStep.research =>
      !hasFox
          ? '進化元となるキツネを購入します。'
          : !hasLab
          ? '研究所を購入します。進化には施設の購入と配置が必要です。'
          : '研究所を配置して確定しましょう。',
    DemoStep.evolve => '炎狐を選び、条件と費用を確認して進化します。元のキツネは残ります。',
    DemoStep.placeEvolution => 'ウサギと同じ囲いに炎狐を配置できます。1つの囲いに複数の動物が暮らせます。',
    DemoStep.collection => '未所持の動物はロック表示。集めたい動物を次の学習目標にできます。',
    DemoStep.grown => '図鑑を閉じて完成イメージへ。27種類の動物と施設を、デモ用の育った動物園として配置します。追加の動物・施設は将来の完成イメージで、課題報酬や通常の購入結果とは別です。',
    DemoStep.complete => '体験完了。ここはデモ用の完成イメージです。実際の課題報酬は提出30＋承認70コインでした。最初からやり直すことも、学習タブで任意の機能を試すこともできます。',
  };
  void distribute() => repository.publish(
    DemoAssignment(
      id: assignmentId,
      subject: AssignmentSubject.other,
      title: '今日の学習をふり返ろう',
      description: '今日わかったことを1つ書いて提出してください。',
      dueAt: DateTime.now().add(const Duration(days: 1)),
    ),
  );
  void submit(String answer) =>
      repository.submit(assignmentId, answer, role: DemoStudyRole.student);
  void approve() => repository.review(
    assignmentId,
    role: DemoStudyRole.teacher,
    approve: true,
    feedback: 'よく頑張りました！',
    expectedVersion: repository.submissionFor(assignmentId)?.version,
  );
  void seeCollection() {
    _collectionSeen = true;
    notifyListeners();
  }

  void _changed() => notifyListeners();
  @override
  void dispose() {
    repository.removeListener(_changed);
    super.dispose();
  }
}
