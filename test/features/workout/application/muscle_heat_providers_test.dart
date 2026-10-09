import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spor_takip/features/onboarding/application/auth_providers.dart';
import 'package:spor_takip/features/workout/application/muscle_heat_providers.dart';
import 'package:spor_takip/features/workout/application/session_providers.dart';
import 'package:spor_takip/features/workout/application/workout_providers.dart';

import '../fakes.dart';
import '../heat_fixtures.dart';

ProviderContainer _container() {
  final container = ProviderContainer(overrides: [
    isLoggedInProvider.overrideWithValue(true),
    nowProvider.overrideWithValue(() => heatNow),
    sessionRepositoryProvider.overrideWithValue(FakeSessionRepository(sessions: heatSessions)),
    exerciseRepositoryProvider.overrideWithValue(FakeExerciseRepository(heatExercises)),
    programRepositoryProvider.overrideWithValue(FakeProgramRepository(programs: [heatProgram])),
  ]);
  addTearDown(container.dispose);
  return container;
}

void main() {
  test('history heat counts the last N days from now', () async {
    final container = _container();
    container.listen(historyHeatProvider(7), (_, _) {});
    container.listen(historyHeatProvider(30), (_, _) {});

    final week = await container.read(historyHeatProvider(7).future);
    expect(week.load, {'chest': 5.0, 'triceps': 1.5});
    expect(week.since, heatNow.subtract(const Duration(days: 7)));
    expect(week.exercisesById.keys, containsAll(['bench', 'squat']));

    final month = await container.read(historyHeatProvider(30).future);
    expect(month.load['quadriceps'], 4.0);
  });

  test('program heat sums the planned sets', () async {
    final container = _container();
    container.listen(programHeatProvider('prog'), (_, _) {});

    final heat = await container.read(programHeatProvider('prog').future);
    expect(heat.program.name, '5x5');
    expect(heat.load, {'chest': 6.5, 'triceps': 5.5, 'quadriceps': 5.0});
  });

  test('exercises are indexed by id', () async {
    final container = _container();
    container.listen(exercisesByIdProvider, (_, _) {});

    final byId = await container.read(exercisesByIdProvider.future);
    expect(byId['dips']?.name, 'Dips');
  });
}
