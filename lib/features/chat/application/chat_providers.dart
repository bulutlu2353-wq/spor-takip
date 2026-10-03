import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/supabase_client.dart';
import '../data/chat_repository.dart';

final chatRepositoryProvider = Provider<ChatRepository>((ref) {
  return SupabaseChatRepository(AppSupabase.client);
});

/// Antrenör sohbeti açık mı? Geliştirme sürerken `false`: sekme görünür ama
/// yalnız tanıtım + "geliştirme aşamasında" ekranı gösterilir, model çağrılmaz.
final coachEnabledProvider = Provider<bool>((ref) => false);
