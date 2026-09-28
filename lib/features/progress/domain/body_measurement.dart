import 'progress_format.dart';

const maxMeasurementCm = 300.0;

/// Veritabanındaki `check (x > 0 and x < 300)` ile aynı.
bool isValidMeasurement(double cm) => cm > 0 && cm < maxMeasurementCm;

/// Ölçü bölgeleri; `name` veritabanındaki sütun adıdır.
enum MeasurementSite { neck, shoulders, chest, waist, hips, arm, forearm, thigh, calf }

/// Bir güne ait ölçüm (cm).
class BodyMeasurement {
  const BodyMeasurement({required this.date, required this.values});

  /// Yerel gün (saat 00:00).
  final DateTime date;

  /// Yalnızca dolu bölgeler.
  final Map<MeasurementSite, double> values;

  factory BodyMeasurement.fromJson(Map<String, dynamic> json) {
    return BodyMeasurement(
      date: parseDbDate(json['measured_on'] as String),
      values: {
        for (final site in MeasurementSite.values)
          if (json[site.name] != null) site: (json[site.name] as num).toDouble(),
      },
    );
  }

  /// Upsert gövdesi (kullanıcı id'si hariç); boş bölgeler null yazılır ki
  /// düzenlemede silinen değerler de temizlensin.
  Map<String, dynamic> toUpsertJson() {
    return {
      'measured_on': formatDbDate(date),
      for (final site in MeasurementSite.values) site.name: values[site],
    };
  }
}

/// [measurements] eskiden yeniye. [site]'in en yeni değeri − bir önceki değeri;
/// bölge iki ölçümde dolu değilse null.
double? measurementChange(List<BodyMeasurement> measurements, MeasurementSite site) {
  final values = [for (final m in measurements) ?m.values[site]];
  if (values.length < 2) return null;
  return values.last - values[values.length - 2];
}
