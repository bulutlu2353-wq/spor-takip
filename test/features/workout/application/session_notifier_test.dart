import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spor_takip/features/onboarding/application/auth_providers.dart';
import 'package:spor_takip/features/progress/application/progress_providers.dart';
import 'package:spor_takip/features/workout/application/session_notifier.dart';
import 'package:spor_takip/features/workout/application/session_providers.dart';
import 'package:spor_takip/features/workout/application/workout_providers.dart';
import 'package:spor_takip/features/workout/domain/exercise.dart';
import 'package:spor_takip/features/workout/domain/workout_session.dart';

import '../../progress/fakes.dart';
import '../fakes.dart';

const _bench = Exercise(id: 'Bench', name: 'Bench Press', equipment: 'barbell', primaryMuscles: ['chest']);

SessionSet _s(
  String id, {
  int pos = 0,
  int idx = 0,
  String exercise = 'Barbell_Squat',
  double? suggested = 60,
  double? pct,
  bool amrap = false,
  bool done = false,
  double? weight,
  int? reps,
  int max = 5,
}) {
  return SessionSet(
    id: id,
    exercisePosition: pos,
    setIndex: idx,
    exerciseId: exercise,
    exerciseName: exercise,
    targetRepsMin: 5,
    targetRepsMax: max,
    isAmrap: amrap,
    percent1rm: pct,
    restSeconds: 90,
    suggestedWeightKg: suggested,
    weightKg: weight,
    reps: reps,
    completedAt: done ? DateTime(2026, 9, 26, 10, 5) : null,
  );
}

WorkoutSession _session(String id, List<SessionSet> sets, {DateTime? finishedAt}) => WorkoutSession(
      id: id,
      programId: 'p1',
      programName: 'SL',
      workoutName: 'A',
      workoutPosition: 0,
      startedAt: DateTime(2026, 9, 26, 10),
      finishedAt: finishedAt,
      sets: sets,
    );

