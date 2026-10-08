import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spor_takip/core/licenses.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('registers the body-highlighter MIT license', () async {
    // Flutter'ın NOTICES toplayıcısı test paketinde olmayabilir; yalnız bizimkini ölç.
    LicenseRegistry.reset();
    registerLicenses();

    final entries = await LicenseRegistry.licenses.toList();
    final entry = entries.singleWhere((e) => e.packages.contains('react-native-body-highlighter'));
    final text = entry.paragraphs.map((p) => p.text).join('\n');
    expect(text, contains('MIT License'));
    expect(text, contains('Copyright (c) 2022 ELABBASSI Hicham'));
  });
}
