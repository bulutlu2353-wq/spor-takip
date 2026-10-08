import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spor_takip/features/onboarding/application/profile_providers.dart';
import 'package:spor_takip/features/onboarding/domain/profile.dart';
import 'package:spor_takip/features/workout/application/muscle_map_providers.dart';
import 'package:spor_takip/features/workout/domain/muscle_map.dart';

import '../../progress/fixtures.dart';

ProviderContainer _container(Profile? profile) {
  final container = ProviderContainer(overrides: [profileProvider.overrideWith((ref) async => profile)]);
  addTearDown(container.dispose);
  return container;
}

void main() {
  test('defaults to the figure of the profile gender', () async {
    final female = _container(testProfile.copyWith(gender: Gender.female));
    await female.read(profileProvider.future);
    expect(female.read(mapFigureProvider), BodyFigure.female);

    final male = _container(testProfile);
    await male.read(profileProvider.future);
    expect(male.read(mapFigureProvider), BodyFigure.male);
  });

  test('falls back to the male figure without a profile', () async {
    final container = _container(null);
    expect(container.read(mapFigureProvider), BodyFigure.male); // yükleniyor
    await container.read(profileProvider.future);
    expect(container.read(mapFigureProvider), BodyFigure.male);
  });

  test('a manual choice wins over the profile', () async {
    final container = _container(testProfile.copyWith(gender: Gender.female));
    await container.read(profileProvider.future);
    container.read(mapFigureChoiceProvider.notifier).choose(BodyFigure.male);
    expect(container.read(mapFigureProvider), BodyFigure.male);
  });
}
