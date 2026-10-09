import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:spor_takip/core/app_shell.dart';
import 'package:spor_takip/features/social/application/social_providers.dart';

void main() {
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await EasyLocalization.ensureInitialized();
  });

  Widget buildTestRouter({int requests = 0}) {
    final router = GoRouter(
      initialLocation: '/home',
      routes: [
        StatefulShellRoute.indexedStack(
          builder: (context, state, navigationShell) => AppShell(navigationShell: navigationShell),
          branches: [
            StatefulShellBranch(routes: [
              GoRoute(path: '/home', builder: (context, state) => const Text('HOME_SCREEN')),
            ]),
            StatefulShellBranch(routes: [
              GoRoute(path: '/nutrition', builder: (context, state) => const Text('NUTRITION_SCREEN')),
            ]),
            StatefulShellBranch(routes: [
              GoRoute(path: '/workout', builder: (context, state) => const Text('WORKOUT_SCREEN')),
            ]),
            StatefulShellBranch(routes: [
              GoRoute(path: '/coach', builder: (context, state) => const Text('COACH_SCREEN')),
            ]),
            StatefulShellBranch(routes: [
              GoRoute(path: '/social', builder: (context, state) => const Text('SOCIAL_SCREEN')),
            ]),
          ],
        ),
      ],
    );
    return EasyLocalization(
      supportedLocales: const [Locale('tr'), Locale('en')],
      path: 'assets/translations',
      fallbackLocale: const Locale('tr'),
      child: ProviderScope(
        overrides: [
          statsSyncProvider.overrideWith((ref) async {}),
          incomingRequestCountProvider.overrideWithValue(requests),
        ],
        child: MaterialApp.router(routerConfig: router),
      ),
    );
  }

  testWidgets('shows all nav destinations and starts on the home branch', (tester) async {
    await tester.pumpWidget(buildTestRouter());
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('app_bottom_nav')), findsOneWidget);
    expect(find.text('HOME_SCREEN'), findsOneWidget);
    expect(find.text('NUTRITION_SCREEN'), findsNothing);
    expect(find.byIcon(Icons.group_outlined), findsOneWidget);
    expect(find.byKey(const Key('nav_social_badge')), findsNothing);
  });

  testWidgets('tapping the nutrition destination switches branch', (tester) async {
    await tester.pumpWidget(buildTestRouter());
    await tester.pumpAndSettle();

    // Çeviri metni testlerde güvenilir değil; ikonla dokunulur.
    await tester.tap(find.byIcon(Icons.restaurant_outlined));
    await tester.pumpAndSettle();

    expect(find.text('NUTRITION_SCREEN'), findsOneWidget);
    expect(find.text('HOME_SCREEN'), findsNothing);
  });

  testWidgets('tapping the workout destination switches branch', (tester) async {
    await tester.pumpWidget(buildTestRouter());
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.fitness_center_outlined));
    await tester.pumpAndSettle();

    expect(find.text('WORKOUT_SCREEN'), findsOneWidget);
    expect(find.text('HOME_SCREEN'), findsNothing);
  });

  testWidgets('tapping the coach destination switches to the coach branch', (tester) async {
    await tester.pumpWidget(buildTestRouter());
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.forum_outlined));
    await tester.pumpAndSettle();

    expect(find.text('COACH_SCREEN'), findsOneWidget);
    expect(find.text('HOME_SCREEN'), findsNothing);
  });

  testWidgets('the social tab opens the social branch and shows pending requests', (tester) async {
    await tester.pumpWidget(buildTestRouter(requests: 2));
    await tester.pumpAndSettle();

    final badge = find.byKey(const Key('nav_social_badge'));
    expect(badge, findsOneWidget);
    expect(find.descendant(of: badge, matching: find.text('2')), findsOneWidget);

    await tester.tap(find.byIcon(Icons.group_outlined));
    await tester.pumpAndSettle();
    expect(find.text('SOCIAL_SCREEN'), findsOneWidget);
  });
}
