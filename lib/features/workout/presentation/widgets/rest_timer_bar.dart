import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../application/rest_timer.dart';
import '../../application/session_providers.dart';
import '../../domain/session_stats.dart';

/// Set işaretlenince görünen geri sayım. Süre dolunca titreşim + sistem sesi.
/// Yalnızca uygulama açıkken çalışır (bildirimler F6'da).
class RestTimerBar extends ConsumerWidget {
  const RestTimerBar({super.key});

  void _alarm(BuildContext context, WidgetRef ref) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!context.mounted) return;
      HapticFeedback.vibrate();
      SystemSound.play(SystemSoundType.alert);
      ref.read(restTimerProvider.notifier).stop();
    });
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final endsAt = ref.watch(restTimerProvider);
    if (endsAt == null) return const SizedBox.shrink();
    final now = ref.watch(clockProvider).value ?? ref.watch(nowProvider)();
    final remaining = endsAt.difference(now);
    if (remaining <= Duration.zero) {
      _alarm(context, ref);
      return const SizedBox.shrink();
    }
    final timer = ref.read(restTimerProvider.notifier);
    final theme = Theme.of(context);
    final onBar = theme.colorScheme.onPrimary;
    return Material(
      key: const Key('rest_timer_bar'),
      color: theme.colorScheme.primary,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 8, 10),
          child: IconTheme.merge(
            data: IconThemeData(color: onBar),
            child: Row(
              children: [
                const Icon(Icons.timer_outlined),
                const SizedBox(width: 8),
                Text(
                  formatDuration(remaining),
                  key: const Key('rest_timer_remaining'),
                  style: theme.textTheme.headlineSmall?.copyWith(color: onBar, fontWeight: FontWeight.w900),
                ),
                const SizedBox(width: 8),
                // Dar ekranda düğmelere yer kalsın diye etiket kısalır.
                Expanded(
                  child: Text(
                    'workout.session.rest'.tr(),
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodyMedium?.copyWith(color: onBar, fontWeight: FontWeight.w600),
                  ),
                ),
                TextButton(
                  key: const Key('rest_timer_add'),
                  style: TextButton.styleFrom(foregroundColor: onBar),
                  onPressed: () => timer.addSeconds(30),
                  child: Text('workout.session.rest_add'.tr()),
                ),
                IconButton(
                  key: const Key('rest_timer_skip'),
                  onPressed: timer.stop,
                  tooltip: 'workout.session.rest_skip'.tr(),
                  color: onBar,
                  icon: const Icon(Icons.skip_next),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
