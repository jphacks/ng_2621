import 'dart:async';

import '../domain/game_repository.dart';
import '../domain/game_snapshot.dart';
import '../domain/zoo_layout.dart';
import '../../zoo/data/zoo_repository.dart';
import '../../zoo/domain/zoo_world.dart';
import 'layout_mutation.dart';
import '../../shop/domain/shop_repository.dart';
import '../../shop/domain/shop_catalog.dart';
import '../../shop/data/shop_catalog_loader.dart';

enum DemoScenario { assigned, submitted, needsRevision, resubmitted, approved }

/// Development fixture adapter only. Never a source of production rewards.
class MockGameRepository implements GameRepository, ShopRepository {
  MockGameRepository({
    DemoScenario scenario = DemoScenario.assigned,
    Future<ShopCatalog> Function()? catalogLoader,
    int bonusCoins = 0,
    Future<ZooWorld> Function()? worldLoader,
  }) : _current = _initialSnapshot(scenario, bonusCoins),
       _catalogLoader = catalogLoader ?? loadShopCatalog,
       _worldLoader = worldLoader ?? ZooRepository().load;

  static GameSnapshot _initialSnapshot(DemoScenario scenario, int bonusCoins) {
    if (bonusCoins < 0) throw ArgumentError.value(bonusCoins, 'bonusCoins');
    final data = snapshotFor(scenario).toJson();
    data['coins'] = (data['coins'] as int) + bonusCoins;
    return GameSnapshot.fromJson(data);
  }

  GameSnapshot _current;

  /// Read-only state for the local interactive demo adapter.
  GameSnapshot get currentSnapshot => _current;
  final Future<ShopCatalog> Function() _catalogLoader;
  ShopCatalog? _catalog;
  final _purchases = <String, PurchaseReceipt>{};
  final _layoutEdits = <String, LayoutEdit>{};
  final Future<ZooWorld> Function() _worldLoader;
  ZooWorld? _loadedWorld;

  Future<PurchaseReceipt> _editLayout(PurchaseRequest request) async {
    final edit = request.layoutEdit!;
    if (request.itemId != 'zoo_layout' ||
        !RegExp(r'^[A-Za-z0-9_-]{1,128}$').hasMatch(request.requestId)) {
      throw const PurchaseFailure(PurchaseFailureCode.invalidRequest);
    }
    final world = _loadedWorld ??= await _worldLoader();
    final prior = _purchases[request.requestId];
    if (prior != null) {
      if (_layoutEdits[request.requestId] != edit) {
        throw const PurchaseFailure(PurchaseFailureCode.requestConflict);
      }
      return prior;
    }
    if (_changes.isClosed) {
      throw const PurchaseFailure(PurchaseFailureCode.unavailable);
    }
    // Validation, pricing, debit and layout commit are synchronous after the await.
    final result = applyLayoutEdit(_current, world, edit);
    final data = _current.toJson();
    data['coins'] = _current.coins - result.price;
    data['layout'] = result.layout.toJson();
    data['revision'] = _current.revision + 1;
    data['confirmedAt'] = DateTime.now().toUtc().toIso8601String();
    final next = GameSnapshot.fromJson(data);
    final receipt = PurchaseReceipt(
      requestId: request.requestId,
      itemId: request.itemId,
      price: result.price,
      revision: next.revision,
    );
    _layoutEdits[request.requestId] = edit;
    _purchases[request.requestId] = receipt;
    _current = next;
    _changes.add(next);
    return receipt;
  }

  @override
  Future<ShopCatalog> loadCatalog() async =>
      _catalog ??= await _catalogLoader();

  @override
  Future<PurchaseReceipt> purchase(PurchaseRequest request) async {
    if (request.layoutEdit != null) return _editLayout(request);
    if (!RegExp(r'^[A-Za-z0-9_-]{1,128}$').hasMatch(request.requestId) ||
        request.itemId.isEmpty) {
      throw const PurchaseFailure(PurchaseFailureCode.invalidRequest);
    }
    final catalog = await loadCatalog();
    // No await between this check and the snapshot/receipt commit.
    final previous = _purchases[request.requestId];
    if (previous != null) {
      if (previous.itemId != request.itemId ||
          _layoutEdits.containsKey(request.requestId)) {
        throw const PurchaseFailure(PurchaseFailureCode.requestConflict);
      }
      return previous;
    }
    if (_changes.isClosed) {
      throw const PurchaseFailure(PurchaseFailureCode.unavailable);
    }
    final item = catalog.items.where((i) => i.id == request.itemId).firstOrNull;
    if (item == null) {
      throw const PurchaseFailure(PurchaseFailureCode.unknownItem);
    }
    if (item.pricing != ShopPricing.fixed) {
      throw const PurchaseFailure(PurchaseFailureCode.invalidRequest);
    }
    if (item.isOwned(_current)) {
      throw const PurchaseFailure(PurchaseFailureCode.alreadyOwned);
    }
    if (!item.isUnlocked(_current)) {
      throw const PurchaseFailure(PurchaseFailureCode.locked);
    }
    if (_current.coins < item.price) {
      throw const PurchaseFailure(PurchaseFailureCode.insufficientCoins);
    }
    final data = _current.toJson();
    data['coins'] = _current.coins - item.price;
    data['revision'] = _current.revision + 1;
    data['confirmedAt'] = DateTime.now().toUtc().toIso8601String();
    final field = item.kind == ShopItemKind.animal
        ? 'ownedAnimalIds'
        : 'ownedFacilityIds';
    data[field] = [...data[field] as List, item.targetId];
    final next = GameSnapshot.fromJson(data);
    final receipt = PurchaseReceipt(
      requestId: request.requestId,
      itemId: item.id,
      price: item.price,
      revision: next.revision,
    );
    _purchases[request.requestId] = receipt;
    _current = next;
    _changes.add(next);
    return receipt;
  }

