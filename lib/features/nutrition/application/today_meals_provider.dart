import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/supabase_client.dart';
import '../../onboarding/application/auth_providers.dart';
import '../domain/meal.dart';
import 'meal_providers.dart';

final todayMealsProvider = FutureProvider.autoDispose<List<Meal>>((ref) async {
  final isLoggedIn = ref.watch(isLoggedInProvider);
  if (!isLoggedIn) return const [];
  final userId = AppSupabase.client.auth.currentUser!.id;
  return ref.watch(mealRepositoryProvider).fetchMealsForDate(
        userId: userId,
        date: DateTime.now(),
      );
});
