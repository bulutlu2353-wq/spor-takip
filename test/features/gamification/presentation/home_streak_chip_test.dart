import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spor_takip/features/gamification/application/gamification_providers.dart';
import 'package:spor_takip/features/gamification/domain/player_summary.dart';
import 'package:spor_takip/features/gamification/domain/quests.dart';
import 'package:spor_takip/features/gamification/domain/streak.dart';
import 'package:spor_takip/features/gamification/presentation/widgets/home_streak_chip.dart';

import '../../progress/presentation/test_app.dart';

PlayerSummary _summary({StreakStatus streak = StreakStatus.none, WeekQuests? quests}) {
  final base = playerSummary(const [], const [], const {});
  return PlayerSummary(
    totalXp: base.totalXp,
    progress: base.progress,
    rank: base.rank,
    breakdown: base.breakdown,
    recent: base.recent,
    titles: base.titles,
    upcoming: base.upcoming,
    streak: streak,
    quests: quests,
  );
}

final _quests = WeekQuests(weekStart: DateTime(2026, 10, 5), quests: [
  QuestProgress(kind: QuestKind.workouts, progress: 3, target: 3, doneAt: DateTime(2026, 10, 7)),
  const QuestProgress(kind: QuestKind.record, progress: 0, target: 1),
  const QuestProgress(kind: QuestKind.mealDays, progress: 1, target: 5),
]);

void main() {
  setUpAll(initTestLocalization);

  Future<void> pump(WidgetTester tester, PlayerSummary summary) async {
    await tester.pumpWidget(testApp(
      const HomeStreakChip(),
      overrides: [playerSummaryProvider.overrideWith((ref) async => summary)],
    ));
    await tester.pumpAndSettle();
  }

  testWidgets('shows the streak and done quests', (tester) async {
    await pump(
      tester,
      _summary(streak: const StreakStatus(length: 12, bonusPercent: 5, restLeft: 1, broken: false), quests: _quests),
    );
    expect(find.byKey(const Key('home_streak_chip')), findsOneWidget);
    expect(find.text('12'), findsOneWidget);
    expect(find.text('1/3'), findsOneWidget);
  });

  testWidgets('only the quest count when the streak is 0', (tester) async {
    await pump(tester, _summary(quests: _quests));
    expect(find.byIcon(Icons.local_fire_department), findsNothing);
    expect(find.text('1/3'), findsOneWidget);
  });

  testWidgets('hidden with neither a streak nor quests', (tester) async {
    await pump(tester, _summary());
    expect(find.byKey(const Key('home_streak_chip')), findsNothing);
  });
}
