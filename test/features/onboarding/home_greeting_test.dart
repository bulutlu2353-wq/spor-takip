import 'package:flutter_test/flutter_test.dart';
import 'package:spor_takip/features/onboarding/domain/home_greeting.dart';

void main() {
  test('greeting follows the hour of the day', () {
    expect(greetingKey(DateTime(2026, 10, 3, 4, 59)), 'home.greeting_evening');
    expect(greetingKey(DateTime(2026, 10, 3, 5)), 'home.greeting_morning');
    expect(greetingKey(DateTime(2026, 10, 3, 11, 59)), 'home.greeting_morning');
    expect(greetingKey(DateTime(2026, 10, 3, 12)), 'home.greeting_day');
    expect(greetingKey(DateTime(2026, 10, 3, 17, 59)), 'home.greeting_day');
    expect(greetingKey(DateTime(2026, 10, 3, 18)), 'home.greeting_evening');
  });
}
