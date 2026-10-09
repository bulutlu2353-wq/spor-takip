import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:spor_takip/features/gamification/application/gamification_providers.dart';
import 'package:spor_takip/features/gamification/domain/levels.dart';
import 'package:spor_takip/features/gamification/domain/player_summary.dart';
import 'package:spor_takip/features/gamification/domain/titles.dart';
import 'package:spor_takip/features/gamification/domain/xp_rules.dart';
import 'package:spor_takip/features/gamification/presentation/level_screen.dart';
import 'package:spor_takip/features/gamification/presentation/widgets/rank_badge.dart';

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
      overrides: [playerSummaryProvider.overrideWith((ref) => load())],
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
}
