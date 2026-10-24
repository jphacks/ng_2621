import 'dart:math';

import 'package:flutter/foundation.dart';

import '../../game/presentation/game_session.dart';
import '../domain/shop_catalog.dart';
import '../domain/shop_repository.dart';

enum PurchaseStatus { idle, processing, success, rejected, uncertain }

/// Lives with the game screen so closing the shop does not lose a retry key.
class ShopPurchaseController extends ChangeNotifier {
  ShopPurchaseController(
    this.session, {
    this.purchaseTimeout = const Duration(seconds: 20),
  }) : assert(purchaseTimeout > Duration.zero) {
    session.addListener(_onState);
  }
  final GameSession session;
  final Duration purchaseTimeout;
  PurchaseStatus status = PurchaseStatus.idle;
  ShopItem? item;
  PurchaseReceipt? receipt;
  String? message;
  PurchaseRequest? _pending;
  bool _disposed = false;

  bool get busy => status == PurchaseStatus.processing;
  bool get uncertain => status == PurchaseStatus.uncertain;
  bool get awaitingSnapshot =>
      status == PurchaseStatus.success &&
      receipt != null &&
      ((session.snapshot?.revision ?? -1) < receipt!.revision ||
          session.snapshot == null ||
          !item!.isOwned(session.snapshot!));

  void _onState() {
    if (!_disposed) notifyListeners();
  }

  Future<void> buy(ShopItem target) async {
    if (_disposed || busy || uncertain || awaitingSnapshot) return;
    final snapshot = session.snapshot;
    if (snapshot == null ||
        session.failed ||
        session.loading ||
        session.repository is! ShopRepository) {
      _reject('購入先に接続できません。残高を再読み込みしてください。');
      return;
    }
    if (target.isOwned(snapshot)) {
      _reject('すでに購入済みです');
      return;
    }
    if (!target.isUnlocked(snapshot)) {
      _reject('解放条件を満たしていません');
      return;
    }
    if (snapshot.coins < target.price) {
      _reject('コインが足りません。残高を確認してください。');
      return;
    }
    item = target;
    receipt = null;
    final random = Random.secure();
    final key = List.generate(
      16,
      (_) => random.nextInt(256).toRadixString(16).padLeft(2, '0'),
    ).join();
    _pending = PurchaseRequest(requestId: key, itemId: target.id);
    await _send();
  }

  void _reject(String reason) {
    status = PurchaseStatus.rejected;
    message = reason;
    notifyListeners();
  }

  Future<void> retry() async {
    if (_disposed || !uncertain || _pending == null) return;
    await _send();
  }

  Future<void> _send() async {
    final repository = session.repository;
    if (repository is! ShopRepository || _pending == null) return;
    status = PurchaseStatus.processing;
    message = null;
    notifyListeners();
    try {
      final result = await (repository as ShopRepository)
          .purchase(_pending!)
          .timeout(purchaseTimeout);
      if (_disposed) return;
      if (result.requestId != _pending!.requestId ||
          result.itemId != _pending!.itemId ||
          result.price <= 0 ||
          result.revision < 0) {
        throw StateError('Inconsistent purchase receipt');
      }
      receipt = result;
      _pending = null;
      status = PurchaseStatus.success;
      message = '${item!.name}を購入しました';
    } on PurchaseFailure catch (error) {
      if (_disposed) return;
      _pending = null;
      status = PurchaseStatus.rejected;
      message = error.message;
    } catch (_) {
      if (_disposed) return;
      status = PurchaseStatus.uncertain;
      message = '購入できたか確認が必要です。もう一度結果を確認してください。';
    }
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    session.removeListener(_onState);
    super.dispose();
  }
}
