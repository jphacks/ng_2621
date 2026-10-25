import '../../study/study_models.dart';

/// Script shared by independent presentation phones. No transport or persistence.
abstract final class PresentationScenario {
  static const assignmentId = 'presentation_assignment';
  static const title = '今日の学習をふり返ろう';
  static const description = '今日わかったことを1つ書いて提出してください。';
  static const answer = '今日は分数の計算を学びました。';
  static const advice = 'よく頑張りました！分数の計算は、途中の式も書くと理解が深まります。次は文章題にも挑戦してみましょう。';
  static const submissionCoins = 30;
  static const approvalCoins = 70;
  static const initialCoins = 3000;
  static DemoAssignment assignment() => DemoAssignment(
    id: assignmentId,
    subject: AssignmentSubject.other,
    title: title,
    description: description,
    dueAt: DateTime(2026, 10, 31, 23, 59),
  );
}
