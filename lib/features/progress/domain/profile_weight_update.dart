import '../../onboarding/domain/profile.dart';
import '../../onboarding/domain/tdee_calculator.dart';

/// Profilin kilo ve hedef alanlarına yazılacak değerler (RPC parametreleri).
class ProfileWeightUpdate {
  const ProfileWeightUpdate({
    required this.weightKg,
    required this.calorieTarget,
    required this.proteinTargetG,
  });

  final double weightKg;
  final double calorieTarget;
  final double proteinTargetG;
}

/// [profile]'in diğer alanlarıyla [weightKg] için hedefleri yeniden hesaplar;
/// formül yalnızca [TdeeCalculator]'da kalır.
ProfileWeightUpdate profileWeightUpdate(
  Profile profile,
  double weightKg, {
  required int currentYear,
  TdeeCalculator calculator = const TdeeCalculator(),
}) {
  final result = calculator.calculate(
    weightKg: weightKg,
    heightCm: profile.heightCm,
    birthYear: profile.birthYear,
    currentYear: currentYear,
    gender: profile.gender,
    activityLevel: profile.activityLevel,
    weightDirection: profile.weightDirection,
    pace: profile.pace,
    focuses: profile.focuses,
    adjustmentKcal: profile.calorieAdjustmentKcal,
  );
  return ProfileWeightUpdate(
    weightKg: weightKg,
    calorieTarget: result.calorieTarget,
    proteinTargetG: result.proteinTargetG,
  );
}
