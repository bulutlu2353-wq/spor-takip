import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../domain/notification_settings.dart';

const notificationSettingsKey = 'notification_settings_v1';

/// Ayarlar cihazda (N1 spec §2.3); okunamazsa varsayılanlar.
class NotificationSettingsStore {
  const NotificationSettingsStore();

  Future<NotificationSettings> load() async {
    try {
      final raw = (await SharedPreferences.getInstance()).getString(notificationSettingsKey);
      return raw == null ? NotificationSettings.defaults : NotificationSettings.fromJson(jsonDecode(raw));
    } catch (e) {
      debugPrint('notification settings load failed: $e');
      return NotificationSettings.defaults;
    }
  }

  Future<void> save(NotificationSettings settings) async {
    try {
      await (await SharedPreferences.getInstance()).setString(notificationSettingsKey, jsonEncode(settings.toJson()));
    } catch (e) {
      debugPrint('notification settings save failed: $e');
    }
  }
}
