import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spor_takip/core/router.dart';
import 'package:spor_takip/features/onboarding/application/auth_providers.dart';
import 'package:spor_takip/features/onboarding/application/profile_providers.dart';
import 'package:spor_takip/features/onboarding/domain/profile.dart';

import '../features/progress/fixtures.dart';

Profile _withWeight(double kg) => Profile(
      userId: testProfile.userId,
      weightKg: kg,
      heightCm: testProfile.heightCm,
      birthYear: testProfile.birthYear,
      gender: testProfile.gender,
      activityLevel: testProfile.activityLevel,
      doesExercise: testProfile.doesExercise,
      exerciseDaysPerWeek: testProfile.exerciseDaysPerWeek,
      goal: testProfile.goal,
      dailyCalorieTarget: testProfile.dailyCalorieTarget,
      dailyProteinTargetG: testProfile.dailyProteinTargetG,
    );

void main() {
  // GoRouter, WidgetsBinding'e dokunur.
  TestWidgetsFlutterBinding.ensureInitialized();

  test('refreshing profile data keeps the same router (no navigation reset)', () async {
    var weight = 80.0;
    final container = ProviderContainer(overrides: [
      isLoggedInProvider.overrideWithValue(true),
      profileProvider.overrideWith((ref) async => _withWeight(weight)),
    ]);
    addTearDown(container.dispose);

    await container.read(profileProvider.future);
    final first = container.read(routerProvider);

    weight = 81;
    container.invalidate(profileProvider);
    await container.read(profileProvider.future);

    expect(identical(container.read(routerProvider), first), isTrue);
  });
}
