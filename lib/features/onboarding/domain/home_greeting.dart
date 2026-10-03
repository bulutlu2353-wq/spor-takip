/// Saate göre selam çeviri anahtarı (spec §5): 05–12 sabah, 12–18 gün, 18–05 akşam.
String greetingKey(DateTime now) {
  final hour = now.hour;
  if (hour >= 5 && hour < 12) return 'home.greeting_morning';
  if (hour >= 12 && hour < 18) return 'home.greeting_day';
  return 'home.greeting_evening';
}
