import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../gamification/domain/xp_rules.dart';
import '../../progress/application/progress_providers.dart';
import '../../workout/application/muscle_heat_providers.dart';
import '../../workout/application/session_providers.dart';
import '../data/social_repository.dart';
import '../domain/challenge.dart';
import '../domain/challenge_progress.dart';
import '../domain/challenge_results.dart';
import '../domain/community.dart';
import '../domain/public_profile.dart';
import 'social_providers.dart';

/// Kendi geçmişimden meydan okuma değeri (S3 spec §3.2); XP olayları bir kez hesaplanır.
final myChallengeValueProvider = FutureProvider.autoDispose<double Function(Challenge)>((ref) async {
  final (sessions, mealTimes, exercisesById) = await (
    ref.watch(allSessionsProvider.future),
    ref.watch(mealTimesProvider.future),
    ref.watch(exercisesByIdProvider.future),
  ).wait;
  final events = xpEvents(sessions, mealTimes);
  return (challenge) => challengeValue(challenge, sessions, events, exercisesById);
});

/// Aktif ya da kesinleşme payındayken katıldığım satıra yerel (canlı) değeri koyar.
List<ChallengeParticipant> _withMyLiveValue(
  Challenge challenge,
  List<ChallengeParticipant> participants,
  String myId,
  DateTime now,
  double Function(Challenge) valueOf,
) {
  final state = challenge.state(now);
  if (state != ChallengeState.active && state != ChallengeState.finalizing) return participants;
  return [
    for (final p in participants)
      p.userId == myId && p.status == ChallengeStatus.joined ? p.copyWith(progress: valueOf(challenge)) : p,
  ];
}

class ChallengeEntry {
  const ChallengeEntry({required this.challenge, required this.participants, required this.myId});

  final Challenge challenge;
  final List<ChallengeParticipant> participants;
  final String myId;

  ChallengeParticipant? get mine => participants.where((p) => p.userId == myId).firstOrNull;
}

class MyChallenges {
  const MyChallenges({
    this.invites = const [],
    this.active = const [],
    this.upcoming = const [],
    this.finished = const [],
    this.profiles = const {},
  });

  /// Bitmemiş davetlerim.
  final List<ChallengeEntry> invites;

  /// Katıldığım, sürmekte ya da kesinleşmekte olanlar; kendi değerim canlı.
  final List<ChallengeEntry> active;
  final List<ChallengeEntry> upcoming;

  /// Son 10, yeniden eskiye.
  final List<ChallengeEntry> finished;

  /// Katılımcı profilleri (ben dahil).
  final Map<String, PublicProfile> profiles;
}

final myChallengesProvider = FutureProvider.autoDispose<MyChallenges>((ref) async {
  final me = await ref.watch(myPublicProfileProvider.future);
  if (me == null) return const MyChallenges();
  final repo = ref.watch(socialRepositoryProvider);
  final ids = await repo.fetchMyChallengeIds();
  final (challenges, participants) = await (repo.fetchChallenges(ids), repo.fetchParticipants(ids)).wait;
  final (profiles, valueOf) = await (
    repo.fetchProfiles([
      ...{
        for (final list in participants.values)
          for (final p in list) p.userId,
      },
    ]),
    ref.watch(myChallengeValueProvider.future),
  ).wait;
  final now = ref.read(nowProvider)();
  final invites = <ChallengeEntry>[], active = <ChallengeEntry>[], upcoming = <ChallengeEntry>[];
  final finished = <ChallengeEntry>[];
  for (final challenge in challenges) {
    final entry = ChallengeEntry(
      challenge: challenge,
      participants: _withMyLiveValue(challenge, participants[challenge.id] ?? const [], me.userId, now, valueOf),
      myId: me.userId,
    );
    final state = challenge.state(now);
    switch (entry.mine?.status) {
      case ChallengeStatus.invited when state == ChallengeState.upcoming || state == ChallengeState.active:
        invites.add(entry);
      case ChallengeStatus.joined:
        switch (state) {
          case ChallengeState.upcoming:
            upcoming.add(entry);
          case ChallengeState.active || ChallengeState.finalizing:
            active.add(entry);
          case ChallengeState.finished:
            finished.add(entry);
        }
      default:
        break;
    }
  }
  int byEnd(ChallengeEntry a, ChallengeEntry b) => a.challenge.endsAt.compareTo(b.challenge.endsAt);
  invites.sort(byEnd);
  active.sort(byEnd);
  upcoming.sort((a, b) => a.challenge.startsAt.compareTo(b.challenge.startsAt));
  finished.sort((a, b) => byEnd(b, a));
  return MyChallenges(
    invites: invites,
    active: active,
    upcoming: upcoming,
    finished: finished.take(10).toList(),
    profiles: {for (final p in profiles) p.userId: p, me.userId: me},
  );
});

