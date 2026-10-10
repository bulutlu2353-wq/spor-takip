import 'package:spor_takip/features/social/data/social_repository.dart';
import 'package:spor_takip/features/social/domain/community.dart';
import 'package:spor_takip/features/social/domain/friendship.dart';
import 'package:spor_takip/features/social/domain/period_keys.dart';
import 'package:spor_takip/features/social/domain/period_stats.dart';
import 'package:spor_takip/features/social/domain/player_stats.dart';
import 'package:spor_takip/features/social/domain/public_profile.dart';

class FakeSocialRepository implements SocialRepository {
  FakeSocialRepository({
    this.me,
    List<PublicProfile> others = const [],
    List<Friendship> friendships = const [],
    Map<String, PlayerStats> stats = const {},
    Set<String> taken = const {},
    List<Community> communities = const [],
    Map<String, List<CommunityMember>> members = const {},
    Map<String, PeriodStats> periodStats = const {},
  })  : others = {for (final p in others) p.userId: p},
        friendships = [...friendships],
        stats = {...stats},
        taken = {...taken},
        communities = {for (final c in communities) c.id: c},
        members = {for (final MapEntry(key: id, value: list) in members.entries) id: [...list]},
        periodStats = {...periodStats};

  PublicProfile? me;
  final Map<String, PublicProfile> others;
  final List<Friendship> friendships;
  final Map<String, PlayerStats> stats;
  final Set<String> taken;
  final Map<String, Community> communities;
  final Map<String, List<CommunityMember>> members;
  final Map<String, PeriodStats> periodStats;
  final List<PlayerStats> upserts = [];
  final List<PeriodStats> periodUpserts = [];
  final List<String> sent = [];
  final List<(String, bool)> responses = [];
  final List<String> removed = [];
  final List<String> joined = [];
  final List<String> left = [];
  final List<(String, String, bool)> memberRemovals = [];
  final List<(PeriodKind, String)> globalQueries = [];
  List<CommunitySearchResult> searchResults = [];
  List<GlobalTitle> globalTitlesResult = [];
  List<GlobalRow> globalRowsResult = [];
  String sendResult = 'pending';
  Object? error;

  /// Kurma ve katılma bunu fırlatır.
  CommunityException? communityError;

  String get _myId => me?.userId ?? 'me';

  void _maybeThrow() {
    if (error case final e?) throw e;
  }

  void _throwCommunityError() {
    if (communityError case final e?) throw e;
  }

  void _addMe(String communityId, {bool owner = false}) {
    final list = members[communityId] ??= [];
    if (list.any((m) => m.userId == _myId)) return;
    list.add(CommunityMember(communityId: communityId, userId: _myId, isOwner: owner, joinedAt: DateTime(2026, 10, 9)));
  }

  @override
  Future<PublicProfile?> fetchMyProfile() async {
    _maybeThrow();
    return me;
  }

  @override
  Future<PublicProfile> createProfile({required String username, required String displayName}) async {
    if (taken.contains(username)) throw UsernameTakenException();
    return me = PublicProfile(userId: 'me', username: username, displayName: displayName, inviteCode: 'K7Q2M9XA');
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
    if (username != null && taken.contains(username)) throw UsernameTakenException();
    return me = me!.copyWith(
      username: username,
      displayName: displayName,
      shareWeekly: shareWeekly,
      shareWorkouts: shareWorkouts,
      shareHeat: shareHeat,
      competeGlobally: competeGlobally,
    );
  }

  @override
  Future<bool> usernameAvailable(String username) async => !taken.contains(username);

  @override
  Future<FoundUser?> findByUsername(String username) async {
    for (final p in others.values) {
      if (p.username == username) {
        return FoundUser(userId: p.userId, username: p.username, displayName: p.displayName);
      }
    }
    return null;
  }

  @override
  Future<FoundUser?> findByInviteCode(String code) async {
    for (final p in others.values) {
      if (p.inviteCode == code.trim().toUpperCase()) {
        return FoundUser(userId: p.userId, username: p.username, displayName: p.displayName);
      }
    }
    return null;
  }

  @override
  Future<List<Friendship>> fetchFriendships() async {
    _maybeThrow();
    return [...friendships];
  }

