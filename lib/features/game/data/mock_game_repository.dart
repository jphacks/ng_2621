import 'dart:async';

import '../domain/game_repository.dart';
import '../domain/game_snapshot.dart';
import '../../shop/domain/shop_repository.dart';
import '../../shop/domain/shop_catalog.dart';
import '../../shop/data/shop_catalog_loader.dart';

enum DemoScenario { assigned, submitted, needsRevision, resubmitted, approved }

/// Development fixture adapter only. Never a source of production rewards.
class MockGameRepository implements GameRepository, ShopRepository {
  MockGameRepository({
    DemoScenario scenario = DemoScenario.assigned,
    Future<ShopCatalog> Function()? catalogLoader,
  }) : _current = snapshotFor(scenario),
       _catalogLoader = catalogLoader ?? loadShopCatalog;

  GameSnapshot _current;

  /// Read-only state for the local interactive demo adapter.
  GameSnapshot get currentSnapshot => _current;
  final Future<ShopCatalog> Function() _catalogLoader;
  ShopCatalog? _catalog;
  final _purchases = <String, PurchaseReceipt>{};

  @override
  Future<ShopCatalog> loadCatalog() async =>
      _catalog ??= await _catalogLoader();

  @override
  Future<PurchaseReceipt> purchase(PurchaseRequest request) async {
    if (!RegExp(r'^[A-Za-z0-9_-]{1,128}$').hasMatch(request.requestId) ||
        request.itemId.isEmpty) {
      throw const PurchaseFailure(PurchaseFailureCode.invalidRequest);
    }
    final catalog = await loadCatalog();
    // No await between this check and the snapshot/receipt commit.
    final previous = _purchases[request.requestId];
    if (previous != null) {
      if (previous.itemId != request.itemId) {
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
    _current = snapshot;
    _changes.add(snapshot);
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
