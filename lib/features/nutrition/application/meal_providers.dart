import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/supabase_client.dart';
import '../data/meal_repository.dart';

final mealRepositoryProvider = Provider<MealRepository>((ref) {
  return SupabaseMealRepository(AppSupabase.client);
});
