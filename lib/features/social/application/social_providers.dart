import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/supabase_client.dart';
import '../../gamification/application/gamification_providers.dart';
import '../../onboarding/application/auth_providers.dart';
import '../../progress/application/progress_providers.dart';
import '../../workout/application/muscle_heat_providers.dart';
import '../../workout/application/session_providers.dart';
import '../data/social_repository.dart';
import '../domain/friendship.dart';
import '../domain/period_stats.dart';
import '../domain/player_stats.dart';
import '../domain/public_profile.dart';

final socialRepositoryProvider = Provider<SocialRepository>((ref) {
  return SupabaseSocialRepository(AppSupabase.client);
});

/// Kendi sosyal kimliğim; yoksa null (Sosyal sekmesi oluşturmayı ister).
final myPublicProfileProvider = FutureProvider<PublicProfile?>((ref) async {
  if (!ref.watch(isLoggedInProvider)) return null;
  return ref.watch(socialRepositoryProvider).fetchMyProfile();
});

final friendshipsProvider = FutureProvider.autoDispose<List<Friendship>>((ref) async {
  final me = await ref.watch(myPublicProfileProvider.future);
  if (me == null) return const [];
  return ref.watch(socialRepositoryProvider).fetchFriendships();
});

class FriendEntry {
  const FriendEntry({required this.profile, this.stats});

  final PublicProfile profile;

  /// Arkadaş henüz yayın yapmadıysa null.
  final PlayerStats? stats;
}

class RequestEntry {
  const RequestEntry({required this.profile, required this.state});

  final PublicProfile profile;
  final FriendshipState state;
}

class SocialOverview {
  const SocialOverview({this.friends = const [], this.incoming = const [], this.outgoing = const []});

  /// Seviye büyükten küçüğe, sonra görünen ad.
  final List<FriendEntry> friends;
  final List<RequestEntry> incoming;
  final List<RequestEntry> outgoing;
}

final socialOverviewProvider = FutureProvider.autoDispose<SocialOverview>((ref) async {
  final me = await ref.watch(myPublicProfileProvider.future);
  if (me == null) return const SocialOverview();
  final friendships = await ref.watch(friendshipsProvider.future);
  final repo = ref.watch(socialRepositoryProvider);
  final friendIds = [
    for (final f in friendships)
      if (f.accepted) f.otherThan(me.userId),
  ];
  final (profiles, stats) = await (
    repo.fetchProfiles([for (final f in friendships) f.otherThan(me.userId)]),
    repo.fetchStats(friendIds),
  ).wait;
  final byId = {for (final p in profiles) p.userId: p};
  final friends = [
    for (final id in friendIds)
      if (byId[id] case final profile?) FriendEntry(profile: profile, stats: stats[id]),
  ]..sort((a, b) {
      final byLevel = (b.stats?.level ?? 0).compareTo(a.stats?.level ?? 0);
      return byLevel != 0 ? byLevel : a.profile.displayName.compareTo(b.profile.displayName);
    });
  List<RequestEntry> requests(FriendshipState state) => [
        for (final f in friendships)
          if (f.stateFor(me.userId) == state)
            if (byId[f.otherThan(me.userId)] case final profile?) RequestEntry(profile: profile, state: state),
      ];
  return SocialOverview(
    friends: friends,
    incoming: requests(FriendshipState.incoming),
    outgoing: requests(FriendshipState.outgoing),
  );
});

/// Sekme rozeti; veri yoksa 0.
final incomingRequestCountProvider = Provider<int>((ref) {
  final me = ref.watch(myPublicProfileProvider).value;
  final friendships = ref.watch(friendshipsProvider).value;
  if (me == null || friendships == null) return 0;
  return friendships.where((f) => f.stateFor(me.userId) == FriendshipState.incoming).length;
});

/// Arkadaş değilse null.
final friendProfileProvider = FutureProvider.autoDispose.family<FriendEntry?, String>((ref, id) async {
  final overview = await ref.watch(socialOverviewProvider.future);
  return overview.friends.where((f) => f.profile.userId == id).firstOrNull;
});

/// Son yayınlanan satır (bellekte); aynıysa yeniden yazılmaz.
class LastPublishedStats extends Notifier<PlayerStats?> {
  @override
  PlayerStats? build() => null;

