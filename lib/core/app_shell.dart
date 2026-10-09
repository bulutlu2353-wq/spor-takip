import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../features/social/application/social_providers.dart';

class AppShell extends ConsumerWidget {
  const AppShell({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Kabuk açıkken oyuncu özeti arkadaşlar için yayınlanır (S1 spec §6.1).
    ref.watch(statsSyncProvider);
    final requests = ref.watch(incomingRequestCountProvider);
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
