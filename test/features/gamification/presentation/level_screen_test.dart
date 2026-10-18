import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:spor_takip/features/gamification/application/gamification_providers.dart';
import 'package:spor_takip/features/gamification/domain/fair_play.dart';
import 'package:spor_takip/features/gamification/domain/levels.dart';
import 'package:spor_takip/features/gamification/domain/player_summary.dart';
import 'package:spor_takip/features/gamification/domain/quests.dart';
import 'package:spor_takip/features/gamification/domain/streak.dart';
import 'package:spor_takip/features/gamification/domain/titles.dart';
import 'package:spor_takip/features/gamification/domain/xp_rules.dart';
import 'package:spor_takip/features/gamification/presentation/level_screen.dart';
import 'package:spor_takip/features/gamification/presentation/widgets/rank_badge.dart';
import 'package:spor_takip/features/workout/application/session_providers.dart';

import '../../progress/presentation/test_app.dart';

final _progress = levelFor(1234); // seviye 8
final _summary = PlayerSummary(
  totalXp: 1234,
  progress: _progress,
  rank: rankFor(_progress.level),
  breakdown: const XpBreakdown(workouts: 500, sets: 400, records: 50, mealDays: 284),
  recent: [
    XpEvent(source: XpSource.workout, date: DateTime(2026, 10, 9, 18), xp: 115, label: 'Push A', sets: 13),
    XpEvent(source: XpSource.record, date: DateTime(2026, 10, 8, 20), xp: 25, label: 'Squat', weightKg: 140, reps: 3),
    XpEvent(source: XpSource.mealDay, date: DateTime(2026, 10, 8), xp: 10),
  ],
  titles: const [
    TitleProgress(kind: TitleKind.muscle, subjectId: 'lats', value: 1600),
    TitleProgress(kind: TitleKind.muscle, subjectId: 'chest', value: 600),
    TitleProgress(kind: TitleKind.exercise, subjectId: 'squat', value: 12, exerciseName: 'Barbell Squat'),
  ],
  upcoming: const [
    TitleProgress(kind: TitleKind.muscle, subjectId: 'shoulders', value: 320),
    TitleProgress(kind: TitleKind.exercise, subjectId: 'deadlift', value: 41, exerciseName: 'Deadlift'),
  ],
);

