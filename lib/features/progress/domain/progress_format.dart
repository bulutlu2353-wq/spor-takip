import '../../workout/domain/block_format.dart' show trimNumber;

/// Saatsiz yerel gün.
DateTime dateOnly(DateTime t) => DateTime(t.year, t.month, t.day);

String _two(int n) => n.toString().padLeft(2, '0');

/// Veritabanı `date` biçimi: `2026-09-28`.
String formatDbDate(DateTime d) => '${d.year.toString().padLeft(4, '0')}-${_two(d.month)}-${_two(d.day)}';

/// `2026-09-28` → yerel 28.9.2026 00:00.
DateTime parseDbDate(String value) {
  final parts = value.split('-').map(int.parse).toList();
  return DateTime(parts[0], parts[1], parts[2]);
}

/// `28.9.2026`
String formatShortDate(DateTime d) => '${d.day}.${d.month}.${d.year}';

/// En fazla bir ondalık: 80 → "80", 80.25 → "80.3".
String formatOneDecimal(double value) => trimNumber((value * 10).round() / 10);

/// Fark: null → "—", (yuvarlanmış) 0 → "0", artı → "▲ 1.5", eksi → "▼ 1.5".
String formatDelta(double? delta) {
  if (delta == null) return '—';
  final rounded = (delta * 10).round() / 10;
  if (rounded == 0) return '0';
  return '${rounded > 0 ? '▲' : '▼'} ${formatOneDecimal(rounded.abs())}';
}

/// Kullanıcı girdisi: "80,5" ya da "80.5"; boş ya da geçersiz → null.
double? parseDecimal(String input) => double.tryParse(input.trim().replaceAll(',', '.'));
