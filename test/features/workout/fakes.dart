import 'package:spor_takip/features/workout/data/exercise_repository.dart';
import 'package:spor_takip/features/workout/data/one_rep_max_repository.dart';
import 'package:spor_takip/features/workout/data/program_repository.dart';
import 'package:spor_takip/features/workout/domain/exercise.dart';
import 'package:spor_takip/features/workout/domain/program.dart';

class FakeExerciseRepository implements ExerciseRepository {
  FakeExerciseRepository([List<Exercise>? exercises]) : exercises = [...?exercises];

  final List<Exercise> exercises;
  final Set<String> inUseIds = {};
  final List<String> deletedIds = [];

  @override
  Future<List<Exercise>> fetchExercises() async => [...exercises];

  @override
  Future<Exercise> createCustomExercise({
    required String name,
    String? primaryMuscle,
    String? equipment,
  }) async {
    final exercise = Exercise(
      id: 'custom-${exercises.length}',
      userId: 'user-1',
      name: name,
      equipment: equipment,
      primaryMuscles: [?primaryMuscle],
    );
    exercises.add(exercise);
    return exercise;
  }

  @override
  Future<void> deleteCustomExercise(String id) async {
    if (inUseIds.contains(id)) throw ExerciseInUseException();
    deletedIds.add(id);
    exercises.removeWhere((e) => e.id == id);
  }
}

class FakeProgramRepository implements ProgramRepository {
  FakeProgramRepository({List<Program>? programs, this.active = const ActiveProgramState()})
      : programs = {for (final p in programs ?? const <Program>[]) p.id!: p};

  final Map<String, Program> programs;
  ActiveProgramState active;
  Object? saveError;
  final List<Program> savedPrograms = [];
  final List<String> copiedIds = [];
  final List<String> deletedIds = [];

  @override
  Future<List<Program>> fetchPrograms() async => programs.values.toList();

  @override
  Future<Program> fetchProgram(String id) async => programs[id]!;

  @override
  Future<String> copyProgram(String sourceId) async {
    copiedIds.add(sourceId);
    final newId = 'copy-of-$sourceId';
    final source = programs[sourceId]!;
    programs[newId] = Program(
      id: newId,
      userId: 'user-1',
      name: source.name,
      scheduleMode: source.scheduleMode,
      sourceProgramId: sourceId,
      workouts: source.workouts,
    );
    return newId;
  }

  @override
  Future<String> saveProgram(Program program) async {
    if (saveError != null) throw saveError!;
    savedPrograms.add(program);
    final id = program.id ?? 'new-${savedPrograms.length}';
    programs[id] = program.copyWith(id: id);
    return id;
  }

  @override
  Future<void> deleteProgram(String id) async {
    deletedIds.add(id);
    programs.remove(id);
    if (active.programId == id) active = const ActiveProgramState();
  }

  @override
  Future<ActiveProgramState> fetchActiveProgramState() async => active;

  @override
  Future<void> setActiveProgram(String? programId) async {
    active = ActiveProgramState(programId: programId);
  }

  @override
  Future<void> setRotationPosition(int position) async {
    active = ActiveProgramState(programId: active.programId, nextRotationPosition: position);
  }
}

class FakeOneRepMaxRepository implements OneRepMaxRepository {
  final Map<String, double> values = {};

  @override
  Future<Map<String, double>> fetchOneRepMaxes() async => {...values};

  @override
  Future<void> saveOneRepMax({required String exerciseId, required double weightKg}) async {
    values[exerciseId] = weightKg;
  }
}
