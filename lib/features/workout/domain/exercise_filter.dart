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

/// [muscle]'ı birincil çalıştıranlar (ada göre); [includeSecondary] ise ardından
/// yalnız ikincil çalıştıranlar (ada göre).
List<Exercise> exercisesForMuscle(List<Exercise> all, String muscle, {bool includeSecondary = false}) {
  int byName(Exercise a, Exercise b) => a.name.toLowerCase().compareTo(b.name.toLowerCase());
  final primary = all.where((e) => e.primaryMuscles.contains(muscle)).toList()..sort(byName);
  if (!includeSecondary) return primary;
  final secondary = all
      .where((e) => !e.primaryMuscles.contains(muscle) && e.secondaryMuscles.contains(muscle))
      .toList()
    ..sort(byName);
  return [...primary, ...secondary];
}
