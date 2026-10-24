import 'shop_catalog.dart';

/// Identity comes from the bound session. Price and balance are never inputs.
class PurchaseRequest {
  const PurchaseRequest({required this.requestId, required this.itemId});
  final String requestId;
  final String itemId;
}

class PurchaseReceipt {
  const PurchaseReceipt({
    required this.requestId,
    required this.itemId,
    required this.price,
    required this.revision,
  });
  final String requestId;
  final String itemId;
  final int price;
  final int revision;
}

enum PurchaseFailureCode {
  insufficientCoins,
  alreadyOwned,
  locked,
  unknownItem,
  requestConflict,
  invalidRequest,
  unavailable,
}

class PurchaseFailure implements Exception {
  const PurchaseFailure(this.code);
  final PurchaseFailureCode code;
  String get message => switch (code) {
    PurchaseFailureCode.insufficientCoins => 'コインが足りません',
    PurchaseFailureCode.alreadyOwned => 'すでに購入済みです',
    PurchaseFailureCode.locked => '解放条件を満たしていません',
    PurchaseFailureCode.unknownItem => '商品が見つかりません',
    PurchaseFailureCode.requestConflict => '購入リクエストが一致しません',
    PurchaseFailureCode.invalidRequest => '購入リクエストが無効です',
    PurchaseFailureCode.unavailable => '購入先に接続できません',
  };
}

abstract interface class ShopRepository {
  Future<ShopCatalog> loadCatalog();
  Future<PurchaseReceipt> purchase(PurchaseRequest request);
}
