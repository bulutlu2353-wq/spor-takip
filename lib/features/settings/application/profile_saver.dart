import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../onboarding/application/auth_providers.dart';
import '../../onboarding/application/profile_providers.dart';

/// [changes]'i profile yazar ve profili yeniler; başarıda true (G2 spec §3.3, §5).
Future<bool> saveProfileChanges(WidgetRef ref, Map<String, dynamic> changes) async {
  try {
    final userId = ref.read(authRepositoryProvider).currentUserId;
    await ref.read(profileRepositoryProvider).updateProfile(userId, changes);
    ref.invalidate(profileProvider);
    return true;
  } catch (e, st) {
    debugPrint('Profile update failed: $e\n$st');
    return false;
  }
}
