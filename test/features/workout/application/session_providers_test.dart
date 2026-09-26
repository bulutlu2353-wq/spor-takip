import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spor_takip/features/onboarding/application/auth_providers.dart';
import 'package:spor_takip/features/workout/application/session_providers.dart';
import 'package:spor_takip/features/workout/domain/workout_session.dart';

import '../fakes.dart';

WorkoutSession _session(String id, {DateTime? finishedAt}) => WorkoutSession(
      id: id,
      programName: 'P',
      workoutName: 'A',
      workoutPosition: 0,
      startedAt: DateTime(2026, 9, 20, 10),
      finishedAt: finishedAt,
    );

void main() {
  ProviderContainer containerWith(FakeSessionRepository repo, {bool loggedIn = true}) {
    final container = ProviderContainer(overrides: [
      isLoggedInProvider.overrideWithValue(loggedIn),
      sessionRepositoryProvider.overrideWithValue(repo),
    ]);
    addTearDown(container.dispose);
    return container;
  }

  test('in-progress session and history come from the repository', () async {
    final repo = FakeSessionRepository(sessions: [
      _session('cur'),
      _session('old', finishedAt: DateTime(2026, 9, 20, 11)),
      _session('older', finishedAt: DateTime(2026, 9, 18, 11)),
    ]);
    final container = containerWith(repo);
    container.listen(inProgressSessionProvider, (_, _) {});
    container.listen(sessionHistoryProvider, (_, _) {});

    expect((await container.read(inProgressSessionProvider.future))!.id, 'cur');
    expect((await container.read(sessionHistoryProvider.future)).map((s) => s.id), ['old', 'older']);
  });

  test('logged out → no session and empty history', () async {
    final container = containerWith(FakeSessionRepository(sessions: [_session('cur')]), loggedIn: false);
    container.listen(inProgressSessionProvider, (_, _) {});
    container.listen(sessionHistoryProvider, (_, _) {});

    expect(await container.read(inProgressSessionProvider.future), isNull);
    expect(await container.read(sessionHistoryProvider.future), isEmpty);
  });
}
