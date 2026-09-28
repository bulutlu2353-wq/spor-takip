import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/body_weight_log.dart';
import '../domain/profile_weight_update.dart';
import '../domain/progress_format.dart';

/// Kullanıcının tek kilo kaydı silinemez (profildeki kilonun kaynağı).
class LastWeightLogException implements Exception {}

/// Silme sırasında uygulamanın kilo listesi sunucudakiyle uyuşmadı.
class StaleWeightListException implements Exception {}

abstract interface class BodyWeightRepository {
  /// Eskiden yeniye.
  Future<List<BodyWeightLog>> fetchLogs();

  /// `log_body_weight` RPC: [date] gününe yazar (varsa üzerine); kayıt en
  /// yeniyse profil [update] ile güncellenir.
  Future<void> logWeight({required DateTime date, required ProfileWeightUpdate update});

  /// `delete_body_weight` RPC. [newLatest]: silinen kayıt en yeniyse kalan en
  /// yeni kaydın kilosu ve hedefleri, değilse null. Tek kayıtsa
  /// [LastWeightLogException], liste eskiyse [StaleWeightListException].
  Future<void> deleteLog({required DateTime date, ProfileWeightUpdate? newLatest});
}

class SupabaseBodyWeightRepository implements BodyWeightRepository {
  SupabaseBodyWeightRepository(this._client);

  final SupabaseClient _client;

  @override
  Future<List<BodyWeightLog>> fetchLogs() async {
    // PostgREST en fazla 1000 satır döner: yeniden eskiye çekilir ki sınır
    // aşılırsa en eskiler düşsün.
    final rows = await _client
        .from('body_weight_logs')
        .select('logged_on, weight_kg')
        .order('logged_on', ascending: false);
    return [for (final row in rows.reversed) BodyWeightLog.fromJson(row)];
  }

  @override
  Future<void> logWeight({required DateTime date, required ProfileWeightUpdate update}) async {
    await _client.rpc('log_body_weight', params: {
      'p_date': formatDbDate(date),
      'p_kg': update.weightKg,
      'p_calorie_target': update.calorieTarget,
      'p_protein_target': update.proteinTargetG,
    });
  }

  @override
  Future<void> deleteLog({required DateTime date, ProfileWeightUpdate? newLatest}) async {
    try {
      await _client.rpc('delete_body_weight', params: {
        'p_date': formatDbDate(date),
        'p_new_latest_kg': newLatest?.weightKg,
        'p_calorie_target': newLatest?.calorieTarget,
        'p_protein_target': newLatest?.proteinTargetG,
      });
    } on PostgrestException catch (error) {
      if (error.message.contains('last_weight_log')) throw LastWeightLogException();
      if (error.message.contains('stale_weight_list')) throw StaleWeightListException();
      rethrow;
    }
  }
}