/// Sekme ve alt menü rozeti; veri yoksa 0.
final pendingChallengeInvitesProvider = Provider<int>((ref) {
  return ref.watch(myChallengesProvider).value?.invites.length ?? 0;
});

/// Topluluğun bitmemiş meydan okumaları; değerler sunucudaki yayından.
final communityChallengesProvider =
    FutureProvider.autoDispose.family<List<ChallengeEntry>, String>((ref, communityId) async {
  final me = await ref.watch(myPublicProfileProvider.future);
  if (me == null) return const [];
  final repo = ref.watch(socialRepositoryProvider);
  final ids = await repo.fetchCommunityChallengeIds(communityId);
  final (challenges, participants) = await (repo.fetchChallenges(ids), repo.fetchParticipants(ids)).wait;
  final now = ref.read(nowProvider)();
  return [
    for (final challenge in challenges)
      if (challenge.state(now) != ChallengeState.finished)
        ChallengeEntry(challenge: challenge, participants: participants[challenge.id] ?? const [], myId: me.userId),
  ]..sort((a, b) => a.challenge.endsAt.compareTo(b.challenge.endsAt));
});

class ChallengeDetail {
  const ChallengeDetail({
    required this.challenge,
    required this.participants,
    required this.profiles,
    required this.myId,
    this.community,
  });

  final Challenge challenge;

  /// Kendi değerim aktifken canlı.
  final List<ChallengeParticipant> participants;

  /// Kendi profilim dahil.
  final Map<String, PublicProfile> profiles;
  final String myId;

  /// Topluluk meydan okumasında, görünüyorsa.
  final Community? community;

  ChallengeParticipant? get mine => participants.where((p) => p.userId == myId).firstOrNull;

  /// Topluluk sahibi her zaman; açan, kendisinden başka katılımcı yokken.
  bool get canDelete =>
      community?.owner == myId ||
      (challenge.creator == myId &&
          !participants.any((p) => p.userId != myId && p.status == ChallengeStatus.joined));
}

/// Görmüyorsam (ya da silindiyse) null.
final challengeDetailProvider = FutureProvider.autoDispose.family<ChallengeDetail?, String>((ref, id) async {
  final me = await ref.watch(myPublicProfileProvider.future);
  if (me == null) return null;
  final repo = ref.watch(socialRepositoryProvider);
  final (challenges, participants) = await (repo.fetchChallenges([id]), repo.fetchParticipants([id])).wait;
  final challenge = challenges.firstOrNull;
  if (challenge == null) return null;
  final list = participants[id] ?? const <ChallengeParticipant>[];
  final (profiles, communities, valueOf) = await (
    repo.fetchProfiles([for (final p in list) p.userId]),
    repo.fetchCommunities([?challenge.communityId]),
    ref.watch(myChallengeValueProvider.future),
  ).wait;
  final now = ref.read(nowProvider)();
  return ChallengeDetail(
    challenge: challenge,
    participants: _withMyLiveValue(challenge, list, me.userId, now, valueOf),
    profiles: {for (final p in profiles) p.userId: p, me.userId: me},
    myId: me.userId,
    community: communities.firstOrNull,
  );
});

