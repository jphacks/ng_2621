import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zoo_study/features/game/demo/presentation_repository.dart';
import 'package:zoo_study/features/game/domain/zoo_layout.dart';
import 'package:zoo_study/features/shop/domain/shop_repository.dart';

import 'demo_tutorial_ui_test.dart' show start, tour, frames, tap;

void main() {
  testWidgets(
    'installed lab opens research and a fence places the purchased rabbit with cancel support',
    (tester) async {
      await start(tester, const Size(390, 844));
      final repository = tour(tester).repository;
      await tester.runAsync(() async {
        await repository.purchase(
          const PurchaseRequest(requestId: 'map_buy_rabbit', itemId: 'rabbit'),
        );
        await repository.purchase(
          const PurchaseRequest(requestId: 'map_buy_lab', itemId: 'laboratory'),
        );
        await repository.purchase(
          const PurchaseRequest(
            requestId: 'map_place_lab',
            itemId: 'zoo_layout',
            layoutEdit: LayoutEdit(
              kind: LayoutEditKind.facility,
              id: 'laboratory',
              left: 11,
              top: 0,
            ),
          ),
        );
      });
      await frames(tester);
      Future<void> tapTile(Offset point) async {
        final terrain = tester.renderObject<RenderBox>(
          find.byKey(const ValueKey('zoo-terrain')),
        );
        await tester.tapAt(terrain.localToGlobal(point * 16));
        await frames(tester);
      }

      await tapTile(const Offset(12, 1));
      expect(find.text('進化しても元の動物は残ります。解放条件と価格を確認できます。'), findsOneWidget);
      await tester.tap(find.byTooltip('閉じる').hitTestable().last);
      await frames(tester);
      await tapTile(const Offset(3.7, 1.5));
      expect(find.text('この囲いに動物を入れる'), findsOneWidget);
      await tap(tester, 'pen-animal-rabbit');
      await tester.tap(find.text('キャンセル'));
      await frames(tester);
      expect(repository.snapshot.layout.animalEnclosures, isEmpty);
      await tapTile(const Offset(3.7, 1.5));
      await tap(tester, 'pen-animal-rabbit');
      await tap(tester, 'confirm-pen-animal');
      expect(
        repository.snapshot.layout.animalEnclosures['rabbit'],
        PresentationRepository.starterPen,
      );
      expect(repository.snapshot.coins, 2500);
      expect(find.text('最初の仲間を迎えよう'), findsNothing);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
}
