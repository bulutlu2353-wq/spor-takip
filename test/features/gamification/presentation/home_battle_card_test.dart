import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
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

  testWidgets('tapping opens the battle screen', (tester) async {
    await pump(tester, const BattleState(index: 0, damage: 0, stats: BattleStats.floor));
    await tester.tap(find.byKey(const Key('home_battle_card')));
    await tester.pumpAndSettle();
    expect(find.text('battle_stub'), findsOneWidget);
  });
}
