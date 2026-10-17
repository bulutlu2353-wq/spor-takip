/// Seri ve görevlerin girdisi (O4 spec §5).
class GameSettings {
  const GameSettings({required this.weeklyGoal, this.userId});

  /// Haftalık antrenman hedefi; dinlenme hakkı `7 − weeklyGoal`.
  final int weeklyGoal;

  /// Görev tohumu; null → görev yok.
  final String? userId;
}

const defaultWeeklyGoal = 3;
const minWeeklyGoal = 2;
const maxWeeklyGoal = 6;

/// Program → profil → 3; `[2, 6]`'ya sıkıştırılır (O4 spec §3.1).
int weeklyGoalFor({int? programDays, int? profileDays}) =>
    (programDays ?? profileDays ?? defaultWeeklyGoal).clamp(minWeeklyGoal, maxWeeklyGoal);
