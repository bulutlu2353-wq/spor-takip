import '../domain/planned_reminder.dart';

typedef ReminderTranslator = String Function(String key, Map<String, String> args);

/// Bildirim zamanlayıcısı (N1 spec §4.2). Mobilde `LocalReminderScheduler`, web'de Noop.
abstract interface class ReminderScheduler {
  /// Eklentiyi kurar; dokunulan bildirimin rotası [onTap]'e gelir. Uygulama bir
  /// bildirimle açıldıysa o bildirimin rotasını döndürür.
  Future<String?> init(void Function(String route) onTap);

  Future<bool> hasPermission();

  Future<bool> requestPermission();

  /// Uygulamanın sistem bildirim ayarlarını açar.
  Future<void> openSystemSettings();

  /// Bekleyen her şeyi iptal edip [plan]'ı kurar; metinler [tr] ile çevrilir.
  Future<void> replaceAll(List<PlannedReminder> plan, ReminderTranslator tr);

  Future<void> cancelAll();
}

/// Web için: hiçbir şey zamanlamaz.
class NoopReminderScheduler implements ReminderScheduler {
  const NoopReminderScheduler();

  @override
  Future<String?> init(void Function(String route) onTap) async => null;

  @override
  Future<bool> hasPermission() async => false;

  @override
  Future<bool> requestPermission() async => false;

  @override
  Future<void> openSystemSettings() async {}

  @override
  Future<void> replaceAll(List<PlannedReminder> plan, ReminderTranslator tr) async {}

  @override
  Future<void> cancelAll() async {}
}
