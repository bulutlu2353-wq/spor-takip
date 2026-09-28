import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spor_takip/features/onboarding/application/auth_providers.dart';
import 'package:spor_takip/features/onboarding/application/profile_providers.dart';
import 'package:spor_takip/features/progress/application/body_weight_service.dart';
import 'package:spor_takip/features/progress/application/progress_providers.dart';
import 'package:spor_takip/features/progress/data/body_weight_repository.dart';
import 'package:spor_takip/features/progress/domain/body_weight_log.dart';
import 'package:spor_takip/features/progress/domain/profile_weight_update.dart';
import 'package:spor_takip/features/workout/application/session_providers.dart';

import '../fakes.dart';
import '../fixtures.dart';

final _now = DateTime(2026, 9, 28, 12);

void main() {
  late FakeBodyWeightRepository repo;
  late ProviderContainer container;

  setUp(() {
    repo = FakeBodyWeightRepository([
      BodyWeightLog(date: DateTime(2026, 9, 10), weightKg: 81),
      BodyWeightLog(date: DateTime(2026, 9, 20), weightKg: 80),
    ]);
    container = ProviderContainer(overrides: [
      isLoggedInProvider.overrideWithValue(true),
      profileProvider.overrideWith((ref) async => testProfile),
      bodyWeightRepositoryProvider.overrideWithValue(repo),
      nowProvider.overrideWithValue(() => _now),
    ]);
    addTearDown(container.dispose);
  });

  BodyWeightService service() => container.read(bodyWeightServiceProvider);

  ProfileWeightUpdate expectedFor(double kg) => profileWeightUpdate(testProfile, kg, currentYear: 2026);

  test('logging the newest entry sends new targets and returns the calorie target', () async {
    final target = await service().log(date: DateTime(2026, 9, 28, 9, 30), weightKg: 79.5);

    final call = repo.logged.single;
    expect(call.date, DateTime(2026, 9, 28)); // saat atılır
    expect(call.update.weightKg, 79.5);
    expect(call.update.calorieTarget, expectedFor(79.5).calorieTarget);
    expect(call.update.proteinTargetG, expectedFor(79.5).proteinTargetG);
    expect(target, expectedFor(79.5).calorieTarget);
  });

  test('overwriting the newest day still counts as newest', () async {
    final target = await service().log(date: DateTime(2026, 9, 20), weightKg: 79);
    expect(target, isNotNull);
  });

  test('a past-dated entry does not change targets (returns null)', () async {
    final target = await service().log(date: DateTime(2026, 9, 15), weightKg: 80.5);
    expect(repo.logged.single.date, DateTime(2026, 9, 15));
    expect(target, isNull);
  });

  test('the first ever entry counts as newest', () async {
    repo.logs.clear();
    expect(await service().log(date: DateTime(2026, 9, 1), weightKg: 82), isNotNull);
  });

  test('deleting the newest entry recalculates targets from the previous one', () async {
    await service().delete(DateTime(2026, 9, 20));

    final call = repo.deleted.single;
    expect(call.date, DateTime(2026, 9, 20));
    expect(call.newLatest!.weightKg, 81);
    expect(call.newLatest!.calorieTarget, expectedFor(81).calorieTarget);
  });

  test('deleting an older entry does not touch the profile', () async {
    await service().delete(DateTime(2026, 9, 10));
    expect(repo.deleted.single.newLatest, isNull);
  });

  test('the only entry cannot be deleted', () async {
    repo.logs.removeAt(0);
    await expectLater(service().delete(DateTime(2026, 9, 20)), throwsA(isA<LastWeightLogException>()));
    expect(repo.deleted, isEmpty);
  });

  test('a stale list error is passed through', () async {
    repo.error = StaleWeightListException();
    await expectLater(service().delete(DateTime(2026, 9, 20)), throwsA(isA<StaleWeightListException>()));
  });

  test('recordInitialWeight logs the onboarding weight with the saved targets', () async {
    await recordInitialWeight(repo, testProfile, DateTime(2026, 9, 28, 18));
    final call = repo.logged.single;
    expect(call.date, DateTime(2026, 9, 28));
    expect(call.update.weightKg, testProfile.weightKg);
    expect(call.update.calorieTarget, testProfile.dailyCalorieTarget);
    expect(call.update.proteinTargetG, testProfile.dailyProteinTargetG);
  });
}
