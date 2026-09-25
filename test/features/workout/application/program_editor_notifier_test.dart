import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spor_takip/features/onboarding/application/auth_providers.dart';
import 'package:spor_takip/features/workout/application/program_editor_notifier.dart';
import 'package:spor_takip/features/workout/application/program_editor_state.dart';
import 'package:spor_takip/features/workout/application/workout_providers.dart';
import 'package:spor_takip/features/workout/domain/exercise.dart';
import 'package:spor_takip/features/workout/domain/program.dart';
import 'package:spor_takip/features/workout/domain/program_workout.dart';
import 'package:spor_takip/features/workout/domain/schedule_mode.dart';

import '../fakes.dart';

const _squat = Exercise(id: 'Barbell_Squat', name: 'Barbell Squat');
const _bench = Exercise(id: 'Bench', name: 'Bench');

void main() {
  late FakeProgramRepository repo;
  late ProviderContainer container;

  ProgramEditorNotifier notifier() => container.read(programEditorProvider.notifier);
  ProgramEditorState state() => container.read(programEditorProvider);

  setUp(() {
    repo = FakeProgramRepository();
    container = ProviderContainer(overrides: [
      isLoggedInProvider.overrideWithValue(true),
      programRepositoryProvider.overrideWithValue(repo),
    ]);
    // autoDispose provider'ı test boyunca canlı tut.
    container.listen(programEditorProvider, (_, _) {});
  });

  tearDown(() => container.dispose());

  test('startBlank creates an empty weekdays draft that is not dirty', () {
    notifier().startBlank();
    expect(state().draft!.name, '');
    expect(state().draft!.scheduleMode, ScheduleMode.weekdays);
    expect(state().dirty, isFalse);
    expect(state().validationError, EditorValidationError.emptyName);
  });

  test('edits mark the draft dirty and validation follows the draft', () {
    notifier()
      ..startBlank()
      ..rename('Benim programım')
      ..addWorkout('Gün 1');
    expect(state().dirty, isTrue);
    expect(state().validationError, EditorValidationError.missingWeekday);

    expect(notifier().setWeekday(0, 1), isTrue);
    expect(state().validationError, isNull);

    notifier().renameWorkout(0, '  ');
    expect(state().validationError, EditorValidationError.emptyWorkoutName);
  });

  test('setWeekday rejects a day already used by another workout', () {
    notifier()
      ..startBlank()
      ..addWorkout('A')
      ..addWorkout('B');
    expect(notifier().setWeekday(0, 3), isTrue);
    expect(notifier().setWeekday(1, 3), isFalse);
    expect(state().draft!.workouts[1].weekday, isNull);
    expect(notifier().setWeekday(0, 3), isTrue, reason: 'same workout may keep its own day');
  });

  test('switching to rotation clears weekdays', () {
    notifier()
      ..startBlank()
      ..addWorkout('A');
    notifier().setWeekday(0, 2);
    notifier().setScheduleMode(ScheduleMode.rotation);
    expect(state().draft!.workouts.single.weekday, isNull);
    expect(state().validationError, EditorValidationError.emptyName);
  });

  test('blocks can be added with defaults, updated, moved and removed', () {
    notifier()
      ..startBlank()
      ..addWorkout('A')
      ..addBlock(0, _squat)
      ..addBlock(0, _bench);
    final first = state().draft!.workouts[0].exercises.first;
    expect(first.exerciseId, 'Barbell_Squat');
    expect([first.sets, first.repsMin, first.repsMax, first.restSeconds], [3, 8, 12, 90]);

    notifier().updateBlock(0, 0, first.copyWith(sets: 5, repsMin: 5, repsMax: 5));
    expect(state().draft!.workouts[0].exercises.first.sets, 5);

    notifier().moveBlock(0, 1, 0);
    expect(state().draft!.workouts[0].exercises.map((b) => b.exerciseId), ['Bench', 'Barbell_Squat']);

    notifier().removeBlock(0, 0);
    expect(state().draft!.workouts[0].exercises.map((b) => b.exerciseId), ['Barbell_Squat']);
  });

  test('workouts can be moved and removed', () {
    notifier()
      ..startBlank()
      ..addWorkout('A')
      ..addWorkout('B')
      ..addWorkout('C')
      ..moveWorkout(2, 0);
    expect(state().draft!.workouts.map((w) => w.name), ['C', 'A', 'B']);
    notifier().removeWorkout(1);
    expect(state().draft!.workouts.map((w) => w.name), ['C', 'B']);
  });

  test('save writes the draft, returns the id and clears dirty', () async {
    notifier()
      ..startBlank()
      ..rename('Mine')
      ..setScheduleMode(ScheduleMode.rotation)
      ..addWorkout('A')
      ..addBlock(0, _squat);

    final id = await notifier().save();

    expect(id, 'new-1');
    expect(repo.savedPrograms.single.name, 'Mine');
    expect(state().draft!.id, 'new-1');
    expect(state().dirty, isFalse);
    expect(state().saving, isFalse);
  });

  test('save refuses an invalid draft without calling the repository', () async {
    notifier().startBlank();
    expect(await notifier().save(), isNull);
    expect(repo.savedPrograms, isEmpty);
  });

  test('failed save keeps the draft and flags the failure', () async {
    repo.saveError = Exception('network');
    notifier().start(const Program(
      id: 'p1',
      userId: 'user-1',
      name: 'Mine',
      scheduleMode: ScheduleMode.rotation,
      workouts: [ProgramWorkout(name: 'A', exercises: [])],
    ));
    notifier().rename('Mine v2');

    expect(await notifier().save(), isNull);
    expect(state().saveFailed, isTrue);
    expect(state().dirty, isTrue);
    expect(state().draft!.name, 'Mine v2');
  });
}
