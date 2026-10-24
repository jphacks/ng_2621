import 'package:flutter_test/flutter_test.dart';
import 'package:zoo_study/main.dart';

void main() {
  testWidgets('ZooStudy displays role selection', (tester) async {
    await tester.pumpWidget(const ZooStudyApp());
    expect(find.text('ZooっとStudy'), findsOneWidget);
    expect(find.text('先生はこちら'), findsOneWidget);
    expect(find.text('生徒はこちら'), findsOneWidget);
  });
}
