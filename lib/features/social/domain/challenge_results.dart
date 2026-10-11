import '../../gamification/domain/xp_rules.dart';
import 'challenge.dart';

class ChallengeStanding {
  const ChallengeStanding({
    required this.userId,
    required this.position,
    required this.value,
    required this.reachedGoal,
  });

  final String userId;

  /// Eşit değerde aynı sıra.
  final int position;
  final double value;

  /// Yalnız hedefte: değer ≥ hedef.
  final bool reachedGoal;
}

/// Katılanlar (joined) değere göre azalan; eşitlikte [names] (yoksa kimlik) sırası.
List<ChallengeStanding> challengeStandings(
  Challenge challenge,
  List<ChallengeParticipant> participants, {
  Map<String, String> names = const {},
}) {
  final joined = [
    for (final p in participants)
      if (p.status == ChallengeStatus.joined) p,
  ]..sort((a, b) {
      final byValue = b.progress.compareTo(a.progress);
      return byValue != 0 ? byValue : (names[a.userId] ?? a.userId).compareTo(names[b.userId] ?? b.userId);
    });
  final rows = <ChallengeStanding>[];
  for (var i = 0; i < joined.length; i++) {
    final p = joined[i];
    rows.add(ChallengeStanding(
      userId: p.userId,
      position: i > 0 && joined[i - 1].progress == p.progress ? rows[i - 1].position : i + 1,
      value: p.progress,
      reachedGoal: challenge.kind == ChallengeKind.goal && p.progress >= (challenge.target ?? double.infinity),
    ));
  }
  return rows;
}

/// Kesinleşmişse ödül alanlar (S3 spec §3.3): yarışta en yüksek (> 0) değer(ler),
/// en az iki katılımcıyla; hedefte ulaşan herkes.
Set<String> challengeWinners(Challenge challenge, List<ChallengeParticipant> participants, DateTime now) {
  if (challenge.state(now) != ChallengeState.finished) return const {};
  final rows = challengeStandings(challenge, participants);
  if (challenge.kind == ChallengeKind.goal) {
    return {
      for (final r in rows)
        if (r.reachedGoal) r.userId,
    };
  }
  if (rows.length < 2 || rows.first.value <= 0) return const {};
  return {
    for (final r in rows)
      if (r.position == 1) r.userId,
  };
}

int challengeRewardXp(ChallengeKind kind) => kind == ChallengeKind.race ? xpPerRaceWin : xpPerGoal;

/// Kazandığım meydan okumaların XP olayları; tarih kesinleşme anı, eskiden yeniye.
List<XpEvent> challengeRewards(
  String myId,
  List<(Challenge, List<ChallengeParticipant>)> challenges,
  DateTime now,
) =>
    [
      for (final (challenge, participants) in challenges)
        if (challengeWinners(challenge, participants, now).contains(myId))
          XpEvent(
            source: XpSource.challenge,
            date: challenge.finalAt,
            xp: challengeRewardXp(challenge.kind),
            label: challenge.name,
          ),
    ]..sort(compareXpEvents);
