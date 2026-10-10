import '../../gamification/domain/levels.dart';
import 'player_stats.dart';
import 'public_profile.dart';

/// Topluluk fonksiyonunun hata kodu (S2 spec §5); ekran koda göre metin gösterir.
class CommunityException implements Exception {
  const CommunityException(this.code);

  final String code;

  @override
  String toString() => 'CommunityException($code)';
}

/// Sunucunun `raise exception` ile döndürdüğü, metni olan kodlar.
const communityErrorCodes = {
  'community_limit',
  'community_full',
  'banned',
  'not_public',
  'unknown_code',
  'no_profile',
  'not_owner',
};

/// Kişi başı topluluk sınırı (S2 spec §2.7).
const maxCommunities = 5;

class Community {
  const Community({
    required this.id,
    required this.name,
    required this.description,
    required this.isPublic,
    required this.inviteCode,
    required this.owner,
  });

  final String id;
  final String name;
  final String description;
  final bool isPublic;
  final String inviteCode;
  final String owner;

  factory Community.fromJson(Map<String, dynamic> json) => Community(
        id: json['id'] as String,
        name: json['name'] as String,
        description: json['description'] as String? ?? '',
        isPublic: json['is_public'] as bool? ?? true,
        inviteCode: json['invite_code'] as String? ?? '',
        owner: json['owner'] as String,
      );

  Community copyWith({String? name, String? description, bool? isPublic, String? inviteCode}) => Community(
        id: id,
        name: name ?? this.name,
        description: description ?? this.description,
        isPublic: isPublic ?? this.isPublic,
        inviteCode: inviteCode ?? this.inviteCode,
        owner: owner,
      );
}

class CommunityMember {
  const CommunityMember({
    required this.communityId,
    required this.userId,
    required this.isOwner,
    required this.joinedAt,
  });

  final String communityId;
  final String userId;
  final bool isOwner;
  final DateTime joinedAt;

  factory CommunityMember.fromJson(Map<String, dynamic> json) => CommunityMember(
        communityId: json['community_id'] as String,
        userId: json['user_id'] as String,
        isOwner: json['role'] == 'owner',
        joinedAt: DateTime.parse(json['joined_at'] as String).toLocal(),
      );
}

/// `search_communities` satırı.
class CommunitySearchResult {
  const CommunitySearchResult({
    required this.id,
    required this.name,
    required this.description,
    required this.memberCount,
    required this.isMember,
  });

  final String id;
  final String name;
  final String description;
  final int memberCount;
  final bool isMember;

  factory CommunitySearchResult.fromJson(Map<String, dynamic> json) => CommunitySearchResult(
        id: json['id'] as String,
        name: json['name'] as String,
        description: json['description'] as String? ?? '',
        memberCount: (json['member_count'] as num?)?.toInt() ?? 0,
        isMember: json['is_member'] as bool? ?? false,
      );
}

/// `global_titles` satırı: bir kategorinin (eşitlikte birden çok) sahibi.
class GlobalTitle {
  const GlobalTitle({
    required this.category,
    required this.userId,
    required this.username,
    required this.displayName,
    required this.level,
    required this.rank,
    required this.value,
  });

  final String category;
  final String userId;
  final String username;
  final String displayName;
  final int level;
  final Rank rank;
  final double value;

  factory GlobalTitle.fromJson(Map<String, dynamic> json) => GlobalTitle(
        category: json['category'] as String,
        userId: json['user_id'] as String,
        username: json['username'] as String,
        displayName: json['display_name'] as String,
        level: (json['level'] as num?)?.toInt() ?? 1,
        rank: Rank.values.asNameMap()[json['rank']] ?? Rank.rookie,
        value: (json['value'] as num?)?.toDouble() ?? 0,
      );
}

/// `global_leaderboard` satırı.
class GlobalRow {
  const GlobalRow({
    required this.position,
    required this.userId,
    required this.username,
    required this.displayName,
    required this.level,
    required this.rank,
    required this.xp,
    this.activeTitle,
  });

  final int position;
  final String userId;
  final String username;
  final String displayName;
  final int level;
  final Rank rank;
  final SharedTitle? activeTitle;
  final int xp;

  String get initials => initialsOf(displayName, username);

  factory GlobalRow.fromJson(Map<String, dynamic> json) {
    final active = json['active_title'] as Map<String, dynamic>?;
    return GlobalRow(
      position: (json['position'] as num).toInt(),
      userId: json['user_id'] as String,
      username: json['username'] as String,
      displayName: json['display_name'] as String,
      level: (json['level'] as num?)?.toInt() ?? 1,
      rank: Rank.values.asNameMap()[json['rank']] ?? Rank.rookie,
      activeTitle: active == null ? null : SharedTitle.fromJson(active),
      xp: (json['xp'] as num?)?.toInt() ?? 0,
    );
  }
}
