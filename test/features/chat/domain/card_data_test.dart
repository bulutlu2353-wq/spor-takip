import 'package:flutter_test/flutter_test.dart';
import 'package:spor_takip/features/chat/domain/card_data.dart';
import 'package:spor_takip/features/onboarding/domain/profile.dart';
import 'package:spor_takip/features/onboarding/domain/tdee_calculator.dart';
import 'package:spor_takip/features/progress/domain/body_weight_log.dart';

import '../../progress/fixtures.dart';
import '../fixtures.dart';

void main() {
  test('profile field changes pair the base value with the proposed one', () {
    final changes = profileFieldChanges(profileEvent());
    expect([for (final c in changes) (c.field, c.before, c.after)], [
      ('height_cm', 180, 185),
      ('activity_level', 'moderate', 'active'),
    ]);
    final goal = profileFieldChanges(goalEvent()).single;
    expect((goal.field, goal.before, goal.after), ('goal', 'gain_muscle', 'lose_weight'));
  });

  test('profileAfter applies the proposed change', () {
    expect(profileAfter(testProfile, weightEvent(kg: 82)).weightKg, 82);
    final updated = profileAfter(testProfile, profileEvent());
    expect(updated.heightCm, 185);
    expect(updated.activityLevel, ActivityLevel.active);
    expect(profileAfter(testProfile, goalEvent()).goal, Goal.loseWeight);
    expect(profileAfter(testProfile, mealEvent()), same(testProfile));
  });

  test('targetsAfter uses TdeeCalculator on the changed profile', () {
    final expected = const TdeeCalculator().calculate(
      weightKg: 82,
      heightCm: 180,
      birthYear: 1996,
      currentYear: 2026,
      gender: Gender.male,
      activityLevel: ActivityLevel.moderate,
      goal: Goal.gainMuscle,
    );
    final targets = targetsAfter(testProfile, weightEvent(kg: 82), currentYear: 2026)!;
    expect(targets.calorieTarget, expected.calorieTarget);
    expect(targets.proteinTargetG, expected.proteinTargetG);
    expect(targetsAfter(testProfile, mealEvent(), currentYear: 2026), isNull);
  });

  test('weight before is the same-day log, else the profile weight', () {
    expect(weightBefore(weightEvent()), 80);
    expect(weightBefore(weightEvent(logBefore: 81.5)), 81.5);
    expect(weightAfter(weightEvent(kg: 82)), 82);
    expect(weightDate(weightEvent(date: '2026-09-15')), DateTime(2026, 9, 15));
  });

  test('a weight entry is newest when it is not before the last log', () {
    final logs = [BodyWeightLog(date: DateTime(2026, 9, 30), weightKg: 80)];
    expect(isNewestWeight(weightEvent(date: '2026-10-01'), logs), isTrue);
    expect(isNewestWeight(weightEvent(date: '2026-09-30'), logs), isTrue);
    expect(isNewestWeight(weightEvent(date: '2026-09-01'), logs), isFalse);
    expect(isNewestWeight(weightEvent(), const []), isTrue);
  });

  test('meal items scale per-100 g values by grams with one decimal', () {
    final items = mealItems(mealEvent());
    expect(items.first.calories, 330);
    expect(items.first.proteinG, 62);
    expect(items.first.fatG, 7.2);
    expect(items.first.withGrams(150).calories, 247.5);
    expect(items.first.withGrams(150).name, 'Tavuk');
    expect(items.last.needsReview, isTrue);
    expect(round1(0.25), 0.3);
  });

  test('apply extras carry targets and edited grams', () {
    expect(applyExtras(), <String, dynamic>{});
    expect(
      applyExtras(targets: const TdeeResult(calorieTarget: 2800, proteinTargetG: 170)),
      {'calorie_target': 2800, 'protein_target': 170},
    );
    expect(applyExtras(itemGrams: [150, 200]), {
      'item_grams': [150, 200],
    });
  });

  test('program change labels come from the payload', () {
    expect(programChangeLabels(programEvent()), ['+ A: Barbell Deadlift 1×5', '− A: Barbell Squat']);
  });
}
