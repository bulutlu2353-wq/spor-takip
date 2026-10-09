import 'package:spor_takip/features/social/data/social_repository.dart';
import 'package:spor_takip/features/social/domain/friendship.dart';
import 'package:spor_takip/features/social/domain/player_stats.dart';
import 'package:spor_takip/features/social/domain/public_profile.dart';

class FakeSocialRepository implements SocialRepository {
  FakeSocialRepository({
    this.me,
    List<PublicProfile> others = const [],
    List<Friendship> friendships = const [],
    Map<String, PlayerStats> stats = const {},
    Set<String> taken = const {},
  })  : others = {for (final p in others) p.userId: p},
        friendships = [...friendships],
        stats = {...stats},
        taken = {...taken};

  PublicProfile? me;
  final Map<String, PublicProfile> others;
  final List<Friendship> friendships;
  final Map<String, PlayerStats> stats;
  final Set<String> taken;
  final List<PlayerStats> upserts = [];
  final List<String> sent = [];
  final List<(String, bool)> responses = [];
  final List<String> removed = [];
  String sendResult = 'pending';
  Object? error;

  void _maybeThrow() {
    if (error case final e?) throw e;
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
  }) async {
    if (username != null && taken.contains(username)) throw UsernameTakenException();
    return me = me!.copyWith(
      username: username,
      displayName: displayName,
      shareWeekly: shareWeekly,
      shareWorkouts: shareWorkouts,
      shareHeat: shareHeat,
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
}
