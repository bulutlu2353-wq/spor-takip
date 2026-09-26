import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/supabase_client.dart';
import '../../onboarding/application/auth_providers.dart';
import '../data/session_repository.dart';
import '../domain/workout_session.dart';

final sessionRepositoryProvider = Provider<SessionRepository>((ref) {
  return SupabaseSessionRepository(AppSupabase.client);
});

/// Ana ekran kartı ve başlatma çakışması için; başlat/bitir/iptal sonrası invalidate edilir.
final inProgressSessionProvider = FutureProvider.autoDispose<WorkoutSession?>((ref) async {
  if (!ref.watch(isLoggedInProvider)) return null;
  return ref.watch(sessionRepositoryProvider).fetchInProgressSession();
});

final sessionHistoryProvider = FutureProvider.autoDispose<List<WorkoutSession>>((ref) async {
  if (!ref.watch(isLoggedInProvider)) return const [];
  return ref.watch(sessionRepositoryProvider).fetchHistory();
});

final sessionDetailProvider = FutureProvider.autoDispose.family<WorkoutSession, String>((ref, id) {
  return ref.watch(sessionRepositoryProvider).fetchSession(id);
});

/// "Şimdi"; testlerde sabit bir fonksiyonla override edilir.
final nowProvider = Provider<DateTime Function()>((ref) => DateTime.now);

/// Saniyede bir "şimdi"; geçen süre ve dinlenme sayacı bunu izler.
/// Widget testlerinde `Stream.value(sabit)` ile override edilmeli.
final clockProvider = StreamProvider.autoDispose<DateTime>((ref) {
  return Stream.periodic(const Duration(seconds: 1), (_) => DateTime.now());
});
