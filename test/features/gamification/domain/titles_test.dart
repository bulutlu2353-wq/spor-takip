import 'package:flutter_test/flutter_test.dart';
import 'package:spor_takip/features/gamification/domain/titles.dart';

import '../game_fixtures.dart';

TitleProgress _muscle(String id, double value) =>
    TitleProgress(kind: TitleKind.muscle, subjectId: id, value: value);

TitleProgress _exercise(String id, double value) =>
    TitleProgress(kind: TitleKind.exercise, subjectId: id, value: value, exerciseName: id);

void main() {
  test('muscle values weigh primary 1 and secondary 0.5; exercise values count sessions', () {
    final all = titleProgress([
      gameSession('a', DateTime(2026, 10, 1), [...gameSets('bench', 4), gameSet('bench', done: false)]),
      gameSession('b', DateTime(2026, 10, 2), gameSets('bench', 2)),
      gameSession('c', DateTime(2026, 10, 3), [gameSet('squat', done: false)]),
      gameSession('live', null, gameSets('squat', 9)),
    ], gameExercisesById);
    final byId = {for (final t in all) t.id: t};
    expect(byId['muscle:chest']!.value, 6);
    expect(byId['muscle:triceps']!.value, 3);
    expect(byId['exercise:bench']!.value, 2);
    expect(byId['exercise:bench']!.exerciseName, 'Barbell Bench Press');
    expect(byId.containsKey('exercise:squat'), isFalse);
    expect(byId.containsKey('muscle:quadriceps'), isFalse);
  });

  test('an unknown exercise still earns its exercise title under the set name', () {
    final all = titleProgress([gameSession('a', DateTime(2026, 10, 1), gameSets('squat', 1))], const {});
    expect(all.single.id, 'exercise:squat');
    expect(all.single.exerciseName, 'Barbell Squat');
  });

  test('tiers and next thresholds follow the kind', () {
    expect(_muscle('chest', 99.5).tier, isNull);
    expect(_muscle('chest', 99.5).nextTier, TitleTier.apprentice);
    expect(_muscle('chest', 100).tier, TitleTier.apprentice);
    expect(_muscle('chest', 100).nextThreshold, 500);
    expect(_muscle('chest', 1500).tier, TitleTier.champion);
    expect(_muscle('chest', 1500).nextThreshold, isNull);
    expect(_muscle('chest', 1500).nextTier, isNull);
    expect(_exercise('bench', 10).tier, TitleTier.apprentice);
    expect(_exercise('bench', 49).nextThreshold, 50);
    expect(_exercise('bench', 49).nextTier, TitleTier.master);
  });

  test('earned titles sort by tier, then value', () {
    final earned = earnedTitles([
      _muscle('chest', 600),
      _exercise('bench', 12),
      _muscle('lats', 2000),
      _muscle('quadriceps', 50),
      _muscle('shoulders', 700),
    ]);
    expect([for (final t in earned) t.id], ['muscle:lats', 'muscle:shoulders', 'muscle:chest', 'exercise:bench']);
  });

  test('upcoming titles are the closest to their next tier, champions excluded', () {
    final all = [_muscle('chest', 450), _exercise('bench', 12), _muscle('quadriceps', 50), _muscle('lats', 2000)];
    expect([for (final t in upcomingTitles(all)) t.id], ['muscle:chest', 'muscle:quadriceps', 'exercise:bench']);
    expect([for (final t in upcomingTitles(all, count: 2)) t.id], ['muscle:chest', 'muscle:quadriceps']);
  });
}
