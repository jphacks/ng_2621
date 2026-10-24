import 'package:flutter/material.dart';

import 'app_bootstrap.dart';
export 'app.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const AppBootstrap());
}
