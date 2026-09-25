import 'package:flutter_test/flutter_test.dart';
import 'package:spor_takip/features/workout/domain/exercise.dart';
import 'package:spor_takip/features/workout/domain/exercise_filter.dart';
import 'package:spor_takip/features/workout/domain/exercise_taxonomy.dart';

const _all = [
  Exercise(id: 'sq', name: 'Barbell Squat', equipment: 'barbell', primaryMuscles: ['quadriceps']),
  Exercise(id: 'bp', name: 'Barbell Bench Press', equipment: 'barbell', primaryMuscles: ['chest']),
  Exercise(id: 'pu', name: 'Pushups', equipment: 'body only', primaryMuscles: ['chest']),
];

void main() {
  test('query matches name case-insensitively', () {
    expect(filterExercises(_all, query: 'bench').map((e) => e.id), ['bp']);
    expect(filterExercises(_all, query: '  BARBELL ').map((e) => e.id), ['sq', 'bp']);
  });

  test('muscle and equipment filters combine', () {
    expect(filterExercises(_all, muscle: 'chest').map((e) => e.id), ['bp', 'pu']);
    expect(filterExercises(_all, muscle: 'chest', equipment: 'body only').map((e) => e.id), ['pu']);
  });

  test('taxonomy lists and label keys', () {
    expect(muscleGroups, hasLength(17));
    expect(equipmentTypes, hasLength(12));
    expect(muscleLabelKey('lower back'), 'workout.muscle.lower_back');
    expect(equipmentLabelKey('e-z curl bar'), 'workout.equipment.e_z_curl_bar');
  });
}
