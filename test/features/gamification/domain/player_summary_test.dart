import 'package:flutter_test/flutter_test.dart';
import 'package:spor_takip/features/gamification/domain/levels.dart';
import 'package:spor_takip/features/gamification/domain/player_summary.dart';
import 'package:spor_takip/features/gamification/domain/xp_rules.dart';

import '../game_fixtures.dart';

void main() {
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
}
