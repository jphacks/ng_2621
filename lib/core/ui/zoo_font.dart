import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Bundled font: no network access or additional package is needed at runtime.
class ZooFont {
  static const family = 'DotGothic16';
  static bool _registered = false;

  static void registerLicense() {
    if (_registered) return;
    _registered = true;
    LicenseRegistry.addLicense(() async* {
      yield LicenseEntryWithLineBreaks([
        family,
      ], await rootBundle.loadString('assets/fonts/OFL-DotGothic16.txt'));
    });
  }
}
