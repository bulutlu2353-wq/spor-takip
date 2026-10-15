import 'package:spor_takip/features/notifications/data/reminder_scheduler.dart';
import 'package:spor_takip/features/notifications/domain/planned_reminder.dart';

class FakeReminderScheduler implements ReminderScheduler {
  FakeReminderScheduler({this.permission = true, this.requestResult = true, this.launchRoute});

  bool permission;
  bool requestResult;
  String? launchRoute;
  void Function(String route)? onTap;
  final replaced = <List<PlannedReminder>>[];
  final translated = <List<String>>[];
  int cancels = 0;
  int permissionRequests = 0;
  int settingsOpened = 0;

  @override
  Future<String?> init(void Function(String route) onTap) async {
    this.onTap = onTap;
    return launchRoute;
  }

  @override
  Future<bool> hasPermission() async => permission;

  @override
  Future<bool> requestPermission() async {
    permissionRequests++;
    permission = requestResult;
    return requestResult;
  }

  @override
  Future<void> openSystemSettings() async => settingsOpened++;

  @override
  Future<void> replaceAll(List<PlannedReminder> plan, ReminderTranslator tr) async {
    replaced.add(plan);
    translated.add([for (final r in plan) tr(r.bodyKey, r.args)]);
  }

  @override
  Future<void> cancelAll() async => cancels++;
}
