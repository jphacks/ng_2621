import 'dart:convert';

import 'package:flutter/services.dart';

import '../domain/zoo_world.dart';

class ZooRepository {
  ZooRepository({AssetBundle? bundle}) : _bundle = bundle ?? rootBundle;

  final AssetBundle _bundle;

  Future<ZooWorld> load() async {
    final source = await _bundle.loadString('assets/zoo/world.json');
    return ZooWorld.fromJson(jsonDecode(source) as Map<String, dynamic>);
  }
}