/// Kesinleşmiş ve kazandığım meydan okumaların XP olayları (S3 spec §3.3). Kimlik yoksa
/// ya da okunamazsa boş: seviye meydan okumasız da hesaplanır.
final challengeRewardsProvider = FutureProvider.autoDispose<List<XpEvent>>((ref) async {
  try {
    final me = await ref.watch(myPublicProfileProvider.future);
    if (me == null) return const [];
    final repo = ref.watch(socialRepositoryProvider);
    final ids = await repo.fetchMyChallengeIds();
    final (challenges, participants) = await (repo.fetchChallenges(ids), repo.fetchParticipants(ids)).wait;
    return challengeRewards(
      me.userId,
      [for (final c in challenges) (c, participants[c.id] ?? const <ChallengeParticipant>[])],
      ref.read(nowProvider)(),
    );
  } catch (e, st) {
    debugPrint('challengeRewards failed: $e\n$st');
    return const [];
  }
});

/// Son yayınlanan değerler (bellekte); aynıysa yeniden yazılmaz.
class LastPublishedChallengeValues extends Notifier<Map<String, double>> {
  @override
  Map<String, double> build() => const {};

  void remember(String id, double value) => state = {...state, id: value};
}

final lastPublishedChallengeValuesProvider =
    NotifierProvider<LastPublishedChallengeValues, Map<String, double>>(LastPublishedChallengeValues.new);

/// Aktif ya da kesinleşme payındaki katılımlarımın değerini yayınlar; yalnız değişeni
/// yazar. `AppShell` izler; hata loglanır.
final challengeSyncProvider = FutureProvider.autoDispose<void>((ref) async {
  final mine = await ref.watch(myChallengesProvider.future);
  final repo = ref.read(socialRepositoryProvider);
  for (final entry in mine.active) {
    final value = entry.mine?.progress;
    if (value == null || ref.read(lastPublishedChallengeValuesProvider)[entry.challenge.id] == value) continue;
    try {
      await repo.publishChallengeProgress(entry.challenge.id, value);
      ref.read(lastPublishedChallengeValuesProvider.notifier).remember(entry.challenge.id, value);
    } catch (e, st) {
      debugPrint('challengeSync failed: $e\n$st');
    }
  }
});

/// Meydan okuma yazma işlemleri; her biri ilgili sağlayıcıları yeniler.
class ChallengeActions {
  ChallengeActions(this._ref);

  final Ref _ref;

  SocialRepository get _repo => _ref.read(socialRepositoryProvider);

  void _refresh(String id, String? communityId) {
    _ref.invalidate(myChallengesProvider);
    _ref.invalidate(challengeDetailProvider(id));
    if (communityId != null) _ref.invalidate(communityChallengesProvider(communityId));
  }

  Future<String> create(ChallengeDraft draft) async {
    final id = await _repo.createChallenge(draft);
    _refresh(id, draft.communityId);
    return id;
  }

  Future<void> respond(Challenge challenge, {required bool accept}) async {
    await _repo.respondChallenge(challenge.id, accept: accept);
    _refresh(challenge.id, challenge.communityId);
  }

  Future<void> join(Challenge challenge) async {
    await _repo.joinChallenge(challenge.id);
    _refresh(challenge.id, challenge.communityId);
  }

  Future<void> leave(Challenge challenge) async {
    await _repo.leaveChallenge(challenge.id);
    _refresh(challenge.id, challenge.communityId);
  }

  Future<void> delete(Challenge challenge) async {
    await _repo.deleteChallenge(challenge.id);
    _refresh(challenge.id, challenge.communityId);
  }
}

final challengeActionsProvider = Provider<ChallengeActions>(ChallengeActions.new);