  @override
  Future<String> sendRequest(String targetId) async {
    sent.add(targetId);
    return sendResult;
  }

  @override
  Future<void> respond(String requesterId, {required bool accept}) async {
    responses.add((requesterId, accept));
    final index = friendships.indexWhere((f) => f.requester == requesterId && !f.accepted);
    if (index < 0) return;
    if (accept) {
      final f = friendships[index];
      friendships[index] =
          Friendship(requester: f.requester, addressee: f.addressee, accepted: true, createdAt: f.createdAt);
    } else {
      friendships.removeAt(index);
    }
  }

  @override
  Future<void> removeFriend(String otherId) async {
    removed.add(otherId);
    friendships.removeWhere((f) => f.requester == otherId || f.addressee == otherId);
  }

  @override
  Future<List<PublicProfile>> fetchProfiles(List<String> userIds) async => [
        for (final id in userIds)
          ?others[id],
      ];

  @override
  Future<Map<String, PlayerStats>> fetchStats(List<String> userIds) async => {
        for (final id in userIds)
          id: ?stats[id],
      };

  @override
  Future<void> upsertMyStats(PlayerStats stats) async => upserts.add(stats);

  @override
  Future<List<String>> fetchMyCommunityIds() async {
    _maybeThrow();
    return [
      for (final MapEntry(key: id, value: list) in members.entries)
        if (list.any((m) => m.userId == _myId)) id,
    ];
  }

  @override
  Future<List<Community>> fetchCommunities(List<String> ids) async => [
        for (final id in ids)
          ?communities[id],
      ];

  @override
  Future<Map<String, List<CommunityMember>>> fetchMembers(List<String> communityIds) async => {
        for (final id in communityIds)
          if (members[id] case final list?) id: [...list],
      };

  @override
  Future<List<CommunitySearchResult>> searchCommunities(String query) async => [...searchResults];

  @override
  Future<String> createCommunity({required String name, required String description, required bool isPublic}) async {
    _throwCommunityError();
    communities['new'] = Community(
      id: 'new',
      name: name,
      description: description,
      isPublic: isPublic,
      inviteCode: 'NEWCMTY2',
      owner: _myId,
    );
    _addMe('new', owner: true);
    return 'new';
  }

  @override
  Future<void> joinCommunity(String id) async {
    _throwCommunityError();
    joined.add(id);
    _addMe(id);
  }

  @override
  Future<String> joinCommunityByCode(String code) async {
    _throwCommunityError();
    final community = communities.values.where((c) => c.inviteCode == code.trim().toUpperCase()).firstOrNull;
    if (community == null) throw const CommunityException('unknown_code');
    joined.add(community.id);
    _addMe(community.id);
    return community.id;
  }

  @override
  Future<void> leaveCommunity(String id) async {
    left.add(id);
    members[id]?.removeWhere((m) => m.userId == _myId);
  }

  @override
  Future<void> updateCommunity(String id, {String? name, String? description, bool? isPublic}) async {
    communities[id] = communities[id]!.copyWith(name: name, description: description, isPublic: isPublic);
  }

  @override
  Future<void> removeMember(String communityId, String userId, {required bool ban}) async {
    memberRemovals.add((communityId, userId, ban));
    members[communityId]?.removeWhere((m) => m.userId == userId);
  }

  @override
  Future<String> regenerateCommunityCode(String id) async {
    communities[id] = communities[id]!.copyWith(inviteCode: 'R3GENKQ2');
    return 'R3GENKQ2';
  }

  @override
  Future<Map<String, PeriodStats>> fetchPeriodStats(List<String> userIds) async => {
        for (final id in userIds)
          id: ?periodStats[id],
      };

  @override
  Future<void> upsertMyPeriodStats(PeriodStats stats) async => periodUpserts.add(stats);

  @override
  Future<List<GlobalTitle>> globalTitles(PeriodKind kind, String key) async {
    globalQueries.add((kind, key));
    return [...globalTitlesResult];
  }

  @override
  Future<List<GlobalRow>> globalLeaderboard(PeriodKind kind, String key) async {
    globalQueries.add((kind, key));
    return [...globalRowsResult];
  }
}
