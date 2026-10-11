import 'dart:math' as math;

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../../../workout/domain/exercise_taxonomy.dart';
import '../../../workout/domain/muscle_heat.dart';
import '../../domain/challenge.dart';
import '../../domain/challenge_results.dart';

String challengeMetricLabel(ChallengeMetric metric) => 'challenge.metric.${metric.name}'.tr();

String challengeMuscleLabel(String muscle) => 'gamification.muscle_short.${taxonomySlug(muscle)}'.tr();

/// Set bir ondalık ("18.5"), diğerleri tamsayı.
String challengeNumber(ChallengeMetric metric, double value) =>
    metric == ChallengeMetric.sets ? formatSets(value) : '${value.round()}';

/// "18.5 set", "2700 kg", "85 XP", "3 antrenman".
String challengeValueLabel(ChallengeMetric metric, double value) =>
    'challenge.value.${metric.name}'.tr(namedArgs: {'n': challengeNumber(metric, value)});

/// Ad boşsa (S3 spec §3.4); en çok 60 karakter.
String challengeAutoName({
  required ChallengeKind kind,
  required ChallengeMetric metric,
  String? muscle,
  double? target,
  required int days,
}) {
  final base = kind == ChallengeKind.race
      ? 'challenge.auto_race'.tr(namedArgs: {'days': '$days', 'metric': 'challenge.metric_noun.${metric.name}'.tr()})
      : 'challenge.auto_goal'.tr(namedArgs: {'days': '$days', 'value': challengeValueLabel(metric, target ?? 0)});
  final name =
      muscle == null ? base : 'challenge.auto_muscle'.tr(namedArgs: {'name': base, 'muscle': challengeMuscleLabel(muscle)});
  return name.length > 60 ? name.substring(0, 60) : name;
}

/// "10 Ekim", saatle "10 Ekim 00:00".
String challengeDateLabel(DateTime date, {bool withTime = false}) {
  final local = date.toLocal();
  final day = '${local.day} ${'home.month_${local.month}'.tr()}';
  if (!withTime) return day;
  return '$day ${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
}

/// Başlamadıysa başlangıç, sürüyorsa kalan süre, sonra "Kesinleşiyor" / "Bitti".
String challengeTimeLabel(Challenge challenge, DateTime now) => switch (challenge.state(now)) {
      ChallengeState.upcoming =>
        'challenge.starts_at'.tr(namedArgs: {'date': challengeDateLabel(challenge.startsAt, withTime: true)}),
      ChallengeState.active => _remaining(challenge.endsAt.difference(now)),
      ChallengeState.finalizing => 'challenge.finalizing'.tr(),
      ChallengeState.finished => 'challenge.ended'.tr(),
    };

String _remaining(Duration left) {
  final hours = math.max(1, (left.inMinutes / 60).ceil());
  return hours < 24
      ? 'social.period_remaining_hours'.tr(namedArgs: {'n': '$hours'})
      : 'social.period_remaining_days'.tr(namedArgs: {'n': '${(hours / 24).ceil()}'});
}

/// Biten meydan okumada benim sonucum.
String challengeResultLabel(
  Challenge challenge,
  List<ChallengeParticipant> participants,
  String myId,
  DateTime now,
) {
  final winners = challengeWinners(challenge, participants, now);
  final xp = '${challengeRewardXp(challenge.kind)}';
  if (winners.contains(myId)) {
    return (challenge.kind == ChallengeKind.race ? 'challenge.result_won' : 'challenge.result_goal')
        .tr(namedArgs: {'xp': xp});
  }
  if (challenge.kind == ChallengeKind.goal) return 'challenge.result_missed'.tr();
  if (winners.isEmpty) return 'challenge.result_none'.tr();
  final mine = challengeStandings(challenge, participants).where((r) => r.userId == myId).firstOrNull;
  return mine == null
      ? 'challenge.result_none'.tr()
      : 'challenge.result_position'.tr(namedArgs: {'n': '${mine.position}'});
}

/// İşlemi çalıştırır; hata kodunu ya da genel hatayı SnackBar'la bildirir. Başarıda true.
Future<bool> runChallengeAction(BuildContext context, Future<void> Function() action) async {
  final messenger = ScaffoldMessenger.of(context);
  try {
    await action();
    return true;
  } on ChallengeException catch (e) {
    messenger.showSnackBar(SnackBar(content: Text('challenge.error.${e.code}'.tr())));
  } catch (e, st) {
    debugPrint('challenge action failed: $e\n$st');
    messenger.showSnackBar(SnackBar(content: Text('social.action_error'.tr())));
  }
  return false;
}
