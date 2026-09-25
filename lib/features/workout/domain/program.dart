import 'program_level.dart';
import 'program_workout.dart';
import 'schedule_mode.dart';

class Program {
  const Program({
    required this.name,
    required this.scheduleMode,
    required this.workouts,
    this.id,
    this.userId,
    this.description,
    this.level,
    this.daysPerWeek,
    this.sourceProgramId,
  });

  /// Henüz kaydedilmemiş (yeni) programda null.
  final String? id;

  /// Hazır programlarda null.
  final String? userId;
  final String name;
  final String? description;
  final ProgramLevel? level;
  final ScheduleMode scheduleMode;
  final int? daysPerWeek;
  final String? sourceProgramId;
  final List<ProgramWorkout> workouts;

  bool get isBuiltIn => userId == null;

  int? get effectiveDaysPerWeek =>
      daysPerWeek ?? (scheduleMode == ScheduleMode.weekdays ? workouts.length : null);

  bool get usesPercentages =>
      workouts.any((w) => w.exercises.any((e) => e.percent1rm != null));

  /// Kilo hesabı için 1RM'si gereken hareketler.
  Set<String> get oneRepMaxExerciseIds => {
        for (final w in workouts)
          for (final e in w.exercises)
            if (e.percent1rm != null) e.oneRepMaxExerciseId,
      };

  factory Program.fromJson(Map<String, dynamic> json) {
    final rows = [...(json['program_workouts'] as List? ?? const [])]
        .cast<Map<String, dynamic>>()
      ..sort((a, b) => (a['position'] as int).compareTo(b['position'] as int));
    return Program(
      id: json['id'] as String?,
      userId: json['user_id'] as String?,
      name: json['name'] as String,
      description: json['description'] as String?,
      level: programLevelFromDb(json['level'] as String?),
      scheduleMode: scheduleModeFromDb(json['schedule_mode'] as String),
      daysPerWeek: json['days_per_week'] as int?,
      sourceProgramId: json['source_program_id'] as String?,
      workouts: rows.map(ProgramWorkout.fromJson).toList(),
    );
  }

  /// `save_program(payload jsonb)` RPC'sinin beklediği şekil.
  Map<String, dynamic> toSavePayload() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'level': programLevelToDb(level),
      'schedule_mode': scheduleModeToDb(scheduleMode),
      'days_per_week': daysPerWeek,
      'source_program_id': sourceProgramId,
      'workouts': workouts.map((w) => w.toJson()).toList(),
    };
  }

  Program copyWith({
    String? id,
    String? name,
    String? description,
    ScheduleMode? scheduleMode,
    List<ProgramWorkout>? workouts,
  }) {
    return Program(
      id: id ?? this.id,
      userId: userId,
      name: name ?? this.name,
      description: description ?? this.description,
      level: level,
      scheduleMode: scheduleMode ?? this.scheduleMode,
      daysPerWeek: daysPerWeek,
      sourceProgramId: sourceProgramId,
      workouts: workouts ?? this.workouts,
    );
  }
}
