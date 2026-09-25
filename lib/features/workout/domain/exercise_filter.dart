import 'exercise.dart';

List<Exercise> filterExercises(
  List<Exercise> all, {
  String query = '',
  String? muscle,
  String? equipment,
}) {
  final q = query.trim().toLowerCase();
  return all
      .where((e) => q.isEmpty || e.name.toLowerCase().contains(q))
      .where((e) => muscle == null || e.primaryMuscles.contains(muscle))
      .where((e) => equipment == null || e.equipment == equipment)
      .toList();
}
