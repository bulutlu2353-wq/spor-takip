/// Kullanıcı adı kuralı (S1 spec §3.1): 3–20 karakter, a–z, 0–9, _.
enum UsernameProblem { tooShort, tooLong, invalidCharacters }

final _allowed = RegExp(r'^[a-z0-9_]+$');

/// Boşluklar kırpılır, küçük harfe çevrilir, baştaki '@' atılır.
String normalizeUsername(String raw) {
  final lower = raw.trim().toLowerCase();
  return lower.startsWith('@') ? lower.substring(1) : lower;
}

UsernameProblem? checkUsername(String normalized) {
  if (normalized.length < 3) return UsernameProblem.tooShort;
  if (normalized.length > 20) return UsernameProblem.tooLong;
  if (!_allowed.hasMatch(normalized)) return UsernameProblem.invalidCharacters;
  return null;
}
