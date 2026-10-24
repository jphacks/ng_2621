import 'dart:math';

import 'package:flutter/foundation.dart';

import '../domain/zoo_layout.dart';
import '../../shop/domain/shop_repository.dart';
import 'game_session.dart';

/// Kept by ZooScreen so uncertain replies can be retried with the same identity.
class LayoutTransactions extends ChangeNotifier {
  LayoutTransactions(this.session) {
    session.addListener(_changed);
  }
  final GameSession session;
  PurchaseRequest? _pending;
  PurchaseReceipt? _receipt;
  LayoutEdit? lastEdit;
  bool busy = false, uncertain = false, _disposed = false;
  String? message;
  bool get awaitingSnapshot =>
      _receipt != null &&
      (session.snapshot?.revision ?? -1) < _receipt!.revision;
  bool get blocked => busy || uncertain || awaitingSnapshot;
  void _changed() {
    if (!_disposed) notifyListeners();
  }

  Future<bool> submit(LayoutEdit edit) async {
    if (blocked) return false;
    final repository = session.repository;
    if (repository is! ShopRepository ||
        session.failed ||
        session.loading ||
        session.snapshot == null) {
      message = '購入先に接続できません';
      _changed();
      return false;
    }
    final random = Random.secure();
    final id = List.generate(
      16,
      (_) => random.nextInt(256).toRadixString(16).padLeft(2, '0'),
    ).join();
    lastEdit = edit;
    _receipt = null;
    _pending = PurchaseRequest(
      requestId: id,
      itemId: 'zoo_layout',
      layoutEdit: edit,
    );
    return _send();
  }

  Future<bool> retry() async => uncertain && _pending != null ? _send() : false;
  Future<bool> _send() async {
    if (busy || session.repository is! ShopRepository) return false;
    busy = true;
    uncertain = false;
    message = null;
    _changed();
    try {
      final receipt = await (session.repository as ShopRepository)
          .purchase(_pending!)
          .timeout(const Duration(seconds: 20));
      if (_disposed) return false;
      if (receipt.requestId != _pending!.requestId ||
          receipt.itemId != 'zoo_layout' ||
          receipt.price < 0 ||
          receipt.revision < 0) {
        throw StateError('Invalid receipt');
      }
      _receipt = receipt;
      _pending = null;
      message = '確定しました';
    } on PurchaseFailure catch (e) {
      _pending = null;
      message = e.message;
    } catch (_) {
      uncertain = true;
      message = '結果が未確認です。同じ操作の結果を再確認してください。';
    }
    busy = false;
    _changed();
    return _receipt != null && !awaitingSnapshot;
  }

  @override
  void dispose() {
    _disposed = true;
    session.removeListener(_changed);
    super.dispose();
  }
}
