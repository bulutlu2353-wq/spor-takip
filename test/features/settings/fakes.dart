import 'package:spor_takip/features/onboarding/application/auth_providers.dart';
import 'package:spor_takip/features/onboarding/data/profile_repository.dart';

class FakeProfileRepository implements ProfileRepository {
  final updates = <Map<String, dynamic>>[];

  /// Doluysa `updateProfile` bunu fırlatır.
  Object? error;

  @override
  Future<void> updateProfile(String userId, Map<String, dynamic> fields) async {
    if (error != null) throw error!;
    updates.add(fields);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName} stub edilmedi');
}

class FakeAuthRepository implements AuthRepository {
  var signedOut = false;

  @override
  String get currentUserId => 'user-1';

  @override
  String? get currentEmail => 'ornek@mail.com';

  @override
  Future<void> signOut() async => signedOut = true;

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName} stub edilmedi');
}
