import 'package:spor_takip/features/workout/data/exercise_repository.dart';
import 'package:spor_takip/features/workout/data/one_rep_max_repository.dart';
import 'package:spor_takip/features/workout/data/program_repository.dart';
import 'package:spor_takip/features/workout/data/session_repository.dart';
import 'package:spor_takip/features/workout/domain/exercise.dart';
import 'package:spor_takip/features/workout/domain/program.dart';
import 'package:spor_takip/features/workout/domain/workout_session.dart';

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

class FakeSessionRepository implements SessionRepository {
  FakeSessionRepository({List<WorkoutSession>? sessions})
      : sessions = {for (final s in sessions ?? const <WorkoutSession>[]) s.id: s};

  final Map<String, WorkoutSession> sessions;
  Object? updateError;
  Object? finishError;
  final List<SessionSet> updatedSets = [];
  final List<String> deletedSetIds = [];
  final List<({String sessionId, Map<String, double> oneRepMaxes})> finished = [];
  var _counter = 0;

  String _id(String prefix) => '$prefix-${_counter++}';

  List<WorkoutSession> get _finishedNewestFirst =>
      sessions.values.where((s) => !s.isInProgress).toList()
        ..sort((a, b) => b.finishedAt!.compareTo(a.finishedAt!));

  @override
  Future<WorkoutSession?> fetchInProgressSession() async =>
      sessions.values.where((s) => s.isInProgress).firstOrNull;

  @override
  Future<WorkoutSession> fetchSession(String id) async => sessions[id]!;

  @override
  Future<List<WorkoutSession>> fetchHistory() async => _finishedNewestFirst;

  @override
  Future<List<WorkoutSession>> fetchExerciseHistory(Set<String> exerciseIds) async => [
        for (final s in _finishedNewestFirst)
          if (s.sets.any((x) => exerciseIds.contains(x.exerciseId)))
            s.copyWith(sets: [for (final x in s.sets) if (exerciseIds.contains(x.exerciseId)) x]),
      ];

  @override
  Future<String> startSession({
    required String? programId,
    required String programName,
    required String workoutName,
    required int workoutPosition,
    required List<SessionSet> sets,
  }) async {
    if (sessions.values.any((s) => s.isInProgress)) throw ActiveSessionExistsException();
    final id = _id('session');
    sessions[id] = WorkoutSession(
      id: id,
      programId: programId,
      programName: programName,
      workoutName: workoutName,
      workoutPosition: workoutPosition,
      startedAt: DateTime(2026, 9, 26, 10),
      sets: [for (final s in sets) s.copyWith(id: _id('set'))],
    );
    return id;
  }

  @override
  Future<void> updateSet(SessionSet set) async {
    if (updateError != null) throw updateError!;
    updatedSets.add(set);
    final owner = sessions.values.firstWhere((s) => s.sets.any((x) => x.id == set.id));
    sessions[owner.id] = owner.replaceSet(set);
  }

  @override
  Future<List<SessionSet>> addSets(String sessionId, List<SessionSet> sets) async {
    final added = [for (final s in sets) s.copyWith(id: _id('set'))];
    final session = sessions[sessionId]!;
    sessions[sessionId] = session.copyWith(sets: [...session.sets, ...added]);
    return added;
  }

  @override
  Future<void> deleteSets(List<String> setIds) async {
    deletedSetIds.addAll(setIds);
    for (final s in sessions.values.toList()) {
      sessions[s.id] = s.copyWith(sets: [for (final x in s.sets) if (!setIds.contains(x.id)) x]);
    }
  }

  @override
  Future<void> finishSession(String sessionId, Map<String, double> oneRepMaxes) async {
    if (finishError != null) throw finishError!;
    finished.add((sessionId: sessionId, oneRepMaxes: oneRepMaxes));
    sessions[sessionId] = sessions[sessionId]!.copyWith(finishedAt: DateTime(2026, 9, 26, 11));
  }

  @override
  Future<void> deleteSession(String sessionId) async {
    sessions.remove(sessionId);
  }
}
