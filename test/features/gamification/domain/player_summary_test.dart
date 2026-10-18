import 'package:flutter_test/flutter_test.dart';
import 'package:spor_takip/features/gamification/domain/game_settings.dart';
import 'package:spor_takip/features/gamification/domain/levels.dart';
import 'package:spor_takip/features/gamification/domain/player_summary.dart';
import 'package:spor_takip/features/gamification/domain/xp_rules.dart';

import '../game_fixtures.dart';

void main() {
  test('with settings the rank waits for the guardian', () {
    const settings = GameSettings(weeklyGoal: 3);
    final now = DateTime(2026, 10, 5, 12);
    // 600 XP → seviye 5 (Acemi eşiği); 603 hasar < 660 → goblin ayakta.
    final weak = playerSummary(const [], const [], const {},
        rewards: [XpEvent(source: XpSource.challenge, date: DateTime(2026, 10, 5), xp: 600)],
        settings: settings, now: now);
    expect(weak.progress.level, 5);
    expect(weak.rank, Rank.rookie);
    expect(weak.battle!.hpLeft, 57);

    // 800 XP → seviye 6; 804 hasar → goblin yenildi.
    final strong = playerSummary(const [], const [], const {},
        rewards: [XpEvent(source: XpSource.challenge, date: DateTime(2026, 10, 5), xp: 800)],
        settings: settings, now: now);
    expect((strong.rank, strong.battle!.guardiansBeaten), (Rank.novice, 1));
  });

  test('without settings there is no battle and the rank follows the level', () {
    final summary = playerSummary(const [], const [], const {},
        rewards: [XpEvent(source: XpSource.challenge, date: DateTime(2026, 10, 5), xp: 600)]);
    expect((summary.battle, summary.rank), (null, Rank.novice));
  });

  test('an empty history is a level 1 rookie', () {
    final summary = playerSummary(const [], const [], const {});
    expect(summary.totalXp, 0);
    expect(summary.progress.level, 1);
    expect(summary.rank, Rank.rookie);
    expect(summary.recent, isEmpty);
    expect(summary.titles, isEmpty);
    expect(summary.titleById('muscle:chest'), isNull);
  });

  test('combines XP, level, rank, the last ten events and titles', () {
    final sessions = [
      for (var i = 0; i < 12; i++) gameSession('s$i', DateTime(2026, 9, 1 + i, 18), gameSets('bench', 10)),
    ];
    final summary = playerSummary(sessions, [DateTime(2026, 9, 1, 9)], gameExercisesById);
    // 12 × (50 + 50) + 10 = 1210 → seviye 7 (eşik 975), 235 / 250.
    expect(summary.totalXp, 1210);
    expect(summary.breakdown.total, 1210);
    expect((summary.progress.level, summary.progress.xpIntoLevel), (7, 235));
    expect(summary.rank, Rank.novice);
    expect(summary.recent, hasLength(10));
    expect(summary.recent.first.date, DateTime(2026, 9, 12, 18)); // yeniden eskiye
    expect(summary.recent.first.source, XpSource.workout);
    // chest 120 → çırak; bench 12 oturum → çırak.
    expect({for (final t in summary.titles) t.id}, {'muscle:chest', 'exercise:bench'});
    expect(summary.titleById('exercise:bench')?.value, 12);
    expect(summary.titleById('muscle:triceps'), isNull); // 60 < 100
    expect(summary.upcoming.first.id, 'muscle:triceps'); // 60 / 100
  });

  test('challenge rewards add XP, a recent gain and count toward the challenge title', () {
    final reward = XpEvent(source: XpSource.challenge, date: DateTime(2026, 10, 5), xp: 100, label: 'Yarış');
    final summary = playerSummary(const [], const [], const {}, rewards: [reward]);
    expect(summary.totalXp, 100);
    expect(summary.breakdown.challenges, 100);
    expect(summary.recent.single.source, XpSource.challenge);
    expect(summary.titles.single.id, 'challenge:wins');
  });

  test('streak and quests need settings; quests need a user id', () {
    final sessions = [gameSession('a', DateTime(2026, 10, 5, 18), gameSets('bench', 3))];
    final plain = playerSummary(sessions, const [], gameExercisesById);
    expect((plain.streak.length, plain.quests), (0, null));

    final now = DateTime(2026, 10, 6, 9);
    final noUser = playerSummary(sessions, const [], gameExercisesById,
        settings: const GameSettings(weeklyGoal: 4), now: now);
    expect((noUser.streak.length, noUser.streak.restLeft, noUser.quests), (1, 3, null));

    final withUser = playerSummary(sessions, const [], gameExercisesById,
        settings: const GameSettings(weeklyGoal: 4, userId: 'user-1'), now: now);
    expect(withUser.quests!.weekStart, DateTime(2026, 10, 5));
    expect(withUser.quests!.quests, hasLength(3));
  });

  test('precomputed events are used as given', () {
    final event = XpEvent(source: XpSource.quest, date: DateTime(2026, 10, 5), xp: 40, label: 'sets');
    final summary = playerSummary(const [], const [], const {}, events: [event]);
    expect(summary.totalXp, 40);
  });
}