  void remember(PlayerStats stats) => state = stats;
}

final lastPublishedStatsProvider = NotifierProvider<LastPublishedStats, PlayerStats?>(LastPublishedStats.new);

/// Son yayınlanan dönem özeti (bellekte); aynıysa yeniden yazılmaz.
class LastPublishedPeriodStats extends Notifier<PeriodStats?> {
  @override
  PeriodStats? build() => null;

  void remember(PeriodStats stats) => state = stats;
}

final lastPublishedPeriodStatsProvider =
    NotifierProvider<LastPublishedPeriodStats, PeriodStats?>(LastPublishedPeriodStats.new);

/// Kendi `player_stats` (S1 spec §5) ve `period_stats` (S2 spec §5) satırlarımı
/// yayınlar; her biri yalnız değişince yazılır. `AppShell` izler; hata loglanır.
final statsSyncProvider = FutureProvider.autoDispose<void>((ref) async {
  final profile = await ref.watch(myPublicProfileProvider.future);
  if (profile == null) return;
  final (summary, sessions, mealTimes, exercisesById, activeTitleId) = await (
    ref.watch(playerSummaryProvider.future),
    ref.watch(allSessionsProvider.future),
    ref.watch(mealTimesProvider.future),
    ref.watch(exercisesByIdProvider.future),
    ref.watch(activeTitleProvider.future),
  ).wait;
  final now = ref.read(nowProvider)();
  final repo = ref.read(socialRepositoryProvider);
  final stats = buildPlayerStats(
    summary: summary,
    sessions: sessions,
    mealTimes: mealTimes,
    exercisesById: exercisesById,
    now: now,
    activeTitleId: activeTitleId,
    privacy: SharedPrivacy(weekly: profile.shareWeekly, workouts: profile.shareWorkouts, heat: profile.shareHeat),
  );
  if (ref.read(lastPublishedStatsProvider) != stats) {
    try {
      await repo.upsertMyStats(stats);
      ref.read(lastPublishedStatsProvider.notifier).remember(stats);
    } catch (e, st) {
      debugPrint('statsSync failed: $e\n$st');
    }
  }
  final period = buildPeriodStats(
    summary: summary,
    sessions: sessions,
    mealTimes: mealTimes,
    exercisesById: exercisesById,
    now: now,
    activeTitleId: activeTitleId,
  );
  if (ref.read(lastPublishedPeriodStatsProvider) != period) {
    try {
      await repo.upsertMyPeriodStats(period);
      ref.read(lastPublishedPeriodStatsProvider.notifier).remember(period);
    } catch (e, st) {
      debugPrint('periodStatsSync failed: $e\n$st');
    }
  }
});

/// Ekranların yazma işlemleri; her biri ilgili sağlayıcıları yeniler.
class SocialActions {
  SocialActions(this._ref);

  final Ref _ref;

  SocialRepository get _repo => _ref.read(socialRepositoryProvider);

  Future<PublicProfile> createProfile({required String username, required String displayName}) async {
    final profile = await _repo.createProfile(username: username, displayName: displayName);
    _ref.invalidate(myPublicProfileProvider);
    return profile;
  }

  Future<PublicProfile> updateProfile({
    String? username,
    String? displayName,
    bool? shareWeekly,
    bool? shareWorkouts,
    bool? shareHeat,
    bool? competeGlobally,
  }) async {
    final profile = await _repo.updateProfile(
      username: username,
      displayName: displayName,
      shareWeekly: shareWeekly,
      shareWorkouts: shareWorkouts,
      shareHeat: shareHeat,
      competeGlobally: competeGlobally,
    );
    _ref.invalidate(myPublicProfileProvider);
    return profile;
  }

  Future<String> send(String targetId) async {
    final result = await _repo.sendRequest(targetId);
    _ref.invalidate(friendshipsProvider);
    return result;
  }

  Future<void> respond(String requesterId, {required bool accept}) async {
    await _repo.respond(requesterId, accept: accept);
    _ref.invalidate(friendshipsProvider);
  }

  Future<void> remove(String otherId) async {
    await _repo.removeFriend(otherId);
    _ref.invalidate(friendshipsProvider);
  }
}

final socialActionsProvider = Provider<SocialActions>(SocialActions.new);
