import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'session_providers.dart';

/// Dinlenmenin bittiği an; null = sayaç kapalı. Oturum ekranı kapanınca sıfırlanır.
final restTimerProvider = NotifierProvider.autoDispose<RestTimerNotifier, DateTime?>(RestTimerNotifier.new);

class RestTimerNotifier extends Notifier<DateTime?> {
  static const defaultSeconds = 90;

  @override
  DateTime? build() => null;

  void start(int? seconds) {
    state = ref.read(nowProvider)().add(Duration(seconds: seconds ?? defaultSeconds));
  }

  void addSeconds(int seconds) {
    final endsAt = state;
    if (endsAt != null) state = endsAt.add(Duration(seconds: seconds));
  }

  void stop() => state = null;
}
