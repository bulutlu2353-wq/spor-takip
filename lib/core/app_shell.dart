import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../features/notifications/application/notification_providers.dart';
import '../features/social/application/challenge_providers.dart';
import '../features/social/application/social_providers.dart';

class AppShell extends ConsumerWidget {
  const AppShell({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Kabuk açıkken oyuncu özeti (S1 spec §6.1), meydan okuma değerlerim (S3) ve hatırlatıcılar (N1) güncel tutulur.
    ref.watch(statsSyncProvider);
    ref.watch(challengeSyncProvider);
    ref.watch(notificationSyncProvider(context.locale.languageCode));
    // Dokunulan bildirimin rotasına git (N1 spec §3.3).
    void openPending() => Future.microtask(() {
          if (!context.mounted) return;
          final next = ref.read(pendingNotificationRouteProvider.notifier).take();
          if (next != null) GoRouter.of(context).go(next);
        });
    ref.listen(pendingNotificationRouteProvider, (_, route) {
      if (route != null) openPending();
    });
    // Uygulama bir bildirimle açıldıysa rota kabuk kurulmadan önce yazılmış olur.
    if (ref.read(pendingNotificationRouteProvider) != null) openPending();
    final requests = ref.watch(incomingRequestCountProvider) + ref.watch(pendingChallengeInvitesProvider);
    Widget socialIcon(IconData icon) =>
        requests > 0 ? Badge(key: const Key('nav_social_badge'), label: Text('$requests'), child: Icon(icon)) : Icon(icon);
    return Scaffold(
      body: navigationShell,
      bottomNavigationBar: NavigationBar(
        key: const Key('app_bottom_nav'),
        selectedIndex: navigationShell.currentIndex,
        onDestinationSelected: (index) => navigationShell.goBranch(
          index,
          initialLocation: index == navigationShell.currentIndex,
        ),
        destinations: [
          NavigationDestination(
            icon: const Icon(Icons.home_outlined),
            selectedIcon: const Icon(Icons.home),
            label: 'nav.home'.tr(),
          ),
          NavigationDestination(
            icon: const Icon(Icons.restaurant_outlined),
            selectedIcon: const Icon(Icons.restaurant),
            label: 'nav.nutrition'.tr(),
          ),
          NavigationDestination(
            icon: const Icon(Icons.fitness_center_outlined),
            selectedIcon: const Icon(Icons.fitness_center),
            label: 'nav.workout'.tr(),
          ),
          NavigationDestination(
            icon: const Icon(Icons.forum_outlined),
            selectedIcon: const Icon(Icons.forum),
            label: 'nav.coach'.tr(),
          ),
          NavigationDestination(
            icon: socialIcon(Icons.group_outlined),
            selectedIcon: socialIcon(Icons.group),
            label: 'nav.social'.tr(),
          ),
        ],
      ),
    );
  }
}
