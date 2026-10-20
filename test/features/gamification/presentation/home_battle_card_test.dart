import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:spor_takip/features/gamification/application/gamification_providers.dart';
import 'package:spor_takip/features/gamification/domain/battle.dart';
import 'package:spor_takip/features/gamification/domain/battle_stats.dart';
import 'package:spor_takip/features/gamification/domain/player_summary.dart';
import 'package:spor_takip/features/gamification/domain/xp_rules.dart';
import 'package:spor_takip/features/gamification/presentation/widgets/battle_widgets.dart';
import 'package:spor_takip/features/gamification/presentation/widgets/home_battle_card.dart';

import '../../progress/presentation/test_app.dart';

PlayerSummary _summary(BattleState? battle) {
  final base = playerSummary(const [], const [], const {});
  return PlayerSummary(
    totalXp: base.totalXp,
    progress: base.progress,
    rank: base.rank,
    breakdown: base.breakdown,
    recent: base.recent,
    titles: base.titles,
    upcoming: base.upcoming,
    battle: battle,
  );
}

final _hit = BattleHit(
  date: DateTime(2026, 10, 5, 18),
  source: XpSource.workout,
  xp: 100,
  damage: 121,
  critShare: 0.4,
  monsterIndex: 0,
);

void main() {
  setUpAll(initTestLocalization);
  setUp(() => SharedPreferences.setMockInitialValues({}));

  Future<void> pump(WidgetTester tester, BattleState? battle) async {
    await tester.pumpWidget(testApp(
      const HomeBattleCard(),
      overrides: [playerSummaryProvider.overrideWith((ref) async => _summary(battle))],
      stubRoutes: {'/home/battle': 'battle_stub'},
    ));
    await tester.pumpAndSettle();
  }

  testWidgets('shows the monster, its guardian rank, hp and the last hit', (tester) async {
    await pump(tester, BattleState(index: 0, damage: 121, stats: BattleStats.floor, recent: [_hit]));
    expect(find.byKey(const Key('home_battle_card')), findsOneWidget);
    expect(find.text('gamification.battle.monster.mud_goblin'.tr()), findsOneWidget);
    expect(find.text('gamification.battle.guardian_of'.tr(namedArgs: {'rank': 'gamification.rank.novice'.tr()})),
        findsOneWidget);
    expect(find.text('539 / 660'), findsOneWidget);
    expect(find.text('${battleHitDay(_hit.date)} −121 · ${critText(0.4)}'), findsOneWidget);
  });

  testWidgets('asks for a workout before the first hit and warns while healing', (tester) async {
    await pump(tester, const BattleState(index: 0, damage: 0, stats: BattleStats.floor, healing: true));
    expect(find.text('gamification.battle.attack_hint'.tr()), findsOneWidget);
    expect(find.text('gamification.battle.healing'.tr()), findsOneWidget);
  });

  testWidgets('the endless boss shows its kill count', (tester) async {
    await pump(tester, const BattleState(index: 17, damage: 0, stats: BattleStats.floor));
    expect(find.text('gamification.battle.endless'.tr(namedArgs: {'n': '2'})), findsOneWidget);
  });

  testWidgets('hidden without a battle', (tester) async {
    await pump(tester, null);
    expect(find.byKey(const Key('home_battle_card')), findsNothing);
  });

  /// Animasyonu sonuna kadar oynatmadan başlatır.
  Future<void> start(WidgetTester tester, BattleState battle) async {
    await tester.pumpWidget(testApp(
      const HomeBattleCard(),
      overrides: [playerSummaryProvider.overrideWith((ref) async => _summary(battle))],
    ));
    for (var i = 0; i < 4; i++) {
      await tester.pump();
    }
    await tester.pump(const Duration(milliseconds: 100));
  }

  final seenBefore = DateTime(2026, 10, 4).toIso8601String();

  testWidgets('first open marks the hits seen without playing', (tester) async {
    await start(tester, BattleState(index: 0, damage: 121, stats: BattleStats.floor, recent: [_hit]));
    expect(find.byKey(const Key('battle_hit_float')), findsNothing);
    expect((await SharedPreferences.getInstance()).getString(battleSeenHitKey), _hit.date.toIso8601String());
  });

  testWidgets('an unseen hit flies its damage once', (tester) async {
    SharedPreferences.setMockInitialValues({battleSeenHitKey: seenBefore});
    await start(tester, BattleState(index: 0, damage: 121, stats: BattleStats.floor, recent: [_hit]));
    expect(find.byKey(const Key('battle_hit_float')), findsOneWidget);
    expect(find.text('gamification.battle.hit_crit'.tr(namedArgs: {'n': '121'})), findsOneWidget);
    expect((await SharedPreferences.getInstance()).getString(battleSeenHitKey), _hit.date.toIso8601String());
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('battle_hit_float')), findsNothing);
  });

  testWidgets('a kill shows the defeat moment, then the next guardian', (tester) async {
    SharedPreferences.setMockInitialValues({battleSeenHitKey: seenBefore});
    final kill = BattleHit(
      date: DateTime(2026, 10, 5, 18),
      source: XpSource.workout,
      xp: 700,
      damage: 700,
      critShare: 0,
      monsterIndex: 0,
      defeated: const [0],
    );
    await start(tester, BattleState(index: 1, damage: 40, stats: BattleStats.floor, recent: [kill]));
    expect(find.byKey(const Key('battle_defeat_moment')), findsOneWidget);
    expect(
      find.text('gamification.battle.defeated'.tr(namedArgs: {'name': 'gamification.battle.monster.mud_goblin'.tr()})),
      findsOneWidget,
    );
    await tester.pump(const Duration(milliseconds: 1300));
    expect(find.byKey(const Key('battle_defeat_moment')), findsNothing);
    expect(find.text('gamification.battle.monster.rat_king'.tr()), findsOneWidget);
    await tester.pumpAndSettle();
  });

  testWidgets('reduced motion skips the replay but still marks it seen', (tester) async {
    tester.platformDispatcher.accessibilityFeaturesTestValue = const FakeAccessibilityFeatures(disableAnimations: true);
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
    SharedPreferences.setMockInitialValues({battleSeenHitKey: seenBefore});
    await start(tester, BattleState(index: 0, damage: 600, stats: BattleStats.floor, recent: [_hit]));
    expect(find.byKey(const Key('battle_hit_float')), findsNothing);
    expect(find.byKey(const Key('monster_pulse')), findsOneWidget); // 60 / 660 kaldı
    expect((await SharedPreferences.getInstance()).getString(battleSeenHitKey), _hit.date.toIso8601String());
  });

  testWidgets('tapping opens the battle screen', (tester) async {
    await pump(tester, const BattleState(index: 0, damage: 0, stats: BattleStats.floor));
    await tester.tap(find.byKey(const Key('home_battle_card')));
    await tester.pumpAndSettle();
    expect(find.text('battle_stub'), findsOneWidget);
  });
}
