import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/friendship.dart';
import '../domain/player_stats.dart';
import '../domain/public_profile.dart';

/// Kullanıcı adı başkasında (benzersizlik ihlali, `23505`).
class UsernameTakenException implements Exception {}

abstract interface class SocialRepository {
  Future<PublicProfile?> fetchMyProfile();
  Future<PublicProfile> createProfile({required String username, required String displayName});
  Future<PublicProfile> updateProfile({
    String? username,
    String? displayName,
    bool? shareWeekly,
    bool? shareWorkouts,
    bool? shareHeat,
  });
  Future<bool> usernameAvailable(String username);
  Future<FoundUser?> findByUsername(String username);
  Future<FoundUser?> findByInviteCode(String code);
  Future<List<Friendship>> fetchFriendships();

  /// `'pending'`, `'accepted'` ya da `'already_friends'`.
  Future<String> sendRequest(String targetId);
  Future<void> respond(String requesterId, {required bool accept});
  Future<void> removeFriend(String otherId);
  Future<List<PublicProfile>> fetchProfiles(List<String> userIds);
  Future<Map<String, PlayerStats>> fetchStats(List<String> userIds);
  Future<void> upsertMyStats(PlayerStats stats);
}

class SupabaseSocialRepository implements SocialRepository {
  SupabaseSocialRepository(this._client);

  final SupabaseClient _client;

  static const _profileColumns =
      'user_id, username, display_name, invite_code, share_weekly, share_workouts, share_heat';

  String get _me => _client.auth.currentUser!.id;

  bool _isUnique(PostgrestException e, String column) => e.code == '23505' && e.message.contains(column);

  @override
  Future<PublicProfile?> fetchMyProfile() async {
    final row = await _client.from('public_profiles').select(_profileColumns).eq('user_id', _me).maybeSingle();
    return row == null ? null : PublicProfile.fromJson(row);
  }

  @override
  Future<PublicProfile> createProfile({required String username, required String displayName}) async {
    // Davet kodu çakışması (çok düşük olasılık) → yeniden dene.
    for (var attempt = 0;; attempt++) {
      try {
        final row = await _client
            .from('public_profiles')
            .insert({'user_id': _me, 'username': username, 'display_name': displayName.trim()})
            .select(_profileColumns)
            .single();
        return PublicProfile.fromJson(row);
      } on PostgrestException catch (e) {
        if (_isUnique(e, 'username')) throw UsernameTakenException();
        if (_isUnique(e, 'invite_code') && attempt < 2) continue;
        rethrow;
      }
    }
  }

  @override
  Future<PublicProfile> updateProfile({
    String? username,
    String? displayName,
    bool? shareWeekly,
    bool? shareWorkouts,
    bool? shareHeat,
  }) async {
    try {
      final row = await _client
          .from('public_profiles')
          .update({
            'username': ?username,
            'display_name': ?displayName?.trim(),
            'share_weekly': ?shareWeekly,
            'share_workouts': ?shareWorkouts,
            'share_heat': ?shareHeat,
            'updated_at': DateTime.now().toUtc().toIso8601String(),
          })
          .eq('user_id', _me)
          .select(_profileColumns)
          .single();
      return PublicProfile.fromJson(row);
    } on PostgrestException catch (e) {
      if (_isUnique(e, 'username')) throw UsernameTakenException();
      rethrow;
    }
  }

  @override
  Future<bool> usernameAvailable(String username) async =>
      await _client.rpc('username_available', params: {'p_username': username}) as bool;

  Future<FoundUser?> _first(Object? rows) {
    final list = rows as List? ?? const [];
    return Future.value(list.isEmpty ? null : FoundUser.fromJson(list.first as Map<String, dynamic>));
  }

  @override
  Future<FoundUser?> findByUsername(String username) async =>
      _first(await _client.rpc('find_user', params: {'p_username': username}));

  @override
  Future<FoundUser?> findByInviteCode(String code) async =>
      _first(await _client.rpc('find_user_by_invite', params: {'p_code': code}));

  @override
  Future<List<Friendship>> fetchFriendships() async {
    final rows = await _client.from('friendships').select('requester, addressee, status, created_at');
    return [for (final row in rows) Friendship.fromJson(row)];
  }

  @override
  Future<String> sendRequest(String targetId) async =>
      await _client.rpc('send_friend_request', params: {'p_target': targetId}) as String;

  @override
  Future<void> respond(String requesterId, {required bool accept}) async {
    await _client.rpc('respond_friend_request', params: {'p_requester': requesterId, 'p_accept': accept});
  }

  @override
  Future<void> removeFriend(String otherId) async {
    await _client.rpc('remove_friend', params: {'p_other': otherId});
  }

  @override
  Future<List<PublicProfile>> fetchProfiles(List<String> userIds) async {
    if (userIds.isEmpty) return const [];
    final rows = await _client.from('public_profiles').select(_profileColumns).inFilter('user_id', userIds);
    return [for (final row in rows) PublicProfile.fromJson(row)];
  }

  @override
  Future<Map<String, PlayerStats>> fetchStats(List<String> userIds) async {
    if (userIds.isEmpty) return const {};
    final rows = await _client.from('player_stats').select().inFilter('user_id', userIds);
    return {for (final row in rows) row['user_id'] as String: PlayerStats.fromJson(row)};
  }

  @override
  Future<void> upsertMyStats(PlayerStats stats) async {
    await _client.from('player_stats').upsert({
      ...stats.toJson(),
      'user_id': _me,
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    });
  }
}
