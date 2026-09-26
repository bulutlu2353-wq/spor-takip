import 'dart:math' as math;

DateTime? _parseTime(Object? value) => value == null ? null : DateTime.parse(value as String);

/// Bir antrenman oturumundaki tek set: planın kopyası (hedef, yüzde, öneri)
/// ve gerçekte yapılan (kilo, tekrar, tamamlanma).
class SessionSet {
  const SessionSet({
    required this.exercisePosition,
    required this.setIndex,
    required this.exerciseId,
    required this.exerciseName,
    required this.targetRepsMin,
    required this.targetRepsMax,
    this.id,
    this.isAmrap = false,
    this.percent1rm,
    this.percentRefExerciseId,
    this.restSeconds,
    this.suggestedWeightKg,
    this.deloaded = false,
    this.weightKg,
    this.reps,
    this.completedAt,
  });

  /// Sunucuya yazılmadan önce null.
  final String? id;
  final int exercisePosition;
  final int setIndex;
  final String exerciseId;
  final String exerciseName;
  final int targetRepsMin;
  final int targetRepsMax;
  final bool isAmrap;
  final double? percent1rm;
  final String? percentRefExerciseId;
  final int? restSeconds;
  final double? suggestedWeightKg;

  /// Öneri, 3 başarısız oturum sonrası %10 düşürüldü.
  final bool deloaded;
  final double? weightKg;
  final int? reps;

  /// null = henüz yapılmadı.
  final DateTime? completedAt;

  bool get isCompleted => completedAt != null;

  /// Yüzdenin dayandığı 1RM'nin hareketi (nSuns T2: Sumo Deadlift → Deadlift).
  String get oneRepMaxExerciseId => percentRefExerciseId ?? exerciseId;

  /// Hedefe ulaşıldı mı: normal sette üst sınır, AMRAP setinde alt sınır.
  bool get hitTarget => isCompleted && (reps ?? 0) >= (isAmrap ? targetRepsMin : targetRepsMax);

  /// Kilo kutusunda gösterilecek değer: girilen, yoksa önerilen.
  double? get displayWeightKg => weightKg ?? suggestedWeightKg;

  /// Tekrar kutusunda gösterilecek değer: girilen, yoksa (AMRAP değilse) hedefin üst sınırı.
  int? get displayReps => reps ?? (isAmrap ? null : targetRepsMax);

  factory SessionSet.fromJson(Map<String, dynamic> json) {
    final exercise = json['exercises'] as Map<String, dynamic>?;
    return SessionSet(
      id: json['id'] as String?,
      exercisePosition: json['exercise_position'] as int,
      setIndex: json['set_index'] as int,
      exerciseId: json['exercise_id'] as String,
      exerciseName: exercise?['name'] as String? ?? json['exercise_id'] as String,
      targetRepsMin: json['target_reps_min'] as int,
      targetRepsMax: json['target_reps_max'] as int,
      isAmrap: json['is_amrap'] as bool? ?? false,
      percent1rm: (json['percent_1rm'] as num?)?.toDouble(),
      percentRefExerciseId: json['percent_ref_exercise_id'] as String?,
      restSeconds: json['rest_seconds'] as int?,
      suggestedWeightKg: (json['suggested_weight_kg'] as num?)?.toDouble(),
      deloaded: json['deloaded'] as bool? ?? false,
      weightKg: (json['weight_kg'] as num?)?.toDouble(),
      reps: json['reps'] as int?,
      completedAt: _parseTime(json['completed_at']),
    );
  }

  /// `start_session` payload'ındaki ve `session_sets` insert'indeki şekil
  /// (oturum id'si ve sonuçlar hariç).
  Map<String, dynamic> toInsertJson() {
    return {
      'exercise_position': exercisePosition,
      'set_index': setIndex,
      'exercise_id': exerciseId,
      'target_reps_min': targetRepsMin,
      'target_reps_max': targetRepsMax,
      'is_amrap': isAmrap,
      'percent_1rm': percent1rm,
      'percent_ref_exercise_id': percentRefExerciseId,
      'rest_seconds': restSeconds,
      'suggested_weight_kg': suggestedWeightKg,
      'deloaded': deloaded,
    };
  }

