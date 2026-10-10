import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/community.dart';
import '../domain/friendship.dart';
import '../domain/period_keys.dart';
import '../domain/period_stats.dart';
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
    bool? competeGlobally,
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
  Future<List<String>> fetchMyCommunityIds();
  Future<List<Community>> fetchCommunities(List<String> ids);

  /// Topluluk → üyeler (katılma sırasıyla).
  Future<Map<String, List<CommunityMember>>> fetchMembers(List<String> communityIds);
  Future<List<CommunitySearchResult>> searchCommunities(String query);

  /// Yeni topluluğun kimliği.
  Future<String> createCommunity({required String name, required String description, required bool isPublic});
  Future<void> joinCommunity(String id);

  /// Katılınan topluluğun kimliği.
  Future<String> joinCommunityByCode(String code);
  Future<void> leaveCommunity(String id);
  Future<void> updateCommunity(String id, {String? name, String? description, bool? isPublic});
  Future<void> removeMember(String communityId, String userId, {required bool ban});
  Future<String> regenerateCommunityCode(String id);
  Future<Map<String, PeriodStats>> fetchPeriodStats(List<String> userIds);
  Future<void> upsertMyPeriodStats(PeriodStats stats);
  Future<List<GlobalTitle>> globalTitles(PeriodKind kind, String key);
  Future<List<GlobalRow>> globalLeaderboard(PeriodKind kind, String key);
}

class SupabaseSocialRepository implements SocialRepository {
  SupabaseSocialRepository(this._client);

  final SupabaseClient _client;

  static const _profileColumns =
      'user_id, username, display_name, invite_code, share_weekly, share_workouts, share_heat, compete_globally';
  static const _communityColumns = 'id, name, description, is_public, invite_code, owner';

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
    bool? competeGlobally,
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
            'compete_globally': ?competeGlobally,
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

  /// Topluluk fonksiyonunun `raise exception '<kod>'` hatasını [CommunityException]'a çevirir.
  Future<T> _community<T>(Future<T> Function() call) async {
    try {
      return await call();
    } on PostgrestException catch (e) {
      if (communityErrorCodes.contains(e.message)) throw CommunityException(e.message);
      rethrow;
    }
  }

  @override
  Future<List<String>> fetchMyCommunityIds() async {
    final rows = await _client.from('community_members').select('community_id').eq('user_id', _me);
    return [for (final row in rows) row['community_id'] as String];
  }

  @override
  Future<List<Community>> fetchCommunities(List<String> ids) async {
    if (ids.isEmpty) return const [];
    final rows = await _client.from('communities').select(_communityColumns).inFilter('id', ids);
    return [for (final row in rows) Community.fromJson(row)];
  }

  @override
  Future<Map<String, List<CommunityMember>>> fetchMembers(List<String> communityIds) async {
    if (communityIds.isEmpty) return const {};
    final rows = await _client
        .from('community_members')
        .select('community_id, user_id, role, joined_at')
        .inFilter('community_id', communityIds)
        .order('joined_at');
    final result = <String, List<CommunityMember>>{};
    for (final row in rows) {
      final member = CommunityMember.fromJson(row);
      (result[member.communityId] ??= []).add(member);
    }
    return result;
  }

  @override
  Future<List<CommunitySearchResult>> searchCommunities(String query) async {
    final rows = await _client.rpc('search_communities', params: {'p_query': query}) as List? ?? const [];
    return [for (final row in rows) CommunitySearchResult.fromJson(row as Map<String, dynamic>)];
  }

  @override
  Future<String> createCommunity({required String name, required String description, required bool isPublic}) =>
      _community(() async => await _client.rpc('create_community', params: {
            'p_name': name,
            'p_description': description,
            'p_is_public': isPublic,
          }) as String);

  @override
  Future<void> joinCommunity(String id) => _community(() async {
        await _client.rpc('join_community', params: {'p_id': id});
      });

  @override
  Future<String> joinCommunityByCode(String code) =>
      _community(() async => await _client.rpc('join_community_by_code', params: {'p_code': code}) as String);

  @override
  Future<void> leaveCommunity(String id) => _community(() async {
        await _client.rpc('leave_community', params: {'p_id': id});
      });

  @override
  Future<void> updateCommunity(String id, {String? name, String? description, bool? isPublic}) async {
    await _client.from('communities').update({
      'name': ?name?.trim(),
      'description': ?description?.trim(),
      'is_public': ?isPublic,
    }).eq('id', id);
  }

  @override
  Future<void> removeMember(String communityId, String userId, {required bool ban}) => _community(() async {
        await _client.rpc('remove_member', params: {'p_id': communityId, 'p_user': userId, 'p_ban': ban});
      });

  @override
  Future<String> regenerateCommunityCode(String id) =>
      _community(() async => await _client.rpc('regenerate_community_code', params: {'p_id': id}) as String);

  @override
  Future<Map<String, PeriodStats>> fetchPeriodStats(List<String> userIds) async {
    if (userIds.isEmpty) return const {};
    final rows = await _client.from('period_stats').select().inFilter('user_id', userIds);
    return {for (final row in rows) row['user_id'] as String: PeriodStats.fromJson(row)};
  }

  @override
  Future<void> upsertMyPeriodStats(PeriodStats stats) async {
    await _client.from('period_stats').upsert({
      ...stats.toJson(),
      'user_id': _me,
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    });
  }

  @override
  Future<List<GlobalTitle>> globalTitles(PeriodKind kind, String key) async {
    final rows = await _client.rpc('global_titles', params: {'p_kind': kind.name, 'p_key': key}) as List? ?? const [];
    return [for (final row in rows) GlobalTitle.fromJson(row as Map<String, dynamic>)];
  }

  @override
  Future<List<GlobalRow>> globalLeaderboard(PeriodKind kind, String key) async {
    final rows =
        await _client.rpc('global_leaderboard', params: {'p_kind': kind.name, 'p_key': key}) as List? ?? const [];
    return [for (final row in rows) GlobalRow.fromJson(row as Map<String, dynamic>)];
  }
}
