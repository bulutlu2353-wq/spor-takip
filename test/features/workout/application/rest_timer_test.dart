import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spor_takip/features/workout/application/rest_timer.dart';
import 'package:spor_takip/features/workout/application/session_providers.dart';

void main() {
  final now = DateTime(2026, 9, 26, 10);

  test('start, extend and stop', () {
    final container = ProviderContainer(overrides: [nowProvider.overrideWithValue(() => now)]);
    addTearDown(container.dispose);
    container.listen(restTimerProvider, (_, _) {});
    final timer = container.read(restTimerProvider.notifier);

    expect(container.read(restTimerProvider), isNull);

    timer.start(null);
    expect(container.read(restTimerProvider), now.add(const Duration(seconds: 90)));

    timer.start(60);
    expect(container.read(restTimerProvider), now.add(const Duration(seconds: 60)));

    timer.addSeconds(30);
    expect(container.read(restTimerProvider), now.add(const Duration(seconds: 90)));

    timer.stop();
    expect(container.read(restTimerProvider), isNull);

    timer.addSeconds(30);
    expect(container.read(restTimerProvider), isNull, reason: 'extending a stopped timer does nothing');
  });
}
