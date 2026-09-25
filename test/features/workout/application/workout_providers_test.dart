import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spor_takip/features/onboarding/application/auth_providers.dart';
import 'package:spor_takip/features/workout/application/workout_providers.dart';
import 'package:spor_takip/features/workout/data/program_repository.dart';
import 'package:spor_takip/features/workout/domain/program.dart';
import 'package:spor_takip/features/workout/domain/program_workout.dart';
import 'package:spor_takip/features/workout/domain/schedule_mode.dart';
import 'package:spor_takip/features/workout/domain/today_workout.dart';

import '../fakes.dart';

const _rotation = Program(
  id: 'p1',
  userId: 'user-1',
  name: 'Rotation',
  scheduleMode: ScheduleMode.rotation,
  workouts: [
    ProgramWorkout(name: 'A', exercises: []),
    ProgramWorkout(name: 'B', exercises: []),
  ],
);

void main() {
  ProviderContainer containerWith(FakeProgramRepository repo, {bool loggedIn = true}) {
    final container = ProviderContainer(overrides: [
      isLoggedInProvider.overrideWithValue(loggedIn),
      programRepositoryProvider.overrideWithValue(repo),
    ]);
    addTearDown(container.dispose);
    return container;
  }

  test('todayWorkoutProvider resolves the active rotation program at its next position', () async {
    final repo = FakeProgramRepository(
      programs: [_rotation],
      active: const ActiveProgramState(programId: 'p1', nextRotationPosition: 1),
    );
    final today = await containerWith(repo).read(todayWorkoutProvider.future);
    expect(today, isA<ScheduledWorkout>());
    expect((today as ScheduledWorkout).workout.name, 'B');
  });

  test('todayWorkoutProvider is NoActiveProgram without an active program', () async {
    final today = await containerWith(FakeProgramRepository()).read(todayWorkoutProvider.future);
    expect(today, isA<NoActiveProgram>());
  });

  test('providers return empty data when logged out (no Supabase calls)', () async {
    final container = containerWith(FakeProgramRepository(programs: [_rotation]), loggedIn: false);
    expect(await container.read(programsProvider.future), isEmpty);
    expect(await container.read(todayWorkoutProvider.future), isA<NoActiveProgram>());
  });
}
