import 'package:flutter_test/flutter_test.dart';
import 'package:spor_takip/features/gamification/domain/fair_play.dart';
import 'package:spor_takip/features/gamification/domain/quests.dart';
import 'package:spor_takip/features/gamification/domain/xp_rules.dart';
import 'package:spor_takip/features/workout/domain/exercise.dart';
import 'package:spor_takip/features/workout/domain/exercise_taxonomy.dart';
import 'package:spor_takip/features/workout/domain/workout_session.dart';

import '../game_fixtures.dart';

// 5 Ekim 2026 pazartesi; 28 Eylül önceki hafta.
final _week = DateTime(2026, 10, 5);

/// Her kası birincil çalıştıran hareket (kas görevinin seçimi ne olursa olsun katkı verir).
const _everything = Exercise(id: 'bench', name: 'Barbell Bench Press', primaryMuscles: muscleGroups);

QuestInputs _inputs(
  List<WorkoutSession> sessions, {
  List<DateTime> meals = const [],
  int weeklyGoal = 3,
  Map<String, Exercise>? exercisesById,
}) =>
    QuestInputs(
      verdicts: judgeSessions(sessions),
      recordTimes: [
        for (final e in xpEvents(sessions, const []))
          if (e.source == XpSource.record) e.date,
      ],
      mealTimes: meals,
      exercisesById: exercisesById ?? gameExercisesById,
      weeklyGoal: weeklyGoal,
    );

QuestProgress _progress(QuestKind kind, QuestInputs inputs, {String? muscle}) =>
    questProgress((kind: kind, muscle: muscle), inputs, _week);

