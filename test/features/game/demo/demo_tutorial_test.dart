import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:zoo_study/features/game/demo/demo_tutorial_controller.dart';
import 'package:zoo_study/features/game/demo/presentation_repository.dart';
import 'package:zoo_study/features/game/domain/zoo_layout.dart';
import 'package:zoo_study/features/shop/domain/shop_catalog.dart';
import 'package:zoo_study/features/shop/domain/shop_repository.dart';
import 'package:zoo_study/features/study/demo_assignment_store.dart';
import 'package:zoo_study/features/zoo/domain/zoo_world.dart';
import 'package:zoo_study/features/zoo/presentation/zoo_controller.dart';

ZooWorld world() => ZooWorld.fromJson(
  jsonDecode(File('assets/zoo/world.json').readAsStringSync())
      as Map<String, dynamic>,
);
PresentationRepository create() => PresentationRepository(
  catalogLoader: () async => ShopCatalog.fromJson(
    jsonDecode(File('assets/zoo/shop_catalog.json').readAsStringSync())
        as Map<String, dynamic>,
  ),
  worldLoader: () async => world(),
);

void main() {
  test('whole tutorial reaches the grown zoo with actual reward, purchase and placement rules', () async {
    final repo = create();
    final tour = DemoTutorialController(repo);
    addTearDown(() {
      tour.dispose();
      repo.dispose();
    });
    expect(repo.coins, 0);
    expect(repo.snapshot.layout.enclosures, hasLength(1));
    expect(tour.step, DemoStep.assign);
    tour.distribute();
    expect(tour.step, DemoStep.submit);
    tour.submit('分数の計算を学びました。');
    expect(repo.coins, 30);
    tour.submit('分数の計算を学びました。');
    expect(repo.coins, 30);
    expect(tour.step, DemoStep.approve);
    tour.approve();
    tour.approve();
    expect(repo.coins, 100);
    expect(tour.step, DemoStep.buyRabbit);
    var sequence = 0;
    Future<void> buy(String id) async {
      await repo.purchase(
        PurchaseRequest(requestId: 'demo_buy_${sequence++}', itemId: id),
      );
    }

    Future<void> edit(LayoutEdit value) async {
      await repo.purchase(
        PurchaseRequest(
          requestId: 'demo_edit_${sequence++}',
          itemId: 'zoo_layout',
          layoutEdit: value,
        ),
      );
    }

    await buy('rabbit');
    expect(repo.coins, 0);
    expect(tour.step, DemoStep.placeRabbit);
    await edit(
      const LayoutEdit(
        kind: LayoutEditKind.assignAnimal,
        id: 'rabbit',
        enclosureId: PresentationRepository.starterPen,
      ),
    );
    expect(tour.step, DemoStep.expand);
    repo.grantExplorationBudget();
    repo.grantExplorationBudget();
    expect(repo.coins, 1500);
    expect(repo.snapshot.rewards.map((r) => r.amount), [30, 70]);
    expect(tour.step, DemoStep.pond);
    await buy('pond');
    await edit(
      const LayoutEdit(
        kind: LayoutEditKind.facility,
        id: 'pond',
        left: 14,
        top: 11,
      ),
    );
    expect(tour.step, DemoStep.research);
    await buy('fox');
    await buy('laboratory');
    await edit(
      const LayoutEdit(
        kind: LayoutEditKind.facility,
        id: 'laboratory',
        left: 11,
        top: 0,
      ),
    );
    expect(tour.step, DemoStep.evolve);
    await buy('fire_fox');
    expect(repo.coins, 150);
    expect(tour.step, DemoStep.placeEvolution);
    await edit(
      const LayoutEdit(
        kind: LayoutEditKind.assignAnimal,
        id: 'fire_fox',
        enclosureId: PresentationRepository.starterPen,
      ),
    );
    expect(tour.step, DemoStep.collection);
    tour.seeCollection();
    expect(tour.step, DemoStep.grown);
    await repo.showGrownZoo();
    expect(tour.step, DemoStep.complete);
    expect(repo.snapshot.ownedAnimalIds, hasLength(27));
    expect(repo.snapshot.layout.enclosures, hasLength(4));
    expect(repo.coins, 150);
    expect(repo.snapshot.rewards, hasLength(2));
    final revision = repo.snapshot.revision;
    await repo.showGrownZoo();
    expect(repo.snapshot.revision, revision);
    final park = ZooController(
      world(),
      layout: repo.snapshot.layout,
      ownedAnimalIds: repo.snapshot.ownedAnimalIds,
      ownedFacilityIds: repo.snapshot.ownedFacilityIds,
    );
    addTearDown(park.dispose);
    expect(park.animals, hasLength(27));
    park.advance(1);
    for (final animal in park.animals) {
      expect(animal.movementArea.contains(animal.position), isTrue);
    }
  });

  test(
    'sandbox isolation and fresh reset do not mutate an existing study account',
    () {
      final ordinary = DemoAssignmentStore();
      final before = ordinary.snapshot.toJson();
      final repo = create();
      final tour = DemoTutorialController(repo);
      tour.distribute();
      tour.submit('回答');
      tour.approve();
      repo.grantExplorationBudget();
      expect(ordinary.snapshot.toJson(), before);
      expect(ordinary.assignments, isEmpty);
      tour.dispose();
      repo.dispose();
      final fresh = create();
      expect(fresh.coins, 0);
      expect(fresh.assignments, isEmpty);
      expect(fresh.snapshot.ownedAnimalIds, isEmpty);
      expect(fresh.budgetGranted, isFalse);
      fresh.dispose();
      ordinary.dispose();
    },
  );
}
