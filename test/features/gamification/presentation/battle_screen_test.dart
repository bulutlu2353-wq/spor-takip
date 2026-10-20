import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spor_takip/features/gamification/application/gamification_providers.dart';
import 'package:spor_takip/features/gamification/domain/battle.dart';
import 'package:spor_takip/features/gamification/domain/battle_stats.dart';
import 'package:spor_takip/features/gamification/domain/levels.dart';
import 'package:spor_takip/features/gamification/domain/player_summary.dart';
import 'package:spor_takip/features/gamification/domain/xp_rules.dart';
import 'package:spor_takip/features/gamification/presentation/battle_screen.dart';

import '../../progress/presentation/test_app.dart';

PlayerSummary _summary({required int xp, required BattleState battle}) {
  final progress = levelFor(xp);
  return PlayerSummary(
    totalXp: xp,
    progress: progress,
    rank: gatedRank(progress.level, battle),
    breakdown: const XpBreakdown(),
    recent: const [],
    titles: const [],
    upcoming: const [],
    battle: battle,
  );
}

const _stats = BattleStats(strength: 44, endurance: 48, consistency: 50);

void main() {
  setUpAll(initTestLocalization);

  Future<void> pump(WidgetTester tester, PlayerSummary summary) async {
    // Canı az canavarın nabzı sonsuz döner; pumpAndSettle takılmasın.
    tester.platformDispatcher.accessibilityFeaturesTestValue = const FakeAccessibilityFeatures(disableAnimations: true);
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
    tester.view.physicalSize = const Size(800, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(testApp(
      const BattleScreen(),
      overrides: [playerSummaryProvider.overrideWith((ref) async => summary)],
      scaffold: false,
    ));
    await tester.pumpAndSettle();
  }

  testWidgets('guardian not beaten yet: the gate shows the next rank', (tester) async {
    // 600 XP → seviye 5; goblin ayakta.
    await pump(tester, _summary(xp: 600, battle: const BattleState(index: 0, damage: 600, stats: _stats)));
    expect(find.byKey(const Key('battle_screen')), findsOneWidget);
    expect(find.text('gamification.battle.gate_open'.tr(namedArgs: {'rank': 'gamification.rank.novice'.tr()})),
        findsOneWidget);
    expect(find.byKey(const Key('battle_gate_wait')), findsNothing);
    expect(find.text('gamification.battle.damage_bonus'.tr(namedArgs: {'n': '24'})), findsOneWidget);
    expect(find.text('44'), findsOneWidget);
    expect(find.text('gamification.battle.hits_empty'.tr()), findsOneWidget);
    expect(find.byKey(const Key('monster_pulse')), findsNWidgets(2)); // başlık + yoldaki aktif satır
  });

  testWidgets('guardian beaten ahead of the level: waits for the level', (tester) async {
    // 300 XP → seviye 3; goblin yenildi → Acemi seviye 5'te.
    await pump(tester, _summary(xp: 300, battle: const BattleState(index: 1, damage: 0, stats: _stats)));
    expect(
      find.text('gamification.battle.gate_wait'.tr(namedArgs: {'n': '5', 'rank': 'gamification.rank.novice'.tr()})),
      findsOneWidget,
    );
    expect(find.text('gamification.battle.gate_level'.tr(namedArgs: {'n': '10'})), findsOneWidget);
  });

  testWidgets('recent hits and the monster path', (tester) async {
    final battle = BattleState(index: 1, damage: 144, stats: _stats, recent: [
      BattleHit(
        date: DateTime(2026, 10, 5, 18),
        source: XpSource.workout,
        xp: 800,
        damage: 804,
        critShare: 0,
        monsterIndex: 0,
        defeated: const [0],
      ),
    ]);
    await pump(tester, _summary(xp: 800, battle: battle));
    expect(find.text('gamification.battle.hit_line'.tr(namedArgs: {'xp': '800', 'damage': '804'})), findsOneWidget);
    expect(
      find.text('gamification.battle.defeated'.tr(namedArgs: {'name': 'gamification.battle.monster.mud_goblin'.tr()})),
      findsOneWidget,
    );
    await tester.scrollUntilVisible(find.byKey(const Key('battle_path_ancient_titan')), 300);
    expect(find.byKey(const Key('battle_path_done_mud_goblin')), findsOneWidget);
    expect(find.byKey(const Key('battle_path_active_rat_king')), findsOneWidget);
    expect(
      find.descendant(
        of: find.byKey(const Key('battle_path_done_mud_goblin')),
        matching: find.byKey(const Key('monster_stamp')),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.byKey(const Key('battle_path_locked_skeleton_guard')),
        matching: find.byKey(const Key('monster_fog')),
      ),
      findsOneWidget,
    );
    expect(find.text('gamification.battle.monster.skeleton_guard'.tr()), findsOneWidget);
    expect(find.text('gamification.battle.monster.shadow_wolf'.tr()), findsNothing);
    expect(find.text('gamification.battle.unknown'.tr()), findsNWidgets(13)); // 3…15
  });

  testWidgets('the info button opens the rules', (tester) async {
    await pump(tester, _summary(xp: 0, battle: const BattleState(index: 0, damage: 0, stats: _stats)));
    await tester.tap(find.byKey(const Key('battle_rules_button')));
    await tester.pumpAndSettle();
    expect(find.text('gamification.rules_battle'.tr()), findsOneWidget);
  });
}