  SessionSet copyWith({
    String? id,
    double? weightKg,
    bool clearWeight = false,
    int? reps,
    bool clearReps = false,
    DateTime? completedAt,
    bool clearCompletedAt = false,
  }) {
    return SessionSet(
      id: id ?? this.id,
      exercisePosition: exercisePosition,
      setIndex: setIndex,
      exerciseId: exerciseId,
      exerciseName: exerciseName,
      targetRepsMin: targetRepsMin,
      targetRepsMax: targetRepsMax,
      isAmrap: isAmrap,
      percent1rm: percent1rm,
      percentRefExerciseId: percentRefExerciseId,
      restSeconds: restSeconds,
      suggestedWeightKg: suggestedWeightKg,
      deloaded: deloaded,
      weightKg: clearWeight ? null : (weightKg ?? this.weightKg),
      reps: clearReps ? null : (reps ?? this.reps),
      completedAt: clearCompletedAt ? null : (completedAt ?? this.completedAt),
    );
  }
}

class WorkoutSession {
  const WorkoutSession({
    required this.id,
    required this.programName,
    required this.workoutName,
    required this.workoutPosition,
    required this.startedAt,
    this.programId,
    this.finishedAt,
    this.sets = const [],
  });

  final String id;

  /// Program silinmişse null.
  final String? programId;
  final String programName;
  final String workoutName;
  final int workoutPosition;
  final DateTime startedAt;

  /// null = devam ediyor.
  final DateTime? finishedAt;

  /// `exercisePosition`, `setIndex` sırasıyla.
  final List<SessionSet> sets;

  bool get isInProgress => finishedAt == null;

  /// Aynı `exercisePosition`'lı ardışık setler (ekrandaki hareket kartları).
  List<List<SessionSet>> get exerciseGroups {
    final groups = <List<SessionSet>>[];
    for (final set in sets) {
      if (groups.isNotEmpty && groups.last.first.exercisePosition == set.exercisePosition) {
        groups.last.add(set);
      } else {
        groups.add([set]);
      }
    }
    return groups;
  }

  /// Yeni eklenecek hareketin sırası.
  int get nextExercisePosition =>
      sets.isEmpty ? 0 : sets.map((s) => s.exercisePosition).reduce(math.max) + 1;

  SessionSet setById(String id) => sets.firstWhere((s) => s.id == id);

  WorkoutSession replaceSet(SessionSet updated) =>
      copyWith(sets: [for (final s in sets) s.id == updated.id ? updated : s]);

  WorkoutSession copyWith({DateTime? finishedAt, List<SessionSet>? sets}) {
    return WorkoutSession(
      id: id,
      programId: programId,
      programName: programName,
      workoutName: workoutName,
      workoutPosition: workoutPosition,
      startedAt: startedAt,
      finishedAt: finishedAt ?? this.finishedAt,
      sets: sets ?? this.sets,
    );
  }

  factory WorkoutSession.fromJson(Map<String, dynamic> json) {
    final sets = [
      for (final row in json['session_sets'] as List? ?? const [])
        SessionSet.fromJson(row as Map<String, dynamic>),
    ]..sort((a, b) {
        final byExercise = a.exercisePosition.compareTo(b.exercisePosition);
        return byExercise != 0 ? byExercise : a.setIndex.compareTo(b.setIndex);
      });
    return WorkoutSession(
      id: json['id'] as String,
      programId: json['program_id'] as String?,
      programName: json['program_name'] as String,
      workoutName: json['workout_name'] as String,
      workoutPosition: json['workout_position'] as int,
      startedAt: DateTime.parse(json['started_at'] as String),
      finishedAt: _parseTime(json['finished_at']),
      sets: sets,
    );
  }
}
