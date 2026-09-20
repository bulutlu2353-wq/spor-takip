import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../features/onboarding/application/auth_providers.dart';
import '../features/onboarding/application/profile_providers.dart';
import '../features/onboarding/presentation/home_screen.dart';
import '../features/onboarding/presentation/login_screen.dart';
import '../features/onboarding/presentation/onboarding_wizard_screen.dart';
import '../features/onboarding/presentation/register_screen.dart';
import 'redirect_logic.dart';

final routerProvider = Provider<GoRouter>((ref) {
  final isLoggedIn = ref.watch(isLoggedInProvider);
  // Riverpod 3.x: `.value` (not the removed `valueOrNull`) returns null on
  // error/loading — see the same note in Task 6's `isLoggedInProvider`.
  final hasProfile = ref.watch(profileProvider).value != null;

  return GoRouter(
    initialLocation: '/login',
    redirect: (context, state) {
      return computeRedirect(
        isLoggedIn: isLoggedIn,
        hasProfile: hasProfile,
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
      GoRoute(path: '/home', builder: (context, state) => const HomeScreen()),
    ],
  );
});
