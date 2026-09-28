import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../onboarding/application/profile_providers.dart';
import '../../onboarding/domain/profile.dart';
import '../../workout/application/session_providers.dart';
import '../data/body_weight_repository.dart';
import '../domain/body_weight_log.dart';
import '../domain/profile_weight_update.dart';
import '../domain/progress_format.dart';
import 'progress_providers.dart';

final bodyWeightServiceProvider = Provider<BodyWeightService>(BodyWeightService.new);

/// Kilo kaydı/silme: profildeki kilo ve hedefleri tutarlı tutar (spec §3).
class BodyWeightService {
  BodyWeightService(this._ref);

  final Ref _ref;

  BodyWeightRepository get _repo => _ref.read(bodyWeightRepositoryProvider);

  /// Profil ve sunucudaki güncel liste (servis kararlarını eski önbelleğe dayandırmaz).
  Future<(Profile, List<BodyWeightLog>)> _context() async {
    final (profile, logs) = await (_ref.read(profileProvider.future), _repo.fetchLogs()).wait;
    if (profile == null) throw StateError('Profil yok');
    return (profile, logs);
  }

  ProfileWeightUpdate _update(Profile profile, double weightKg) =>
      profileWeightUpdate(profile, weightKg, currentYear: _ref.read(nowProvider)().year);

  /// [date] gününe [weightKg] yazar. Kayıt en yeniyse (ya da ilkse) profil
  /// güncellenir ve yeni kalori hedefi döner; geçmiş tarihliyse null.
  Future<double?> log({required DateTime date, required double weightKg}) async {
    final day = dateOnly(date);
    final (profile, logs) = await _context();
    final isLatest = logs.isEmpty || !day.isBefore(logs.last.date);
    final update = _update(profile, weightKg);
    await _repo.logWeight(date: day, update: update);
    _ref.invalidate(weightLogsProvider);
    if (!isLatest) return null;
    _ref.invalidate(profileProvider);
    return update.calorieTarget;
  }

  /// [date] günündeki kaydı siler; en yeniyse profil bir önceki kayda göre
  /// güncellenir. Tek kayıtsa [LastWeightLogException].
  Future<void> delete(DateTime date) async {
    final day = dateOnly(date);
    final (profile, logs) = await _context();
    if (logs.length <= 1) throw LastWeightLogException();
    final isLatest = logs.last.date == day;
    final newLatest = isLatest ? _update(profile, logs[logs.length - 2].weightKg) : null;
    try {
      await _repo.deleteLog(date: day, newLatest: newLatest);
    } finally {
      _ref.invalidate(weightLogsProvider);
    }
    if (isLatest) _ref.invalidate(profileProvider);
  }
}

/// Onboarding sonunda profildeki kiloyu ilk kilo kaydı olarak yazar
/// (hedefler profille aynı olduğu için değişmez).
Future<void> recordInitialWeight(BodyWeightRepository repo, Profile profile, DateTime now) {
  return repo.logWeight(
    date: dateOnly(now),
    update: ProfileWeightUpdate(
      weightKg: profile.weightKg,
      calorieTarget: profile.dailyCalorieTarget,
      proteinTargetG: profile.dailyProteinTargetG,
    ),
  );
}
