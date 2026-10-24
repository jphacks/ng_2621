import 'dart:convert';

import 'package:flutter/services.dart';

import '../domain/shop_catalog.dart';

Future<ShopCatalog> loadShopCatalog() async => ShopCatalog.fromJson(
  jsonDecode(await rootBundle.loadString('assets/zoo/shop_catalog.json'))
      as Map<String, dynamic>,
);
