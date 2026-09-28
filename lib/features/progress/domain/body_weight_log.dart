import 'progress_format.dart';

const maxBodyWeightKg = 500.0;

/// Veritabanındaki `check (weight_kg > 0 and weight_kg < 500)` ile aynı.
bool isValidBodyWeight(double kg) => kg > 0 && kg < maxBodyWeightKg;

/// Bir güne ait tek kilo kaydı.
class BodyWeightLog {
  const BodyWeightLog({required this.date, required this.weightKg});

  /// Yerel gün (saat 00:00).
  final DateTime date;
  final double weightKg;

  factory BodyWeightLog.fromJson(Map<String, dynamic> json) {
    return BodyWeightLog(
      date: parseDbDate(json['logged_on'] as String),
      weightKg: (json['weight_kg'] as num).toDouble(),
    );
  }
}
