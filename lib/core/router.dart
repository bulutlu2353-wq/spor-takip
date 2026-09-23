import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../features/nutrition/presentation/meal_capture_screen.dart';
import '../features/nutrition/presentation/nutrition_screen.dart';
import '../features/onboarding/application/auth_providers.dart';
import '../features/onboarding/application/profile_providers.dart';
import '../features/onboarding/presentation/home_screen.dart';
import '../features/onboarding/presentation/login_screen.dart';
import '../features/onboarding/presentation/onboarding_wizard_screen.dart';
import '../features/onboarding/presentation/register_screen.dart';
import 'app_shell.dart';
import 'redirect_logic.dart';

final routerProvider = Provider<GoRouter>((ref) {
  final isLoggedIn = ref.watch(isLoggedInProvider);
  final profileAsync = ref.watch(profileProvider);
  // AsyncValue.when correctly avoids re-triggering `loading` during a
  // background refresh that already has data, via Riverpod's default
  // skipLoadingOnRefresh.
  final profileState = profileAsync.when(
    data: (profile) => profile == null ? ProfileState.absent : ProfileState.present,
    loading: () => ProfileState.loading,
    error: (_, _) => ProfileState.error,
  );

  return GoRouter(
    initialLocation: '/login',
    redirect: (context, state) {
      return computeRedirect(
        isLoggedIn: isLoggedIn,
        profileState: profileState,
        location: state.uri.path,
      );
    },
    routes: [
      GoRoute(path: '/login', builder: (context, state) => const LoginScreen()),
      GoRoute(path: '/register', builder: (context, state) => const RegisterScreen()),
      GoRoute(
        path: '/onboarding',
        builder: (context, state) => const OnboardingWizardScreen(),
      ),
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) => AppShell(navigationShell: navigationShell),
        branches: [
          StatefulShellBranch(
            routes: [GoRoute(path: '/home', builder: (context, state) => const HomeScreen())],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/nutrition',
                builder: (context, state) => const NutritionScreen(),
                routes: [
                  GoRoute(
                    path: 'capture',
                    builder: (context, state) => const MealCaptureScreen(),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    ],
  );
});
