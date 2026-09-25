import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:spor_takip/core/app_shell.dart';

void main() {
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await EasyLocalization.ensureInitialized();
  });

  Widget buildTestRouter() {
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
          ],
        ),
      ],
    );
    return EasyLocalization(
      supportedLocales: const [Locale('tr'), Locale('en')],
      path: 'assets/translations',
      fallbackLocale: const Locale('tr'),
      child: MaterialApp.router(routerConfig: router),
    );
  }

  testWidgets('shows all nav destinations and starts on the home branch', (tester) async {
    await tester.pumpWidget(buildTestRouter());
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('app_bottom_nav')), findsOneWidget);
    expect(find.text('HOME_SCREEN'), findsOneWidget);
    expect(find.text('NUTRITION_SCREEN'), findsNothing);
  });

  testWidgets('tapping the nutrition destination switches branch', (tester) async {
    await tester.pumpWidget(buildTestRouter());
    await tester.pumpAndSettle();

    // Tap by icon rather than by translated label: as in the other widget
    // tests in this suite (e.g. nutrition_screen_test.dart), the
    // EasyLocalization asset load does not reliably complete within
    // pumpAndSettle() in the test environment, so `.tr()` output ("Beslenme")
    // cannot be relied upon here. The icon is locale-independent and
    // uniquely identifies the nutrition destination.
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
}
