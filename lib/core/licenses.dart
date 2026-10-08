import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

const bodyHighlighterLicenseAsset = 'LICENSES/body-highlighter.txt';

/// Uygulamaya gömülü üçüncü taraf verilerin lisansları (Flutter lisans sayfasında görünür).
void registerLicenses() {
  LicenseRegistry.addLicense(() async* {
    final text = await rootBundle.loadString(bodyHighlighterLicenseAsset);
    yield LicenseEntryWithLineBreaks(const ['react-native-body-highlighter'], text);
  });
}