void main() {
  test('fnv1a32 matches the reference vectors', () {
    expect(fnv1a32(''), 0x811c9dc5);
    expect(fnv1a32('a'), 0xe40c292c);
    expect(fnv1a32('foobar'), 0xbf9cf968);
  });

  group('pickQuests', () {
    test('is stable and takes one quest from each category', () {
      final picks = pickQuests('user-1', _week);
      expect(pickQuests('user-1', _week), picks);
      expect(picks, hasLength(3));
      for (final (i, pick) in picks.indexed) {
        expect(questCategories[i], contains(pick.kind));
        expect(pick.muscle, pick.kind == QuestKind.muscle ? isIn(muscleGroups) : isNull);
      }
    });

    test('changes across weeks', () {
      final weeks = {
        for (var i = 0; i < 20; i++) pickQuests('user-1', DateTime(2026, 10, 5 + 7 * i)).map((p) => p.kind).join(),
      };
      expect(weeks.length, greaterThan(1));
    });
  });

  group('questProgress', () {
    test('workouts: done at the workout that reaches the weekly goal', () {
      final p = _progress(
        QuestKind.workouts,
        _inputs([
          gameSession('a', DateTime(2026, 10, 5, 18), gameSets('bench', 3)),
          gameSession('small', DateTime(2026, 10, 6, 18), gameSets('bench', 2)),
          gameSession('b', DateTime(2026, 10, 7, 18), gameSets('bench', 3)),
          gameSession('c', DateTime(2026, 10, 9, 18), gameSets('bench', 3)),
          gameSession('next', DateTime(2026, 10, 12, 18), gameSets('bench', 3)),
        ], weeklyGoal: 2),
      );
      expect((p.progress, p.target, p.doneAt), (3.0, 2.0, DateTime(2026, 10, 7, 18)));
    });

    test('sets and volume targets grow from the previous 4 weeks', () {
      final history = [
        for (final day in [7, 14, 21, 28])
          gameSession('h$day', DateTime(2026, 9, day, 18), gameSets('bench', 25, kg: 100, reps: 10)),
      ];
      final inputs = _inputs([...history, gameSession('a', DateTime(2026, 10, 6, 18), gameSets('bench', 20, kg: 10, reps: 10))]);
      final sets = _progress(QuestKind.sets, inputs);
      // 100 / 4 × 1,1 = 27,5 → 30.
      expect((sets.progress, sets.target, sets.done), (20.0, 30.0, false));
      final volume = _progress(QuestKind.volume, inputs);
      // 100000 / 4 × 1,1 = 27500.
      expect((volume.progress, volume.target), (2000.0, 27500.0));
    });

    test('sets and volume targets have floors and a ceiling', () {
      final empty = _inputs(const []);
      expect(_progress(QuestKind.sets, empty).target, 15);
      expect(_progress(QuestKind.volume, empty).target, 3000);
      final heavy = _inputs([
        for (final day in [7, 8, 9, 10, 14, 15, 16, 17])
          gameSession('h$day', DateTime(2026, 9, day, 18), gameSets('bench', 30, kg: 50, reps: 5)),
      ]);
      // 240 / 4 × 1,1 = 66 → 70 → 60.
      expect(_progress(QuestKind.sets, heavy).target, 60);
    });

    test('long: only workouts of at least 45 minutes', () {
      final p = _progress(
        QuestKind.long,
        _inputs([
          gameSession('short', DateTime(2026, 10, 5, 18), gameSets('bench', 3), duration: const Duration(minutes: 30)),
          gameSession('a', DateTime(2026, 10, 6, 18), gameSets('bench', 3), duration: const Duration(minutes: 45)),
          gameSession('b', DateTime(2026, 10, 8, 18), gameSets('bench', 3)),
        ]),
      );
      expect((p.progress, p.doneAt), (2.0, DateTime(2026, 10, 8, 18)));
    });

    test('record: done at the record event', () {
      final p = _progress(
        QuestKind.record,
        _inputs([
          gameSession('base', DateTime(2026, 10, 1, 18), gameSets('bench', 3, kg: 100, reps: 5)),
          gameSession('pr', DateTime(2026, 10, 6, 18), gameSets('bench', 3, kg: 110, reps: 5)),
        ]),
      );
      expect((p.progress, p.target, p.doneAt), (1.0, 1.0, DateTime(2026, 10, 6, 18)));
    });

    test('muscle: weighted counted sets for the picked muscle', () {
      final inputs = _inputs([
        gameSession('a', DateTime(2026, 10, 5, 18), gameSets('bench', 6)), // göğüs 6, triceps 3
        gameSession('b', DateTime(2026, 10, 7, 18), gameSets('bench', 6)),
      ]);
      expect(_progress(QuestKind.muscle, inputs, muscle: 'chest').doneAt, DateTime(2026, 10, 7, 18));
      final triceps = _progress(QuestKind.muscle, inputs, muscle: 'triceps');
      expect((triceps.progress, triceps.target, triceps.done), (6.0, 8.0, false));
    });

    test('variety: muscle groups with at least 3 weighted sets', () {
      final p = _progress(
        QuestKind.variety,
        _inputs([
          gameSession('a', DateTime(2026, 10, 5, 18), gameSets('bench', 4)), // göğüs 4, triceps 2
          gameSession('b', DateTime(2026, 10, 6, 18), gameSets('squat', 3)), // quadriceps 3
          gameSession('c', DateTime(2026, 10, 7, 18), gameSets('bench', 3)), // göğüs 7, triceps 3,5
        ]),
      );
      expect((p.progress, p.target, p.done), (3.0, 4.0, false));
    });

    test('weekend: a counted workout on Saturday or Sunday', () {
      final p = _progress(
        QuestKind.weekend,
        _inputs([
          gameSession('fri', DateTime(2026, 10, 9, 18), gameSets('bench', 3)),
          gameSession('sun', DateTime(2026, 10, 11, 10), gameSets('bench', 3)),
        ]),
      );
      expect(p.doneAt, DateTime(2026, 10, 11, 10));
    });

    test('meal days: done at the first meal of the fifth day', () {
      final p = _progress(
        QuestKind.mealDays,
        _inputs(const [], meals: [
          for (var d = 5; d <= 9; d++) ...[DateTime(2026, 10, d, 13), DateTime(2026, 10, d, 8)],
          DateTime(2026, 10, 12, 8),
        ]),
      );
      expect((p.progress, p.doneAt), (5.0, DateTime(2026, 10, 9, 8)));
    });

    test('full days: a counted workout and a meal on the same day, at the later of the two', () {
      final p = _progress(
        QuestKind.fullDays,
        _inputs([
          for (final d in [5, 6, 7, 8]) gameSession('s$d', DateTime(2026, 10, d, 18), gameSets('bench', 3)),
        ], meals: [
          DateTime(2026, 10, 5, 8),
          DateTime(2026, 10, 6, 20),
          DateTime(2026, 10, 7, 21),
          DateTime(2026, 10, 9, 8), // antrenmansız gün
        ]),
      );
      expect((p.progress, p.target, p.doneAt), (3.0, 3.0, DateTime(2026, 10, 7, 21)));
    });
  });

  group('weekQuests', () {
    // Önceki hafta düşük kilo (rekor tabanı); bu hafta 3 gün her kası çalıştıran ağır antrenman + 5 gün öğün:
    // hangi 3 görev seçilirse seçilsin hepsi biter.
    final sessions = [
      gameSession('base', DateTime(2026, 10, 1, 18), gameSets('bench', 10, kg: 100, reps: 5)),
      for (final d in [5, 7, 10]) gameSession('s$d', DateTime(2026, 10, d, 18), gameSets('bench', 10, kg: 110, reps: 5)),
    ];
    final meals = [for (final d in [5, 6, 7, 8, 10]) DateTime(2026, 10, d, 8)];
    final inputs = _inputs(sessions, meals: meals, weeklyGoal: 2, exercisesById: {'bench': _everything});

    test('all three done → bonus at the last completion', () {
      final week = weekQuests(inputs, userId: 'user-1', weekStart: _week);
      expect(week.quests.map((q) => (kind: q.kind, muscle: q.muscle)), pickQuests('user-1', _week));
      expect(week.quests.every((q) => q.done), isTrue);
      final last = week.quests.map((q) => q.doneAt!).reduce((a, b) => a.isAfter(b) ? a : b);
      expect((week.bonusDone, week.bonusAt), (true, last));
    });

    test('nothing this week → no bonus', () {
      final week = weekQuests(inputs, userId: 'user-1', weekStart: DateTime(2026, 10, 12));
      expect(week.quests.any((q) => q.done), isFalse);
      expect(week.bonusAt, isNull);
    });
  });

  test('questWeeks spans the first to the last activity week', () {
    expect(questWeeks(_inputs(const [])), isEmpty);
    final weeks = questWeeks(_inputs(
      [gameSession('a', DateTime(2026, 9, 30, 18), gameSets('bench', 3))],
      meals: [DateTime(2026, 10, 13, 8)],
    ));
    expect(weeks, [DateTime(2026, 9, 28), DateTime(2026, 10, 5), DateTime(2026, 10, 12)]);
  });
}
