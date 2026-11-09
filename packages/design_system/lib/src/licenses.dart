import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

bool _registered = false;

/// Adds the bundled font and icon licenses to Flutter's license page. Pub
/// package licenses, including Material Symbols, are collected by Flutter.
void registerTankLoopLicenses() {
  if (_registered) return;
  _registered = true;
  LicenseRegistry.addLicense(() async* {
    for (final (name, file) in const [
      ('Plus Jakarta Sans', 'PlusJakartaSans-OFL.txt'),
      ('Playfair Display', 'PlayfairDisplay-OFL.txt'),
      ('Phosphor Icons', 'Phosphor-MIT.txt'),
      ('Lucide', 'Lucide-ISC.txt'),
    ]) {
      yield LicenseEntryWithLineBreaks(
        [name],
        await rootBundle.loadString(
          'packages/tankloop_design_system/assets/licenses/$file',
        ),
      );
    }
  });
}
