/// Yarış: süre sonunda en yüksek değer kazanır; hedef: ulaşan herkes başarır (S3 spec §2.2).
enum ChallengeKind { race, goal }

enum ChallengeMetric { workouts, sets, xp, volume }

enum ChallengeStatus { invited, joined, declined }

/// S3 spec §3.1.
enum ChallengeState { upcoming, active, finalizing, finished }

/// Meydan okuma fonksiyonunun hata kodu; ekran koda göre metin gösterir.
class ChallengeException implements Exception {
  const ChallengeException(this.code);

  final String code;

  @override
  String toString() => 'ChallengeException($code)';
}

/// Sunucunun `raise exception` ile döndürdüğü, metni olan kodlar.
const challengeErrorCodes = {
  'challenge_limit',
  'community_challenge_limit',
  'not_friend',
  'not_member',
  'challenge_closed',
  'invalid_challenge',
  'not_allowed',
  'no_profile',
};

const challengeDurations = [3, 7, 14, 30];
const maxChallengeInvitees = 9;
const maxActiveChallenges = 5;
const maxCommunityChallenges = 3;

/// Bitişten sonra geç senkron payı; sonra sonuç kesinleşir.
const challengeGrace = Duration(hours: 24);
const xpPerRaceWin = 100;
const xpPerGoal = 50;

class Challenge {
  const Challenge({
    required this.id,
    required this.creator,
    required this.name,
    required this.kind,
    required this.metric,
    required this.startsAt,
    required this.endsAt,
    this.communityId,
    this.muscle,
    this.target,
  });

  final String id;
  final String creator;

  /// null = arkadaş meydan okuması.
  final String? communityId;
  final String name;
  final ChallengeKind kind;
  final ChallengeMetric metric;

  /// Yalnız set ve hacimde; null = tümü.
  final String? muscle;

  /// Yalnız hedefte.
  final double? target;
  final DateTime startsAt;
  final DateTime endsAt;

  bool get isCommunity => communityId != null;

  /// Yaz saati günü ±1 saat yuvarlanır.
  int get days => (endsAt.difference(startsAt).inMinutes / Duration.minutesPerDay).round();

  /// Sonucun kesinleştiği an.
  DateTime get finalAt => endsAt.add(challengeGrace);

  ChallengeState state(DateTime now) {
    if (now.isBefore(startsAt)) return ChallengeState.upcoming;
    if (now.isBefore(endsAt)) return ChallengeState.active;
    if (now.isBefore(finalAt)) return ChallengeState.finalizing;
    return ChallengeState.finished;
  }

  factory Challenge.fromJson(Map<String, dynamic> json) => Challenge(
        id: json['id'] as String,
        creator: json['creator'] as String,
        communityId: json['community_id'] as String?,
        name: json['name'] as String,
        kind: ChallengeKind.values.byName(json['kind'] as String),
        metric: ChallengeMetric.values.byName(json['metric'] as String),
        muscle: json['muscle'] as String?,
        target: (json['target'] as num?)?.toDouble(),
        startsAt: DateTime.parse(json['starts_at'] as String).toLocal(),
        endsAt: DateTime.parse(json['ends_at'] as String).toLocal(),
      );
}

class ChallengeParticipant {
  const ChallengeParticipant({
    required this.challengeId,
    required this.userId,
    required this.status,
    this.progress = 0,
  });

  final String challengeId;
  final String userId;
  final ChallengeStatus status;
  final double progress;

  ChallengeParticipant copyWith({double? progress}) => ChallengeParticipant(
        challengeId: challengeId,
        userId: userId,
        status: status,
        progress: progress ?? this.progress,
      );

  factory ChallengeParticipant.fromJson(Map<String, dynamic> json) => ChallengeParticipant(
        challengeId: json['challenge_id'] as String,
        userId: json['user_id'] as String,
        status: ChallengeStatus.values.byName(json['status'] as String),
        progress: (json['progress'] as num?)?.toDouble() ?? 0,
      );
}

/// `create_challenge` parametreleri.
class ChallengeDraft {
  const ChallengeDraft({
    required this.name,
    required this.kind,
    required this.metric,
    required this.startsAt,
    required this.endsAt,
    this.muscle,
    this.target,
    this.communityId,
    this.invitees = const [],
  });

  final String name;
  final ChallengeKind kind;
  final ChallengeMetric metric;
  final String? muscle;
  final double? target;
  final DateTime startsAt;
  final DateTime endsAt;
  final String? communityId;
  final List<String> invitees;

  Map<String, dynamic> toParams() => {
        'p_name': name,
        'p_kind': kind.name,
        'p_metric': metric.name,
        'p_muscle': muscle,
        'p_target': target,
        'p_starts_at': startsAt.toUtc().toIso8601String(),
        'p_ends_at': endsAt.toUtc().toIso8601String(),
        'p_community_id': communityId,
        'p_invitees': invitees,
      };
}
