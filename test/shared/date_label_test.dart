import 'package:easy_localization/easy_localization.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:spor_takip/shared/date_label.dart';

void main() {
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await EasyLocalization.ensureInitialized();
  });

  final now = DateTime(2026, 10, 5);

  test('day and month, the year only when it differs', () {
    expect(shortDateLabel(DateTime(2026, 10, 4), now), '4 ${'home.month_10'.tr()}');
    expect(shortDateLabel(DateTime(2025, 12, 30), now), '30 ${'home.month_12'.tr()} 2025');
  });
}
