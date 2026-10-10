import '../../workout/domain/exercise_taxonomy.dart';
import 'period_keys.dart';
import 'period_stats.dart';

/// Unvan kategorileri gösterim sırasıyla: genel XP ("Yıldız") ve 17 kas.
const periodCategories = <String>['xp', ...muscleGroups];

class Standing {
  const Standing({required this.userId, required this.xp, required this.position});

  final String userId;
  final int xp;

  /// 1'den; eşit XP aynı sıra (1, 2, 2, 4).
  final int position;
}

/// Dönem XP'si > 0 olanlar, büyükten küçüğe; eşitlikte userId sırası.
List<Standing> standings(Map<String, PeriodStats> members, PeriodKind kind, String key) {
  final rows = [
    for (final MapEntry(key: id, value: stats) in members.entries)
      if (stats.valueFor(kind, key, 'xp').toInt() case final xp when xp > 0) (id: id, xp: xp),
  ]..sort((a, b) {
      final byXp = b.xp.compareTo(a.xp);
      return byXp != 0 ? byXp : a.id.compareTo(b.id);
    });
  final result = <Standing>[];
  for (var i = 0; i < rows.length; i++) {
    final position = i > 0 && rows[i].xp == rows[i - 1].xp ? result[i - 1].position : i + 1;
    result.add(Standing(userId: rows[i].id, xp: rows[i].xp, position: position));
  }
  return result;
}

class PeriodTitle {
  const PeriodTitle({required this.category, required this.holders, required this.value});

  /// 'xp' ya da kas adı.
  final String category;

  /// Eşitlikte birden çok; userId sırasıyla.
  final List<String> holders;
  final double value;
}

/// Kategori başına en yüksek değer (> 0) ve sahipleri; [periodCategories] sırasıyla.
List<PeriodTitle> periodTitles(Map<String, PeriodStats> members, PeriodKind kind, String key) {
  final result = <PeriodTitle>[];
  for (final category in periodCategories) {
    var best = 0.0;
    final holders = <String>[];
    for (final MapEntry(key: id, value: stats) in members.entries) {
      final value = stats.valueFor(kind, key, category);
      if (value <= 0 || value < best) continue;
      if (value > best) {
        best = value;
        holders.clear();
      }
      holders.add(id);
    }
    if (holders.isNotEmpty) result.add(PeriodTitle(category: category, holders: holders..sort(), value: best));
  }
  return result;
}
