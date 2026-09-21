import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/supabase_client.dart';

/// Supabase auth durumundaki değişiklikleri (giriş/çıkış/oturum yenileme)
/// yayınlayan stream.
final authStateProvider = StreamProvider<AuthState>((ref) {
  return AppSupabase.client.auth.onAuthStateChange;
});

/// Şu anda giriş yapılmış bir kullanıcı var mı.
final isLoggedInProvider = Provider<bool>((ref) {
  final session = ref.watch(authStateProvider).asData?.value.session;
  return session != null;
});

class AuthRepository {
  AuthRepository(this._client);

  final SupabaseClient _client;

  String get currentUserId {
    final user = _client.auth.currentUser;
    if (user == null) {
      throw StateError('currentUserId çağrıldı ama giriş yapılmış kullanıcı yok');
    }
    return user.id;
  }

  Future<void> signUp({required String email, required String password}) {
    return _client.auth.signUp(email: email, password: password);
  }

  Future<void> signIn({required String email, required String password}) {
    return _client.auth.signInWithPassword(email: email, password: password);
  }

  Future<void> signOut() => _client.auth.signOut();

  Future<void> resetPassword(String email) {
    return _client.auth.resetPasswordForEmail(email);
  }

  Future<bool> signInWithGoogle() {
    return _client.auth.signInWithOAuth(OAuthProvider.google);
  }
}

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepository(AppSupabase.client);
});
