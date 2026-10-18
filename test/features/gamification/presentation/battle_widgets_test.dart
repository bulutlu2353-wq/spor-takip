import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spor_takip/features/gamification/domain/battle.dart';
import 'package:spor_takip/features/gamification/domain/battle_stats.dart';
import 'package:spor_takip/features/gamification/domain/monsters.dart';
import 'package:spor_takip/features/gamification/presentation/widgets/battle_widgets.dart';
import 'package:spor_takip/features/workout/domain/exercise_taxonomy.dart';

import '../../progress/presentation/test_app.dart';

void main() {
  setUpAll(initTestLocalization);

  testWidgets('avatar, hp bar and weak muscle chips', (tester) async {
    const state = BattleState(index: 0, damage: 100, stats: BattleStats.floor);
    await tester.pumpWidget(testApp(Column(children: [
      const MonsterAvatar(index: 0),
      const BattleHpBar(battle: state),
      WeakMuscleChips(monster: monsterAt(0)),
    ])));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('monster_avatar_mud_goblin')), findsOneWidget);
    expect(find.text('560 / 660'), findsOneWidget);
    expect(find.text(muscleLabelKey('chest').tr()), findsOneWidget);
    expect(find.text(muscleLabelKey('quadriceps').tr()), findsOneWidget);
  });

  test('crit text rounds the share to a percent', () {
    expect(critText(0.4), 'gamification.battle.crit'.tr(namedArgs: {'n': '40'}));
  });
}
