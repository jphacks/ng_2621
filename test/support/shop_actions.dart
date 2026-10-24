import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> openShopItem(WidgetTester tester, String id) async {
  if (find.byKey(ValueKey('buy-$id')).evaluate().isNotEmpty) return;
  final card = find.byKey(ValueKey('shop-item-$id'));
  await tester.scrollUntilVisible(
    card,
    240,
    scrollable: find.byType(Scrollable).first,
  );
  await tester.pump();
  await tester.tap(card);
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
  await tester.pump();
}
