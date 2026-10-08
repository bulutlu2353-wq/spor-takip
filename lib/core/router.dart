import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../features/chat/presentation/coach_screen.dart';
import '../features/nutrition/presentation/meal_capture_screen.dart';
import '../features/nutrition/presentation/nutrition_screen.dart';
import '../features/onboarding/application/auth_providers.dart';
import '../features/onboarding/application/profile_providers.dart';
import '../features/onboarding/presentation/home_screen.dart';
import '../features/onboarding/presentation/login_screen.dart';
import '../features/onboarding/presentation/onboarding_wizard_screen.dart';
import '../features/onboarding/presentation/register_screen.dart';
import '../features/progress/presentation/measurements_screen.dart';
import '../features/progress/presentation/strength_screen.dart';
import '../features/progress/presentation/weight_screen.dart';
import '../features/settings/presentation/goals_screen.dart';
import '../features/settings/presentation/settings_screen.dart';
import '../features/workout/presentation/exercise_picker_screen.dart';
import '../features/workout/presentation/history_detail_screen.dart';
import '../features/workout/presentation/history_screen.dart';
import '../features/workout/presentation/muscle_map_screen.dart';
import '../features/workout/presentation/program_detail_screen.dart';
import '../features/workout/presentation/program_editor_screen.dart';
import '../features/workout/presentation/programs_screen.dart';
import '../features/workout/presentation/session_screen.dart';
import '../features/workout/presentation/session_summary_screen.dart';
import 'app_shell.dart';
import 'redirect_logic.dart';

final routerProvider = Provider<GoRouter>((ref) {
  final isLoggedIn = ref.watch(isLoggedInProvider);
  // Yalnızca profilin durumu izlenir: kilo kaydı profili yenilediğinde (F4b)
  // yeni bir GoRouter kurulup gezinme yığını sıfırlanmasın. AsyncValue.when,
  // Riverpod'un varsayılan skipLoadingOnRefresh'i sayesinde veri varken
  // yapılan arka plan yenilemesinde `loading`'e düşmez.
  final profileState = ref.watch(profileProvider.select((profileAsync) => profileAsync.when(
        data: (profile) => profile == null ? ProfileState.absent : ProfileState.present,
        loading: () => ProfileState.loading,
        error: (_, _) => ProfileState.error,
      )));

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
      // Antrenman: alt menü dışında tam ekran.
      GoRoute(
        path: '/session/:id',
        builder: (context, state) => SessionScreen(sessionId: state.pathParameters['id']!),
        routes: [
          GoRoute(path: 'exercises', builder: (context, state) => const ExercisePickerScreen()),
          GoRoute(
            path: 'summary',
            builder: (context, state) => SessionSummaryScreen(sessionId: state.pathParameters['id']!),
          ),
        ],
      ),
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) => AppShell(navigationShell: navigationShell),
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/home',
                builder: (context, state) => const HomeScreen(),
                routes: [
                  GoRoute(path: 'weight', builder: (context, state) => const WeightScreen()),
                  GoRoute(path: 'strength', builder: (context, state) => const StrengthScreen()),
                  GoRoute(path: 'measurements', builder: (context, state) => const MeasurementsScreen()),
                  GoRoute(
                    path: 'settings',
                    builder: (context, state) => const SettingsScreen(),
                    routes: [GoRoute(path: 'goals', builder: (context, state) => const GoalsScreen())],
                  ),
                ],
              ),
            ],
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
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/workout',
                builder: (context, state) => const ProgramsScreen(),
                routes: [
                  GoRoute(path: 'new', builder: (context, state) => const ProgramEditorScreen()),
                  GoRoute(path: 'exercises', builder: (context, state) => const ExercisePickerScreen()),
                  GoRoute(path: 'muscles', builder: (context, state) => const MuscleMapScreen()),
                  GoRoute(
                    path: 'history',
                    builder: (context, state) => const HistoryScreen(),
                    routes: [
                      GoRoute(
                        path: ':id',
                        builder: (context, state) =>
                            HistoryDetailScreen(sessionId: state.pathParameters['id']!),
                      ),
                    ],
                  ),
                  GoRoute(
                    path: 'program/:id',
                    builder: (context, state) =>
                        ProgramDetailScreen(programId: state.pathParameters['id']!),
                    routes: [
                      GoRoute(
                        path: 'edit',
                        builder: (context, state) =>
                            ProgramEditorScreen(programId: state.pathParameters['id']),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(path: '/coach', builder: (context, state) => const CoachScreen()),
            ],
          ),
        ],
      ),
    ],
  );
});
