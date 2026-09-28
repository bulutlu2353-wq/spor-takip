import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/body_measurement.dart';
import '../domain/progress_format.dart';

abstract interface class BodyMeasurementRepository {
  /// Eskiden yeniye.
  Future<List<BodyMeasurement>> fetchMeasurements();

  /// Aynı tarihte ölçüm varsa üzerine yazar.
  Future<void> saveMeasurement(BodyMeasurement measurement);

  Future<void> deleteMeasurement(DateTime date);
}

class SupabaseBodyMeasurementRepository implements BodyMeasurementRepository {
  SupabaseBodyMeasurementRepository(this._client);

  final SupabaseClient _client;

  static const _table = 'body_measurements';

  @override
  Future<List<BodyMeasurement>> fetchMeasurements() async {
    final rows = await _client.from(_table).select().order('measured_on');
    return [for (final row in rows) BodyMeasurement.fromJson(row)];
  }

  @override
  Future<void> saveMeasurement(BodyMeasurement measurement) async {
    await _client.from(_table).upsert(
      {...measurement.toUpsertJson(), 'user_id': _client.auth.currentUser!.id},
      onConflict: 'user_id,measured_on',
    );
  }

  @override
  Future<void> deleteMeasurement(DateTime date) async {
    await _client.from(_table).delete().eq('measured_on', formatDbDate(date));
  }
}
