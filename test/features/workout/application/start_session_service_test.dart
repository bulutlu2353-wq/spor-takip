import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spor_takip/features/onboarding/application/auth_providers.dart';
import 'package:spor_takip/features/workout/application/session_providers.dart';
import 'package:spor_takip/features/workout/application/start_session_service.dart';
import 'package:spor_takip/features/workout/application/workout_providers.dart';
import 'package:spor_takip/features/workout/data/session_repository.dart';
import 'package:spor_takip/features/workout/domain/exercise.dart';
import 'package:spor_takip/features/workout/domain/program.dart';
import 'package:spor_takip/features/workout/domain/program_workout.dart';
import 'package:spor_takip/features/workout/domain/schedule_mode.dart';
import 'package:spor_takip/features/workout/domain/workout_exercise.dart';
import 'package:spor_takip/features/workout/domain/workout_session.dart';

import '../fakes.dart';

const _squat = Exercise(
    id: 'Barbell_Squat', name: 'Barbell Squat', equipment: 'barbell', primaryMuscles: ['quadriceps']);
const _bench = Exercise(id: 'Bench', name: 'Bench Press', equipment: 'barbell', primaryMuscles: ['chest']);

const _program = Program(
  id: 'sl',
  name: 'StrongLifts 5x5',
  scheduleMode: ScheduleMode.rotation,
  workouts: [
    ProgramWorkout(name: 'A', exercises: [
      WorkoutExercise(
          exerciseId: 'Barbell_Squat', exerciseName: 'Barbell Squat', sets: 3, repsMin: 5, repsMax: 5, restSeconds: 180),
      WorkoutExercise(
          exerciseId: 'Bench', exerciseName: 'Bench Press', sets: 1, repsMin: 5, repsMax: 5, isAmrap: true, percent1rm: 75),
    ]),
  ],
);

SessionSet _done(String id, int index) => SessionSet(
      id: id,
      exercisePosition: 0,
      setIndex: index,
      exerciseId: 'Barbell_Squat',
      exerciseName: 'Barbell Squat',
      targetRepsMin: 5,
      targetRepsMax: 5,
      weightKg: 60,
      reps: 5,
      completedAt: DateTime(2026, 9, 20, 10, 30),
    );

final _old = WorkoutSession(
  id: 'old',
  programId: 'sl',
  programName: 'StrongLifts 5x5',
  workoutName: 'A',
  workoutPosition: 0,
  startedAt: DateTime(2026, 9, 20, 10),
  finishedAt: DateTime(2026, 9, 20, 11),
  sets: [_done('o1', 0), _done('o2', 1), _done('o3', 2)],
);

void main() {
  late FakeSessionRepository repo;
  late ProviderContainer container;

  setUp(() {
    repo = FakeSessionRepository(sessions: [_old]);
    container = ProviderContainer(overrides: [
      isLoggedInProvider.overrideWithValue(true),
      sessionRepositoryProvider.overrideWithValue(repo),
      exerciseRepositoryProvider.overrideWithValue(FakeExerciseRepository([_squat, _bench])),
      oneRepMaxRepositoryProvider.overrideWithValue(FakeOneRepMaxRepository()..values['Bench'] = 100),
    ]);
    container.listen(inProgressSessionProvider, (_, _) {});
  });

  tearDown(() => container.dispose());

  test('start writes the session with suggested weights and refreshes the in-progress session', () async {
    expect(await container.read(inProgressSessionProvider.future), isNull);

    final id = await container.read(startSessionServiceProvider).start(_program, 0);

    final session = repo.sessions[id]!;
    expect(session.programId, 'sl');
    expect(session.programName, 'StrongLifts 5x5');
    expect(session.workoutName, 'A');
    expect(session.workoutPosition, 0);
    expect(session.sets.length, 4);
    expect(session.sets.take(3).map((s) => s.suggestedWeightKg), [65, 65, 65]);
    expect(session.sets.last.suggestedWeightKg, 75);
    expect(session.sets.last.isAmrap, isTrue);
    expect((await container.read(inProgressSessionProvider.future))!.id, id);
  });

  test('start rethrows when a session is already in progress', () async {
    await container.read(startSessionServiceProvider).start(_program, 0);
    expect(
      () => container.read(startSessionServiceProvider).start(_program, 0),
      throwsA(isA<ActiveSessionExistsException>()),
    );
  });

  test('sets for an added exercise use its own history', () async {
    final sets = await container.read(startSessionServiceProvider).setsForAddedExercise(_squat, 3);
    expect(sets.length, 3);
    expect(sets.first.exercisePosition, 3);
    expect(sets.first.targetRepsMax, 12);
    // başarı, geçmiş setlerin kendi hedefine (5) göre ölçülür → 60 + 5
    expect(sets.first.suggestedWeightKg, 65);
  });
}
