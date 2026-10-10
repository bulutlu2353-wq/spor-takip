/// Avatar baş harfleri: ilk iki kelimenin baş harfi, tek kelimede ilk iki harf;
/// görünen ad boşsa kullanıcı adından.
String initialsOf(String displayName, String username) {
  final words = displayName.trim().split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();
  final source = words.isEmpty ? username : words.first;
  final letters = words.length >= 2
      ? '${words[0].substring(0, 1)}${words[1].substring(0, 1)}'
      : source.substring(0, source.length < 2 ? source.length : 2);
  return letters.toUpperCase();
}

/// Sosyal kimlik (S1 spec §3.1). Arkadaşların satırında da gizlilik bayrakları gelir.
class PublicProfile {
  const PublicProfile({
    required this.userId,
    required this.username,
    required this.displayName,
    required this.inviteCode,
    this.shareWeekly = true,
    this.shareWorkouts = true,
    this.shareHeat = true,
    this.competeGlobally = true,
  });

  final String userId;
  final String username;
  final String displayName;
  final String inviteCode;
  final bool shareWeekly;
  final bool shareWorkouts;
  final bool shareHeat;

  /// Genel sıralamada ve genel unvanlarda yer alır (S2 spec §2.6).
  final bool competeGlobally;

  String get initials => initialsOf(displayName, username);

  factory PublicProfile.fromJson(Map<String, dynamic> json) => PublicProfile(
        userId: json['user_id'] as String,
        username: json['username'] as String,
        displayName: json['display_name'] as String,
        inviteCode: json['invite_code'] as String? ?? '',
        shareWeekly: json['share_weekly'] as bool? ?? true,
        shareWorkouts: json['share_workouts'] as bool? ?? true,
        shareHeat: json['share_heat'] as bool? ?? true,
        competeGlobally: json['compete_globally'] as bool? ?? true,
      );

  PublicProfile copyWith({
    String? username,
    String? displayName,
    bool? shareWeekly,
    bool? shareWorkouts,
    bool? shareHeat,
    bool? competeGlobally,
  }) =>
      PublicProfile(
        userId: userId,
        username: username ?? this.username,
        displayName: displayName ?? this.displayName,
        inviteCode: inviteCode,
        shareWeekly: shareWeekly ?? this.shareWeekly,
        shareWorkouts: shareWorkouts ?? this.shareWorkouts,
        shareHeat: shareHeat ?? this.shareHeat,
        competeGlobally: competeGlobally ?? this.competeGlobally,
      );
}

/// `find_user` / `find_user_by_invite` satırı.
class FoundUser {
  const FoundUser({required this.userId, required this.username, required this.displayName});

  final String userId;
  final String username;
  final String displayName;

  String get initials => initialsOf(displayName, username);

  factory FoundUser.fromJson(Map<String, dynamic> json) => FoundUser(
        userId: json['user_id'] as String,
        username: json['username'] as String,
        displayName: json['display_name'] as String,
      );
}