void main() {
  setUpAll(initTestLocalization);
  setUp(() => SharedPreferences.setMockInitialValues({}));

  Future<void> pump(WidgetTester tester, Future<PlayerSummary> Function() load) async {
    tester.view.physicalSize = const Size(800, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(testApp(
      const LevelScreen(),
      scaffold: false,
      overrides: [
        playerSummaryProvider.overrideWith((ref) => load()),
        nowProvider.overrideWithValue(() => DateTime(2026, 10, 9, 12)),
      ],
    ));
    await tester.pumpAndSettle();
  }

  testWidgets('shows the header, breakdown, titles, ladder and recent gains', (tester) async {
    await pump(tester, () async => _summary);
    expect(find.byKey(const Key('level_screen')), findsOneWidget);
    for (final key in ['level_header', 'level_breakdown', 'level_titles', 'level_upcoming', 'level_ladder', 'level_recent']) {
      expect(find.byKey(Key(key)), findsOneWidget, reason: key);
    }
    final header = find.byKey(const Key('level_header'));
    final badge = tester.widget<RankBadge>(find.descendant(of: header, matching: find.byType(RankBadge)));
    expect((badge.rank, badge.level), (Rank.novice, 8));
    expect(find.byKey(const Key('level_progress')), findsOneWidget);
    expect(find.byKey(const Key('title_muscle:lats')), findsOneWidget);
    expect(find.byKey(const Key('title_exercise:squat')), findsOneWidget);
    expect(find.byKey(const Key('upcoming_muscle:shoulders')), findsOneWidget);
    expect(find.byKey(const Key('ladder_novice')), findsOneWidget);
    expect(find.byKey(const Key('ladder_rookie')), findsOneWidget);
    for (var i = 0; i < 3; i++) {
      expect(find.byKey(Key('recent_$i')), findsOneWidget);
    }
    expect(find.descendant(of: find.byKey(const Key('recent_1')), matching: find.text('gamification.record')),
        findsOneWidget);
    expect(find.byKey(const Key('level_active_title')), findsNothing);
  });

  testWidgets('equipping a title shows it in the header; tapping it again takes it off', (tester) async {
    await pump(tester, () async => _summary);
    await tester.ensureVisible(find.byKey(const Key('title_equip_muscle:chest')));
    await tester.tap(find.byKey(const Key('title_equip_muscle:chest')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('level_active_title')), findsOneWidget);
    expect(find.byKey(const Key('title_unequip_muscle:chest')), findsOneWidget);
    expect(find.byKey(const Key('title_equip_muscle:lats')), findsOneWidget);

    await tester.tap(find.byKey(const Key('title_unequip_muscle:chest')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('level_active_title')), findsNothing);
  });

  testWidgets('a saved title that is no longer earned is not shown', (tester) async {
    SharedPreferences.setMockInitialValues({'gamification.active_title': 'muscle:neck'});
    await pump(tester, () async => _summary);
    expect(find.byKey(const Key('level_active_title')), findsNothing);
  });

  testWidgets('an empty history shows empty texts', (tester) async {
    await pump(tester, () async => playerSummary(const [], const [], const {}));
    expect(find.byKey(const Key('level_titles_empty')), findsOneWidget);
    expect(find.byKey(const Key('level_recent_empty')), findsOneWidget);
    expect(find.byKey(const Key('level_upcoming')), findsNothing);
  });

  testWidgets('a load error offers a retry', (tester) async {
    await pump(tester, () async => throw Exception('offline'));
    expect(find.byKey(const Key('level_retry')), findsOneWidget);
  });

  testWidgets('challenge rewards show in the breakdown, titles and recent gains', (tester) async {
    final reward = XpEvent(source: XpSource.challenge, date: DateTime(2026, 10, 5), xp: 100, label: 'Yarış');
    await pump(tester, () async => playerSummary(const [], const [], const {}, rewards: [reward]));
    final breakdown = find.byKey(const Key('level_breakdown'));
    expect(find.descendant(of: breakdown, matching: find.text('gamification.breakdown_challenges')), findsOneWidget);
    expect(find.descendant(of: find.byKey(const Key('level_titles')), matching: find.byIcon(Icons.flag_outlined)),
        findsOneWidget);
    expect(find.descendant(of: find.byKey(const Key('level_recent')), matching: find.byIcon(Icons.flag)),
        findsOneWidget);
  });

  testWidgets('a workout without XP shows 0 XP and the reason', (tester) async {
    final skipped = PlayerSummary(
      totalXp: 0,
      progress: levelFor(0),
      rank: Rank.rookie,
      breakdown: const XpBreakdown(),
      recent: [
        XpEvent(source: XpSource.workout, date: DateTime(2026, 10, 9, 18), xp: 0, label: 'Kısa', skip: SkipReason.tooSmall),
        XpEvent(source: XpSource.workout, date: DateTime(2026, 10, 9, 12), xp: 0, label: 'Üçüncü', skip: SkipReason.dailyLimit),
      ],
      titles: const [],
      upcoming: const [],
    );
    await pump(tester, () async => skipped);
    final recent = find.byKey(const Key('level_recent'));
    expect(find.descendant(of: recent, matching: find.text('gamification.skip_too_small'.tr())), findsOneWidget);
    expect(find.descendant(of: recent, matching: find.text('gamification.skip_daily_limit'.tr())), findsOneWidget);
    expect(find.descendant(of: recent, matching: find.text('gamification.xp_none'.tr())), findsNWidgets(2));
  });

  testWidgets('the info button opens the XP rules', (tester) async {
    await pump(tester, () async => _summary);
    await tester.tap(find.byKey(const Key('level_rules_button')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('level_rules_sheet')), findsOneWidget);
    expect(find.text('gamification.rules_minimum'.tr()), findsOneWidget);
    expect(find.text('gamification.rules_streak'.tr()), findsOneWidget);
    expect(find.text('gamification.rules_quests'.tr()), findsOneWidget);
    expect(find.text('gamification.rules_battle'.tr()), findsOneWidget);
  });

  testWidgets('shows the streak and quest cards', (tester) async {
    await pump(
      tester,
      () async => PlayerSummary(
        totalXp: _summary.totalXp,
        progress: _summary.progress,
        rank: _summary.rank,
        breakdown: const XpBreakdown(streak: 12, quests: 140),
        recent: const [],
        titles: const [],
        upcoming: const [],
        streak: const StreakStatus(length: 14, bonusPercent: 10, restLeft: 2, broken: false),
        quests: WeekQuests(weekStart: DateTime(2026, 10, 5), quests: [
          QuestProgress(kind: QuestKind.workouts, progress: 4, target: 4, doneAt: DateTime(2026, 10, 8)),
          const QuestProgress(kind: QuestKind.muscle, muscle: 'chest', progress: 3, target: 8),
          const QuestProgress(kind: QuestKind.mealDays, progress: 2, target: 5),
        ]),
      ),
    );
    final streak = find.byKey(const Key('level_streak_card'));
    expect(find.descendant(of: streak, matching: find.textContaining('gamification.streak_days'.tr(namedArgs: {'n': '14'}))), findsOneWidget);
    expect(find.descendant(of: streak, matching: find.text('gamification.streak_bonus'.tr(namedArgs: {'n': '10'}))), findsOneWidget);
    expect(find.descendant(of: streak, matching: find.text('gamification.streak_rest_left'.tr(namedArgs: {'n': '2'}))), findsOneWidget);

    final quests = find.byKey(const Key('level_quests_card'));
    expect(find.descendant(of: quests, matching: find.text('gamification.quest_workouts'.tr(namedArgs: {'n': '4'}))), findsOneWidget);
    expect(find.descendant(of: quests, matching: find.text('gamification.quest_meal_days'.tr(namedArgs: {'n': '5'}))), findsOneWidget);
    expect(find.descendant(of: find.byKey(const Key('quest_0')), matching: find.byIcon(Icons.check_circle)), findsOneWidget);
    expect(find.descendant(of: quests, matching: find.text('gamification.quests_bonus'.tr())), findsOneWidget);
    // 9 Ekim 12:00 → pazartesiye 2,5 gün.
    expect(find.descendant(of: quests, matching: find.text('social.period_remaining_days'.tr(namedArgs: {'n': '3'}))), findsOneWidget);

    final breakdown = find.byKey(const Key('level_breakdown'));
    expect(find.descendant(of: breakdown, matching: find.text('gamification.breakdown_streak'.tr())), findsOneWidget);
    expect(find.descendant(of: breakdown, matching: find.text('140')), findsOneWidget);
  });

  testWidgets('a broken streak invites a new one; no quests card without quests', (tester) async {
    await pump(tester, () async => playerSummary(const [], const [], const {}));
    expect(find.text('gamification.streak_broken'.tr()), findsOneWidget);
    expect(find.byKey(const Key('level_quests_card')), findsNothing);
  });

  testWidgets('recent quest and streak rows', (tester) async {
    await pump(
      tester,
      () async => playerSummary(const [], const [], const {}, events: [
        XpEvent(
          source: XpSource.workout,
          date: DateTime(2026, 10, 8, 18),
          xp: 71,
          label: 'Push A',
          sets: 3,
          streakBonus: 6,
          streakPercent: 10,
        ),
        XpEvent(source: XpSource.quest, date: DateTime(2026, 10, 8, 19), xp: 40, label: 'mealDays', target: 5),
        XpEvent(source: XpSource.quest, date: DateTime(2026, 10, 8, 20), xp: 60, label: 'all'),
      ]),
    );
    expect(find.text('${'gamification.workout_sets'.tr(namedArgs: {'n': '3'})} · ${'gamification.streak_detail'.tr(namedArgs: {'n': '10'})}'), findsOneWidget);
    expect(find.text('gamification.quest_event'.tr(namedArgs: {'name': 'gamification.quest_meal_days'.tr(namedArgs: {'n': '5'})})), findsOneWidget);
    expect(find.text('gamification.quest_all'.tr()), findsOneWidget);
  });

  testWidgets('a rank whose level is reached but whose guardian stands says so', (tester) async {
    // Seviye 8 ama goblin ayakta → rütbe Çaylak; Acemi "Bekçiyi yen" der, Amatör (seviye 10) kilitli.
    final gated = PlayerSummary(
      totalXp: _summary.totalXp,
      progress: _summary.progress,
      rank: Rank.rookie,
      breakdown: _summary.breakdown,
      recent: _summary.recent,
      titles: _summary.titles,
      upcoming: _summary.upcoming,
    );
    await pump(tester, () async => gated);
    expect(find.byKey(const Key('ladder_guard_novice')), findsOneWidget);
    expect(find.byKey(const Key('ladder_guard_amateur')), findsNothing);
  });
}
