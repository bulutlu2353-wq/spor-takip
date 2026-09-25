import 'package:flutter_test/flutter_test.dart';
import 'package:spor_takip/features/workout/domain/weight_calculator.dart';

void main() {
  test('returns null when either input is missing', () {
    expect(targetWeightKg(oneRepMaxKg: null, percent1rm: 80), isNull);
    expect(targetWeightKg(oneRepMaxKg: 100, percent1rm: null), isNull);
  });

  test('multiplies and rounds to the nearest 2.5 kg', () {
    expect(targetWeightKg(oneRepMaxKg: 100, percent1rm: 76.5), 77.5); // 76.5 → 77.5
    expect(targetWeightKg(oneRepMaxKg: 100, percent1rm: 58.5), 57.5); // 58.5 → 57.5
    expect(targetWeightKg(oneRepMaxKg: 140, percent1rm: 85.5), 120.0); // 119.7 → 120
    expect(targetWeightKg(oneRepMaxKg: 60, percent1rm: 50), 30.0);
  });
}
