import 'package:flutter_test/flutter_test.dart';
import 'package:zoo_study/main.dart';

void main() {
  testWidgets('ZooっとStudy starts successfully', (WidgetTester tester) async {
    await tester.pumpWidget(const ZooStudyApp());

    expect(find.text('ZooっとStudy'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
