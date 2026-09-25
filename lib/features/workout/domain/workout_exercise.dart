/// Bir antrenmandaki *özdeş setlerden oluşan bir blok*. Setleri farklı
/// yüzde/tekrarla yapılan hareketler (5/3/1, nSuns) art arda birden fazla blok olur.
class WorkoutExercise {
  const WorkoutExercise({
    required this.exerciseId,
    required this.exerciseName,
    required this.sets,
    required this.repsMin,
    required this.repsMax,
    this.isAmrap = false,
    this.percent1rm,
    this.percentRefExerciseId,
    this.restSeconds,
    this.notes,
  });

  final String exerciseId;
  final String exerciseName;
  final int sets;
  final int repsMin;
  final int repsMax;
  final bool isAmrap;
  final double? percent1rm;
  final String? percentRefExerciseId;
  final int? restSeconds;
  final String? notes;

  /// Yüzdenin dayandığı 1RM'nin hareketi (nSuns T2: Sumo Deadlift → Deadlift).
  String get oneRepMaxExerciseId => percentRefExerciseId ?? exerciseId;

  factory WorkoutExercise.fromJson(Map<String, dynamic> json) {
    final exercise = json['exercises'] as Map<String, dynamic>?;
    return WorkoutExercise(
      exerciseId: json['exercise_id'] as String,
      exerciseName: exercise?['name'] as String? ?? json['exercise_id'] as String,
      sets: json['sets'] as int,
      repsMin: json['reps_min'] as int,
      repsMax: json['reps_max'] as int,
      isAmrap: json['is_amrap'] as bool? ?? false,
      percent1rm: (json['percent_1rm'] as num?)?.toDouble(),
      percentRefExerciseId: json['percent_ref_exercise_id'] as String?,
      restSeconds: json['rest_seconds'] as int?,
      notes: json['notes'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'exercise_id': exerciseId,
      'sets': sets,
      'reps_min': repsMin,
      'reps_max': repsMax,
      'is_amrap': isAmrap,
      'percent_1rm': percent1rm,
      'percent_ref_exercise_id': percentRefExerciseId,
      'rest_seconds': restSeconds,
      'notes': notes,
    };
  }

  WorkoutExercise copyWith({
    String? exerciseId,
    String? exerciseName,
    int? sets,
    int? repsMin,
    int? repsMax,
    bool? isAmrap,
    double? percent1rm,
    bool clearPercent1rm = false,
    int? restSeconds,
    bool clearRestSeconds = false,
    String? notes,
    bool clearNotes = false,
  }) {
    return WorkoutExercise(
      exerciseId: exerciseId ?? this.exerciseId,
      exerciseName: exerciseName ?? this.exerciseName,
      sets: sets ?? this.sets,
      repsMin: repsMin ?? this.repsMin,
      repsMax: repsMax ?? this.repsMax,
      isAmrap: isAmrap ?? this.isAmrap,
      percent1rm: clearPercent1rm ? null : (percent1rm ?? this.percent1rm),
      percentRefExerciseId: percentRefExerciseId,
      restSeconds: clearRestSeconds ? null : (restSeconds ?? this.restSeconds),
      notes: clearNotes ? null : (notes ?? this.notes),
    );
  }
}
