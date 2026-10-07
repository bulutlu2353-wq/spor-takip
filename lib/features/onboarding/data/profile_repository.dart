import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/profile.dart';

class ProfileRepository {
  ProfileRepository(this._client);

  final SupabaseClient _client;

  static const _table = 'profiles';

  Future<Profile?> fetchProfile(String userId) async {
    final row = await _client
        .from(_table)
        .select()
        .eq('user_id', userId)
        .maybeSingle();
    if (row == null) return null;
    return Profile.fromJson(row);
  }

  Future<void> saveProfile(Profile profile) {
    return _client.from(_table).upsert(profile.toJson());
  }

  /// Yalnız verilen sütunları günceller (ayarlar ekranı, G2 spec §3.3).
  Future<void> updateProfile(String userId, Map<String, dynamic> fields) {
    return _client.from(_table).update(fields).eq('user_id', userId);
  }
}
