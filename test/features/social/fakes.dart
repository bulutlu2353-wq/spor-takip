import 'package:spor_takip/features/social/data/social_repository.dart';
import 'package:spor_takip/features/social/domain/challenge.dart';
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
    List<Challenge> challenges = const [],
    Map<String, List<ChallengeParticipant>> participants = const {},
  })  : others = {for (final p in others) p.userId: p},
        friendships = [...friendships],
        stats = {...stats},
        taken = {...taken},
        communities = {for (final c in communities) c.id: c},
        members = {for (final MapEntry(key: id, value: list) in members.entries) id: [...list]},
        periodStats = {...periodStats},
        challenges = {for (final c in challenges) c.id: c},
        participants = {for (final MapEntry(key: id, value: list) in participants.entries) id: [...list]};

  PublicProfile? me;
  final Map<String, PublicProfile> others;
  final List<Friendship> friendships;
  final Map<String, PlayerStats> stats;
  final Set<String> taken;
  final Map<String, Community> communities;
  final Map<String, List<CommunityMember>> members;
  final Map<String, PeriodStats> periodStats;
  final Map<String, Challenge> challenges;
  final Map<String, List<ChallengeParticipant>> participants;
  final List<ChallengeDraft> createdChallenges = [];
  final List<(String, bool)> challengeResponses = [];
  final List<String> joinedChallenges = [];
  final List<String> leftChallenges = [];
  final List<String> deletedChallenges = [];
  final List<(String, double)> publishedProgress = [];

  /// Meydan okuma yazma işlemleri bunu fırlatır.
  ChallengeException? challengeError;
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

  void _throwChallengeError() {
    if (challengeError case final e?) throw e;
  }

  void _setMyStatus(String id, ChallengeStatus status) {
    final list = participants[id] ??= [];
    list.removeWhere((p) => p.userId == _myId);
    list.add(ChallengeParticipant(challengeId: id, userId: _myId, status: status));
  }

  @override
  Future<List<String>> fetchMyChallengeIds() async {
    _maybeThrow();
    return [
      for (final MapEntry(key: id, value: list) in participants.entries)
        if (list.any((p) => p.userId == _myId && p.status != ChallengeStatus.declined)) id,
    ];
  }

  @override
  Future<List<String>> fetchCommunityChallengeIds(String communityId) async => [
        for (final c in challenges.values)
          if (c.communityId == communityId) c.id,
      ];

  @override
  Future<List<Challenge>> fetchChallenges(List<String> ids) async => [
        for (final id in ids)
          ?challenges[id],
      ];

  @override
  Future<Map<String, List<ChallengeParticipant>>> fetchParticipants(List<String> challengeIds) async => {
        for (final id in challengeIds)
          if (participants[id] case final list?) id: [...list],
      };

  @override
  Future<String> createChallenge(ChallengeDraft draft) async {
    _throwChallengeError();
    createdChallenges.add(draft);
    challenges['new'] = Challenge(
      id: 'new',
      creator: _myId,
      communityId: draft.communityId,
      name: draft.name,
      kind: draft.kind,
      metric: draft.metric,
      muscle: draft.muscle,
      target: draft.target,
      startsAt: draft.startsAt,
      endsAt: draft.endsAt,
    );
    participants['new'] = [
      ChallengeParticipant(challengeId: 'new', userId: _myId, status: ChallengeStatus.joined),
      for (final id in draft.invitees) ChallengeParticipant(challengeId: 'new', userId: id, status: ChallengeStatus.invited),
    ];
    return 'new';
  }

  @override
  Future<void> respondChallenge(String id, {required bool accept}) async {
    _throwChallengeError();
    challengeResponses.add((id, accept));
    _setMyStatus(id, accept ? ChallengeStatus.joined : ChallengeStatus.declined);
  }

  @override
  Future<void> joinChallenge(String id) async {
    _throwChallengeError();
    joinedChallenges.add(id);
    _setMyStatus(id, ChallengeStatus.joined);
  }

  @override
  Future<void> leaveChallenge(String id) async {
    _throwChallengeError();
    leftChallenges.add(id);
    participants[id]?.removeWhere((p) => p.userId == _myId);
  }

  @override
  Future<void> deleteChallenge(String id) async {
    _throwChallengeError();
    deletedChallenges.add(id);
    challenges.remove(id);
    participants.remove(id);
  }

  @override
  Future<void> publishChallengeProgress(String id, double value) async => publishedProgress.add((id, value));
}
