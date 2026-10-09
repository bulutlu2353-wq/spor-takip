import 'package:flutter_test/flutter_test.dart';
import 'package:spor_takip/features/social/domain/friendship.dart';
import 'package:spor_takip/features/social/domain/public_profile.dart';
import 'package:spor_takip/features/social/domain/username.dart';

void main() {
  test('usernames are trimmed, lowercased and lose a leading @', () {
    expect(normalizeUsername('  @Samet_Fit '), 'samet_fit');
    expect(normalizeUsername('ab'), 'ab');
  });

  test('username rules: 3–20 characters of a–z, 0–9 and _', () {
    expect(checkUsername('ab'), UsernameProblem.tooShort);
    expect(checkUsername('abc'), isNull);
    expect(checkUsername('a' * 20), isNull);
    expect(checkUsername('a' * 21), UsernameProblem.tooLong);
    expect(checkUsername('ali-veli'), UsernameProblem.invalidCharacters);
    expect(checkUsername('şule'), UsernameProblem.invalidCharacters);
    expect(checkUsername('ali veli'), UsernameProblem.invalidCharacters);
  });

  test('a profile reads its row and falls back to sharing everything', () {
    final p = PublicProfile.fromJson({
      'user_id': 'u1',
      'username': 'samet_fit',
      'display_name': 'Samet Aydın',
      'invite_code': 'K7Q2M9XA',
      'share_weekly': false,
    });
    expect((p.userId, p.username, p.displayName, p.inviteCode), ('u1', 'samet_fit', 'Samet Aydın', 'K7Q2M9XA'));
    expect((p.shareWeekly, p.shareWorkouts, p.shareHeat), (false, true, true));
    expect(p.initials, 'SA');
    expect(p.copyWith(shareHeat: false).shareHeat, isFalse);
    expect(p.copyWith(displayName: 'Ali').displayName, 'Ali');
  });

  test('initials come from the first two words, else the first two letters', () {
    expect(initialsOf('Ayşe Kaya', 'ayse'), 'AK');
    expect(initialsOf('deniz', 'deniz'), 'DE');
    expect(initialsOf('  ', 'mo'), 'MO');
  });

  test('found users read the function rows', () {
    final f = FoundUser.fromJson({'user_id': 'u2', 'username': 'ayse.k', 'display_name': 'Ayşe Kaya'});
    expect((f.userId, f.username, f.displayName, f.initials), ('u2', 'ayse.k', 'Ayşe Kaya', 'AK'));
  });

  test('a friendship knows its side', () {
    final f = Friendship.fromJson({
      'requester': 'me',
      'addressee': 'ayse',
      'status': 'pending',
      'created_at': '2026-10-09T10:00:00Z',
    });
    expect(f.stateFor('me'), FriendshipState.outgoing);
    expect(f.stateFor('ayse'), FriendshipState.incoming);
    expect(f.otherThan('me'), 'ayse');
    expect(f.otherThan('ayse'), 'me');
    final accepted = Friendship(requester: 'me', addressee: 'ayse', accepted: true, createdAt: DateTime(2026));
    expect(accepted.stateFor('ayse'), FriendshipState.friends);
  });
}
