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
    final image = tester.widget<Image>(find.byType(Image));
    final provider = image.image as ResizeImage;
    expect((provider.imageProvider as AssetImage).assetName, 'assets/monsters/mud_goblin.jpg');
    expect(provider.width, (64 * monsterAt(0).zoom * tester.view.devicePixelRatio).ceil());
    expect(find.byIcon(Icons.pest_control), findsNothing);
    expect(find.byKey(const Key('monster_stamp')), findsNothing);
    expect(find.byKey(const Key('monster_fog')), findsNothing);
    expect(find.byKey(const Key('monster_pulse')), findsNothing);
    expect(find.text('560 / 660'), findsOneWidget);
    expect(find.text(muscleLabelKey('chest').tr()), findsOneWidget);
    expect(find.text(muscleLabelKey('quadriceps').tr()), findsOneWidget);
  });

  testWidgets('each look draws its own layer', (tester) async {
    tester.platformDispatcher.accessibilityFeaturesTestValue = const FakeAccessibilityFeatures(disableAnimations: true);
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
    await tester.pumpWidget(testApp(const Column(children: [
      MonsterAvatar(index: 0, look: MonsterLook.defeated),
      MonsterAvatar(index: 1, look: MonsterLook.fogged),
      MonsterAvatar(index: 2, look: MonsterLook.lowHp),
      MonsterAvatar(index: 3, size: 44, look: MonsterLook.defeated),
    ])));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('monster_stamp')), findsNWidgets(2));
    expect(find.text('gamification.battle.stamp'.tr()), findsOneWidget); // 44 px'te metin yerine çarpı
    expect(find.byKey(const Key('monster_fog')), findsOneWidget);
    expect(find.text('?'), findsOneWidget);
    expect(find.byKey(const Key('monster_pulse')), findsOneWidget);
  });

  test('active look turns low below 30% hp and the path hides names past the next one', () {
    final hp = monsterHp(0);
    BattleState at(int damage) => BattleState(index: 0, damage: damage, stats: BattleStats.floor);
    expect(activeLook(at(0)), MonsterLook.normal);
    expect(activeLook(at((hp * 0.7).floor())), MonsterLook.normal);
    expect(activeLook(at((hp * 0.7).floor() + 10)), MonsterLook.lowHp);
    expect(pathNameVisible(0, 2), isTrue);
    expect(pathNameVisible(2, 2), isTrue);
    expect(pathNameVisible(3, 2), isTrue);
    expect(pathNameVisible(4, 2), isFalse);
  });

  test('crit text rounds the share to a percent', () {
    expect(critText(0.4), 'gamification.battle.crit'.tr(namedArgs: {'n': '40'}));
  });
}
