import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/supabase_client.dart';
import '../data/profile_repository.dart';
import '../domain/profile.dart';
import 'auth_providers.dart';

final profileRepositoryProvider = Provider<ProfileRepository>((ref) {
  return ProfileRepository(AppSupabase.client);
});

/// Giriş yapılmış kullanıcının profilini getirir. Giriş yapılmamışsa veya
/// henüz profil oluşturulmamışsa null döner (onboarding gerekli demektir).
final profileProvider = FutureProvider<Profile?>((ref) async {
  final isLoggedIn = ref.watch(isLoggedInProvider);
  if (!isLoggedIn) return null;
  final userId = AppSupabase.client.auth.currentUser!.id;
  return ref.watch(profileRepositoryProvider).fetchProfile(userId);
});
