import 'dart:async';

import 'package:app_settings/app_settings.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

import '../domain/planned_reminder.dart';
import 'reminder_scheduler.dart';

/// `flutter_local_notifications` ile yerel zamanlama (N1 spec §4.2). `init` bitmeden
/// gelen çağrılar onu bekler.
class LocalReminderScheduler implements ReminderScheduler {
  LocalReminderScheduler._();

  static final instance = LocalReminderScheduler._();

  static const _channelId = 'reminders';

  final _plugin = FlutterLocalNotificationsPlugin();
  final _ready = Completer<void>();

  AndroidFlutterLocalNotificationsPlugin? get _android =>
      _plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();

  @override
  Future<String?> init(void Function(String route) onTap) async {
    try {
      tz_data.initializeTimeZones();
      try {
        final zone = await FlutterTimezone.getLocalTimezone();
        tz.setLocalLocation(tz.getLocation(zone.identifier));
      } catch (e) {
        debugPrint('local time zone unavailable, using UTC: $e');
      }
      await _plugin.initialize(
        settings: const InitializationSettings(
          android: AndroidInitializationSettings('@mipmap/ic_launcher'),
          iOS: DarwinInitializationSettings(
            requestAlertPermission: false,
            requestBadgePermission: false,
            requestSoundPermission: false,
          ),
        ),
        onDidReceiveNotificationResponse: (response) {
          final route = response.payload;
          if (route != null && route.isNotEmpty) onTap(route);
        },
      );
      final launch = await _plugin.getNotificationAppLaunchDetails();
      final route = launch?.notificationResponse?.payload;
      return launch?.didNotificationLaunchApp == true && route != null && route.isNotEmpty ? route : null;
    } finally {
      if (!_ready.isCompleted) _ready.complete();
    }
  }

  @override
  Future<bool> hasPermission() async {
    await _ready.future;
    return await _android?.areNotificationsEnabled() ?? false;
  }

  @override
  Future<bool> requestPermission() async {
    await _ready.future;
    final android = _android;
    if (android != null) return await android.requestNotificationsPermission() ?? false;
    final ios = _plugin.resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>();
    return await ios?.requestPermissions(alert: true, badge: true, sound: true) ?? false;
  }

  @override
  Future<void> openSystemSettings() => AppSettings.openAppSettings(type: AppSettingsType.notification);

  @override
  Future<void> replaceAll(List<PlannedReminder> plan, ReminderTranslator tr) async {
    await _ready.future;
    await _plugin.cancelAll();
    final details = NotificationDetails(
      android: AndroidNotificationDetails(
        _channelId,
        tr('notifications.channel_name', const {}),
        channelDescription: tr('notifications.channel_desc', const {}),
      ),
      iOS: const DarwinNotificationDetails(),
    );
    for (final reminder in plan) {
      final at = reminder.at;
      await _plugin.zonedSchedule(
        id: reminder.id,
        title: tr(reminder.titleKey, reminder.args),
        body: tr(reminder.bodyKey, reminder.args),
        scheduledDate: tz.TZDateTime(tz.local, at.year, at.month, at.day, at.hour, at.minute),
        notificationDetails: details,
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        payload: reminder.route,
      );
    }
  }

  @override
  Future<void> cancelAll() async {
    await _ready.future;
    await _plugin.cancelAll();
  }
}