void main() {
  late FakeSessionRepository repo;
  late ProviderContainer container;
  late FakeProgressDataRepository progressRepo;

  void setUpWith(List<SessionSet> sets, {List<WorkoutSession> history = const []}) {
    repo = FakeSessionRepository(sessions: [_session('sess', sets), ...history]);
    progressRepo = FakeProgressDataRepository();
    container = ProviderContainer(overrides: [
      progressDataRepositoryProvider.overrideWithValue(progressRepo),
      isLoggedInProvider.overrideWithValue(true),
      sessionRepositoryProvider.overrideWithValue(repo),
      exerciseRepositoryProvider.overrideWithValue(FakeExerciseRepository([_bench])),
      oneRepMaxRepositoryProvider.overrideWithValue(FakeOneRepMaxRepository()),
    ]);
    addTearDown(container.dispose);
    container.listen(sessionNotifierProvider('sess'), (_, _) {});
  }

  Future<void> load() => container.read(sessionNotifierProvider('sess').future);
  SessionNotifier notifier() => container.read(sessionNotifierProvider('sess').notifier);
  WorkoutSession current() => container.read(sessionNotifierProvider('sess')).requireValue;

  test('complete saves the suggested weight and target reps', () async {
    setUpWith([_s('a'), _s('b', idx: 1)]);
    await load();

    expect(await notifier().complete('a'), isTrue);

    final saved = repo.updatedSets.single;
    expect(saved.id, 'a');
    expect(saved.weightKg, 60);
    expect(saved.reps, 5);
    expect(saved.completedAt, isNotNull);
    expect(current().setById('a').isCompleted, isTrue);
  });

  test('a failed save reverts the set', () async {
    setUpWith([_s('a')]);
    await load();
    repo.updateError = Exception('offline');

    expect(await notifier().complete('a'), isFalse);

    expect(current().setById('a').isCompleted, isFalse);
    expect(current().setById('a').weightKg, isNull);
  });

  test('an AMRAP set without reps cannot be completed', () async {
    setUpWith([_s('a', amrap: true)]);
    await load();

    expect(await notifier().complete('a'), isFalse);
    expect(repo.updatedSets, isEmpty);

    notifier().setReps('a', 8);
    expect(await notifier().complete('a'), isTrue);
    expect(repo.updatedSets.single.reps, 8);
  });

  test('uncomplete clears completion but keeps the values', () async {
    setUpWith([_s('a', done: true, weight: 60, reps: 5)]);
    await load();

    expect(await notifier().uncomplete('a'), isTrue);

    final set = current().setById('a');
    expect(set.isCompleted, isFalse);
    expect(set.weightKg, 60);
    expect(repo.updatedSets.single.completedAt, isNull);
  });

  test('editing the first pending weight fills the following pending sets of the lift', () async {
    setUpWith([_s('a'), _s('b', idx: 1), _s('c', pos: 1, exercise: 'Bench')]);
    await load();

    notifier().setWeight('a', 65);
    expect(current().setById('a').weightKg, 65);
    expect(current().setById('b').weightKg, 65);
    expect(current().setById('c').weightKg, isNull);

    notifier().setWeight('b', 70);
    expect(current().setById('a').weightKg, 65, reason: 'b is not the first pending set');
    expect(current().setById('b').weightKg, 70);
  });

  test('propagation starts at the first pending set and skips other percentages', () async {
    setUpWith([
      _s('done', done: true, weight: 60, reps: 5),
      _s('p1', idx: 1, pct: 65),
      _s('p2', idx: 2, pct: 65),
      _s('p3', idx: 3, pct: 85),
    ]);
    await load();

    notifier().setWeight('p1', 50);
    expect(current().setById('p2').weightKg, 50);
    expect(current().setById('p3').weightKg, isNull);
    expect(current().setById('done').weightKg, 60);
  });

  test('addExercise appends three suggested sets at the next position', () async {
    final old = _session(
      'old',
      [for (var i = 0; i < 3; i++) _s('o$i', idx: i, exercise: 'Bench', done: true, weight: 40, reps: 8, max: 12)],
      finishedAt: DateTime(2026, 9, 20, 11),
    );
    setUpWith([_s('a')], history: [old]);
    await load();

    expect(await notifier().addExercise(_bench), isTrue);

    final groups = current().exerciseGroups;
    expect(groups.length, 2);
    expect(groups.last.length, 3);
    expect(groups.last.first.exercisePosition, 1);
    expect(groups.last.first.exerciseName, 'Bench Press');
    expect(groups.last.first.suggestedWeightKg, 40);
    expect(groups.last.every((s) => s.id != null), isTrue);
  });

  test('removeExercise deletes only pending sets', () async {
    setUpWith([_s('a', done: true, weight: 60, reps: 5), _s('b', idx: 1), _s('c', pos: 1, exercise: 'Bench')]);
    await load();

    expect(await notifier().removeExercise(0), isTrue);

    expect(repo.deletedSetIds, ['b']);
    expect(current().sets.map((s) => s.id), ['a', 'c']);
  });

  test('cancel deletes the session', () async {
    setUpWith([_s('a')]);
    await load();

    await notifier().cancel();

    expect(repo.sessions.containsKey('sess'), isFalse);
  });

  test('finish passes the approved 1RMs', () async {
    setUpWith([_s('a', done: true, weight: 60, reps: 5)]);
    await load();

    await notifier().finish({'Barbell_Squat': 105});

    expect(repo.finished.single.sessionId, 'sess');
    expect(repo.finished.single.oneRepMaxes, {'Barbell_Squat': 105});
  });

  test('finish rethrows repository errors', () async {
    setUpWith([_s('a', done: true, weight: 60, reps: 5)]);
    await load();
    repo.finishError = Exception('offline');

    expect(() => notifier().finish(const {}), throwsException);
  });

  test('finish refreshes the progress data', () async {
    setUpWith([_s('a', done: true, weight: 60, reps: 5)]);
    await load();
    container.listen(recentSessionsProvider, (_, _) {});
    await container.read(recentSessionsProvider.future);
    expect(progressRepo.sessionFetches, 1);

    await notifier().finish(const {});
    await container.read(recentSessionsProvider.future);

    expect(progressRepo.sessionFetches, 2);
  });
}
