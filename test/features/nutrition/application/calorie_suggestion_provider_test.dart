import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spor_takip/features/nutrition/application/calorie_suggestion_provider.dart';
import 'package:spor_takip/features/nutrition/domain/adaptive_tdee.dart';
import 'package:spor_takip/features/onboarding/application/profile_providers.dart';
import 'package:spor_takip/features/onboarding/domain/profile.dart';
import 'package:spor_takip/features/progress/application/progress_providers.dart';
import 'package:spor_takip/features/progress/domain/body_weight_log.dart';
import 'package:spor_takip/features/workout/application/session_providers.dart';

import '../../progress/fakes.dart';
import '../../progress/fixtures.dart';

void main() {
  test('combines profile, weight logs and meals into a suggestion', () async {
    final container = ProviderContainer(
      retry: (retryCount, error) => null,
      overrides: [
        profileProvider.overrideWith(
          (ref) async => testProfile.copyWith(weightDirection: WeightDirection.lose, pace: Pace.balanced),
        ),
        weightLogsProvider.overrideWith((ref) async => [
              for (var i = 0; i < 22; i++) BodyWeightLog(date: DateTime(2026, 10, 1 + i), weightKg: 80),
            ]),
        progressDataRepositoryProvider.overrideWithValue(FakeProgressDataRepository()),
        nowProvider.overrideWithValue(() => DateTime(2026, 10, 22, 10)),
      ],
    );
    addTearDown(container.dispose);

    final suggestion = await container.read(calorieSuggestionProvider.future);
    expect(suggestion, isNotNull);
    expect(suggestion!.method, SuggestionMethod.weightTrend);
    expect(suggestion.newTarget, closeTo(1849, 0.01));
  });

  test('no profile gives no suggestion', () async {
    final container = ProviderContainer(
      retry: (retryCount, error) => null,
      overrides: [
        profileProvider.overrideWith((ref) async => null),
        weightLogsProvider.overrideWith((ref) async => const []),
        progressDataRepositoryProvider.overrideWithValue(FakeProgressDataRepository()),
        nowProvider.overrideWithValue(() => DateTime(2026, 10, 22, 10)),
      ],
    );
    addTearDown(container.dispose);
    expect(await container.read(calorieSuggestionProvider.future), isNull);
  });
}
