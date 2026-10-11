import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:spor_takip/features/notifications/data/notification_settings_store.dart';
import 'package:spor_takip/features/notifications/domain/notification_settings.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('missing settings load as the defaults', () async {
    expect(await const NotificationSettingsStore().load(), NotificationSettings.defaults);
  });

  test('saved settings load back', () async {
    final settings = NotificationSettings.defaults.copyWith(nutritionEnabled: true, nutritionTime: const ReminderTime(20, 15));
    await const NotificationSettingsStore().save(settings);
    expect(await const NotificationSettingsStore().load(), settings);
  });

  test('unreadable data loads as the defaults', () async {
    SharedPreferences.setMockInitialValues({notificationSettingsKey: 'not json'});
    expect(await const NotificationSettingsStore().load(), NotificationSettings.defaults);
  });
}
