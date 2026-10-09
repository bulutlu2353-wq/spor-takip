import 'package:spor_takip/features/gamification/domain/levels.dart';
import 'package:spor_takip/features/gamification/domain/titles.dart';
import 'package:spor_takip/features/social/domain/friendship.dart';
import 'package:spor_takip/features/social/domain/player_stats.dart';
import 'package:spor_takip/features/social/domain/public_profile.dart';
import 'package:spor_takip/features/workout/domain/muscle_heat.dart';

const socialMe = PublicProfile(userId: 'me', username: 'samet_fit', displayName: 'Samet', inviteCode: 'K7Q2M9XA');
const socialAyse = PublicProfile(userId: 'ayse', username: 'ayse_k', displayName: 'Ayşe Kaya', inviteCode: 'AYSE2345');
const socialBurak = PublicProfile(userId: 'burak', username: 'burak', displayName: 'Burak', inviteCode: 'BURAK234');
const socialCan = PublicProfile(userId: 'can', username: 'can', displayName: 'Can', inviteCode: 'CANCAN23');
const socialDeniz = PublicProfile(userId: 'deniz', username: 'deniz', displayName: 'Deniz', inviteCode: 'DENIZ234');

Friendship socialFriendship(String requester, String addressee, {bool accepted = true}) =>
    Friendship(requester: requester, addressee: addressee, accepted: accepted, createdAt: DateTime(2026, 10, 1));

PlayerStats socialStats({
  int level = 31,
  Rank rank = Rank.determined,
  bool withSections = true,
  DateTime? updatedAt,
}) =>
    PlayerStats(
      level: level,
      totalXp: 18420,
      rank: rank,
      activeTitle: const SharedTitle(kind: TitleKind.muscle, subjectId: 'lats', tier: TitleTier.champion),
      titles: const [
        SharedTitle(kind: TitleKind.muscle, subjectId: 'lats', tier: TitleTier.champion),
        SharedTitle(kind: TitleKind.exercise, subjectId: 'row', exerciseName: 'Barbell Row', tier: TitleTier.master),
      ],
      weekly: withSections ? const WeeklyStats(workouts: 4, sets: 62, mealDays: 6) : null,
      recent: withSections
          ? [
              RecentWorkout(
                name: 'Pull A',
                date: DateTime(2026, 10, 9, 8),
                sets: 18,
                records: const [SharedRecord(name: 'Barbell Row', weightKg: 90, reps: 5)],
              ),
              RecentWorkout(name: 'Legs', date: DateTime(2026, 10, 8, 18), sets: 21, records: const []),
            ]
          : null,
      heat: withSections ? const {'lats': HeatTier.high, 'quadriceps': HeatTier.medium} : null,
      updatedAt: updatedAt ?? DateTime(2026, 10, 9, 9),
    );