  /// Fixture event merging keeps prior spending and ownership intact.
  void receiveDemoScenario(DemoScenario scenario) {
    final data = snapshotFor(
      scenario,
      revision: _current.revision + 1,
    ).toJson();
    final receipts = {for (final r in _current.rewards) r.transactionId: r};
    var increase = 0;
    for (final raw in data['rewards'] as List) {
      final receipt = RewardReceipt.fromJson(raw as Map<String, dynamic>);
      if (!receipts.containsKey(receipt.transactionId)) {
        receipts[receipt.transactionId] = receipt;
        increase += receipt.amount;
      }
    }
    data['coins'] = _current.coins + increase;
    data['rewards'] = receipts.values.map((r) => r.toJson()).toList();
    data['ownedAnimalIds'] = _current.ownedAnimalIds.toList();
    data['ownedFacilityIds'] = _current.ownedFacilityIds.toList();
    receiveConfirmedSnapshot(GameSnapshot.fromJson(data));
  }

  final _changes = StreamController<GameSnapshot>.broadcast(sync: true);

  @override
  GameConnection get connection => GameConnection.demo;

  @override
  Stream<GameSnapshot> watchGameState() => Stream.multi((controller) {
    final subscription = _changes.stream.listen(
      controller.addSync,
      onError: controller.addErrorSync,
      onDone: controller.closeSync,
    );
    controller.addSync(_current);
    controller.onCancel = subscription.cancel;
  });

  /// Test harness entry point, deliberately absent from GameRepository.
  void receiveConfirmedSnapshot(GameSnapshot snapshot) {
    if (snapshot.organizationId != _current.organizationId ||
        snapshot.studentId != _current.studentId) {
      throw const FormatException('Cannot change mock session identity');
    }
    if (snapshot.revision <= _current.revision) return;
    // Assignment projections do not own layout. Preserve it when they refresh
    // rewards with an older DTO constructor; explicit nonempty test fixtures may seed it.
    final incoming = snapshot.layout;
    final data = snapshot.toJson();
    if (incoming.enclosures.isEmpty &&
        incoming.animalEnclosures.isEmpty &&
        incoming.facilities.isEmpty) {
      data['layout'] = _current.layout.toJson();
    }
    _current = GameSnapshot.fromJson(data);
    _changes.add(_current);
  }

  Future<void> dispose() => _changes.close();

  static GameSnapshot snapshotFor(DemoScenario scenario, {int? revision}) {
    final time = DateTime.utc(2026, 10, 24, 3);
    final submitted = scenario != DemoScenario.assigned;
    final approved = scenario == DemoScenario.approved;
    return GameSnapshot(
      organizationId: 'demo_org',
      studentId: 'demo_student',
      classIds: ['demo_class'],
      revision: revision ?? scenario.index,
      coins: approved
          ? 100
          : submitted
          ? 30
          : 0,
      confirmedAt: time.add(Duration(minutes: scenario.index)),
      assignments: [
        AssignmentSummary(
          id: 'demo_assignment',
          organizationId: 'demo_org',
          classId: 'demo_class',
          title: '数学プリント No.3',
          description: '指定された問題に取り組みましょう。',
          dueAt: DateTime.utc(2026, 10, 30, 14, 59),
          submittedAt: submitted ? time : null,
          state: switch (scenario) {
            DemoScenario.assigned => AssignmentState.notSubmitted,
            DemoScenario.needsRevision => AssignmentState.needsRevision,
            DemoScenario.approved => AssignmentState.approved,
            _ => AssignmentState.pendingReview,
          },
          revisionCount: scenario == DemoScenario.resubmitted || approved
              ? 1
              : 0,
          feedback: scenario == DemoScenario.needsRevision
              ? '途中の計算も書いてみよう。'
              : null,
        ),
      ],
      rewards: [
        if (submitted)
          RewardReceipt(
            assignmentId: 'demo_assignment',
            studentId: 'demo_student',
            kind: RewardKind.submit,
            amount: 30,
            confirmedAt: time,
          ),
        if (approved)
          RewardReceipt(
            assignmentId: 'demo_assignment',
            studentId: 'demo_student',
            kind: RewardKind.approve,
            amount: 70,
            confirmedAt: time.add(const Duration(minutes: 4)),
          ),
      ],
    );
  }
}
