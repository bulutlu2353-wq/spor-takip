import 'workout_exercise.dart';

class ProgramWorkout {
  const ProgramWorkout({required this.name, required this.exercises, this.weekday});

  final String name;

  /// ISO hafta günü (1=Pzt … 7=Paz); yalnızca weekdays modunda dolu.
  final int? weekday;
  final List<WorkoutExercise> exercises;

  factory ProgramWorkout.fromJson(Map<String, dynamic> json) {
    final rows = [...(json['workout_exercises'] as List? ?? const [])]
        .cast<Map<String, dynamic>>()
      ..sort((a, b) => (a['position'] as int).compareTo(b['position'] as int));
    return ProgramWorkout(
      name: json['name'] as String,
      weekday: json['weekday'] as int?,
      exercises: rows.map(WorkoutExercise.fromJson).toList(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'weekday': weekday,
      'exercises': exercises.map((e) => e.toJson()).toList(),
    };
  }

  ProgramWorkout copyWith({
    String? name,
    int? weekday,
    bool clearWeekday = false,
    List<WorkoutExercise>? exercises,
  }) {
    return ProgramWorkout(
      name: name ?? this.name,
      weekday: clearWeekday ? null : (weekday ?? this.weekday),
      exercises: exercises ?? this.exercises,
    );
  }
}
