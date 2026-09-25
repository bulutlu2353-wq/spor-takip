/// Programın haftaya nasıl yerleştiği: haftanın sabit günlerine mi, yoksa
/// sıralı bir döngü olarak mı (hangi gün gidilirse sıradaki antrenman).
enum ScheduleMode { weekdays, rotation }

ScheduleMode scheduleModeFromDb(String value) => ScheduleMode.values.byName(value);

String scheduleModeToDb(ScheduleMode mode) => mode.name;
