import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:spor_takip/features/gamification/domain/levels.dart';
import 'package:spor_takip/features/social/application/social_providers.dart';
import 'package:spor_takip/features/social/domain/community.dart';
import 'package:spor_takip/features/social/domain/period_keys.dart';
import 'package:spor_takip/features/social/presentation/global_tab.dart';
import 'package:spor_takip/features/workout/application/session_providers.dart';

import '../../progress/presentation/test_app.dart';
import '../fakes.dart';
import '../social_fixtures.dart';

const _titles = [
  GlobalTitle(
    category: 'lats',
    userId: 'burak',
    username: 'burak',
    displayName: 'Burak',
    level: 20,
    rank: Rank.athlete,
    value: 41,
  ),
  GlobalTitle(
    category: 'xp',
    userId: 'ayse',
    username: 'ayse_k',
    displayName: 'Ayşe Kaya',
    level: 42,
    rank: Rank.gladiator,
    value: 3480,
  ),
  GlobalTitle(
    category: 'lats',
    userId: 'ayse',
    username: 'ayse_k',
    displayName: 'Ayşe Kaya',
    level: 42,
    rank: Rank.gladiator,
    value: 41,
  ),
];

const _rows = [
  GlobalRow(
    position: 1,
    userId: 'ayse',
    username: 'ayse_k',
    displayName: 'Ayşe Kaya',
    level: 42,
    rank: Rank.gladiator,
    xp: 4120,
  ),
  GlobalRow(
    position: 2,
    userId: 'me',
    username: 'samet_fit',
    displayName: 'Samet',
    level: 28,
    rank: Rank.dedicated,
    xp: 2190,
  ),
];

void main() {
  setUpAll(initTestLocalization);
  setUp(() => SharedPreferences.setMockInitialValues({}));

  Future<void> pump(WidgetTester tester, FakeSocialRepository repo) async {
    tester.view.physicalSize = const Size(800, 2000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(testApp(
      const Scaffold(body: GlobalTab()),
      scaffold: false,
      overrides: [
        socialRepositoryProvider.overrideWithValue(repo),
        nowProvider.overrideWithValue(() => DateTime(2026, 10, 9, 12)),
      ],
      stubRoutes: {'/social/settings': 'settings-stub'},
    ));
    await tester.pumpAndSettle();
  }

  testWidgets('shows last week global champions and this week top list with me highlighted', (tester) async {
    final repo = FakeSocialRepository(me: socialMe)
      ..globalTitlesResult = _titles
      ..globalRowsResult = _rows;
    await pump(tester, repo);

    expect(repo.globalQueries, [(PeriodKind.week, '2026-W40'), (PeriodKind.week, '2026-W41')]);
    expect(find.byKey(const Key('global_opted_out')), findsNothing);
    expect(
      tester.getTopLeft(find.byKey(const Key('title_xp'))).dy,
      lessThan(tester.getTopLeft(find.byKey(const Key('title_lats'))).dy),
    );
    expect(find.text('@burak, @ayse_k'), findsOneWidget);
    expect(find.text('@ayse_k'), findsWidgets);
    expect(find.byKey(const Key('standing_ayse')), findsOneWidget);
    expect(find.byKey(const Key('standing_me_label')), findsOneWidget);
    expect(find.byKey(const Key('period_remaining')), findsOneWidget);
  });

  testWidgets('the month view asks for month keys; empty results show empty texts', (tester) async {
    final repo = FakeSocialRepository(me: socialMe);
    await pump(tester, repo);
    expect(find.byKey(const Key('global_titles_empty')), findsOneWidget);
    expect(find.byKey(const Key('global_standings_empty')), findsOneWidget);

    repo.globalQueries.clear();
    await tester.tap(find.byKey(const Key('global_period_month')));
    await tester.pumpAndSettle();
    expect(repo.globalQueries, [(PeriodKind.month, '2026-09'), (PeriodKind.month, '2026-10')]);
  });

  testWidgets('opted out shows a note that opens the settings', (tester) async {
    await pump(tester, FakeSocialRepository(me: socialMe.copyWith(competeGlobally: false)));
    expect(find.byKey(const Key('global_opted_out')), findsOneWidget);
    await tester.tap(find.byKey(const Key('global_open_settings')));
    await tester.pumpAndSettle();
    expect(find.text('settings-stub'), findsOneWidget);
  });
}
