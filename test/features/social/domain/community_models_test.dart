import 'package:flutter_test/flutter_test.dart';
import 'package:spor_takip/features/gamification/domain/levels.dart';
import 'package:spor_takip/features/gamification/domain/titles.dart';
import 'package:spor_takip/features/social/domain/community.dart';
import 'package:spor_takip/features/social/domain/public_profile.dart';

void main() {
  test('community, member and search result rows', () {
    final community = Community.fromJson({
      'id': 'c1',
      'name': 'Demir Kulübü',
      'description': 'Sabah 6 ekibi',
      'is_public': false,
      'invite_code': 'Q7M2K9TA',
      'owner': 'me',
    });
    expect(community.isPublic, isFalse);
    expect(community.inviteCode, 'Q7M2K9TA');
    final edited = community.copyWith(name: 'Demir', isPublic: true);
    expect((edited.id, edited.name, edited.description, edited.isPublic, edited.owner),
        ('c1', 'Demir', 'Sabah 6 ekibi', true, 'me'));

    final member = CommunityMember.fromJson({
      'community_id': 'c1',
      'user_id': 'ayse',
      'role': 'owner',
      'joined_at': '2026-10-01T09:00:00Z',
    });
    expect((member.communityId, member.userId, member.isOwner), ('c1', 'ayse', true));
    expect(member.joinedAt.isUtc, isFalse);

    final result = CommunitySearchResult.fromJson({
      'id': 'c1',
      'name': 'Demir Kulübü',
      'description': null,
      'member_count': 24,
      'is_member': true,
    });
    expect((result.description, result.memberCount, result.isMember), ('', 24, true));
  });

  test('global title and row', () {
    final title = GlobalTitle.fromJson({
      'category': 'lats',
      'user_id': 'ayse',
      'username': 'ayse_k',
      'display_name': 'Ayşe Kaya',
      'level': 42,
      'rank': 'gladiator',
      'value': 41.5,
    });
    expect((title.category, title.level, title.rank, title.value), ('lats', 42, Rank.gladiator, 41.5));

    final row = GlobalRow.fromJson({
      'position': 3,
      'user_id': 'ayse',
      'username': 'ayse_k',
      'display_name': 'Ayşe Kaya',
      'level': 42,
      'rank': 'unknown',
      'active_title': {'kind': 'muscle', 'subject_id': 'lats', 'tier': 'champion'},
      'xp': 4120,
    });
    expect((row.position, row.rank, row.xp, row.initials), (3, Rank.rookie, 4120, 'AK'));
    expect(row.activeTitle?.tier, TitleTier.champion);
  });

  test('community exception keeps its code', () {
    expect(const CommunityException('banned').code, 'banned');
    expect(communityErrorCodes, containsAll(['community_limit', 'unknown_code', 'not_owner']));
    expect(maxCommunities, 5);
  });

  test('profiles compete globally unless the row says otherwise', () {
    const base = {'user_id': 'me', 'username': 'samet_fit', 'display_name': 'Samet'};
    expect(PublicProfile.fromJson(base).competeGlobally, isTrue);
    final out = PublicProfile.fromJson({...base, 'compete_globally': false});
    expect(out.competeGlobally, isFalse);
    expect(out.copyWith(competeGlobally: true).competeGlobally, isTrue);
    expect(out.copyWith(displayName: 'S').competeGlobally, isFalse);
  });
}
