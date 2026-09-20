import 'package:flutter_test/flutter_test.dart';
import 'package:spor_takip/core/redirect_logic.dart';

void main() {
  group('computeRedirect', () {
    test('sends logged-out users to /login from anywhere except auth routes', () {
      expect(
        computeRedirect(isLoggedIn: false, hasProfile: false, location: '/home'),
        '/login',
      );
      expect(
        computeRedirect(isLoggedIn: false, hasProfile: false, location: '/onboarding'),
        '/login',
      );
    });

    test('does not redirect logged-out users already on /login or /register', () {
      expect(computeRedirect(isLoggedIn: false, hasProfile: false, location: '/login'), isNull);
      expect(computeRedirect(isLoggedIn: false, hasProfile: false, location: '/register'), isNull);
    });

    test('sends logged-in users without a profile to /onboarding', () {
      expect(
        computeRedirect(isLoggedIn: true, hasProfile: false, location: '/home'),
        '/onboarding',
      );
      expect(
        computeRedirect(isLoggedIn: true, hasProfile: false, location: '/login'),
        '/onboarding',
      );
    });

    test('does not redirect logged-in profile-less users already on /onboarding', () {
      expect(
        computeRedirect(isLoggedIn: true, hasProfile: false, location: '/onboarding'),
        isNull,
      );
    });

    test('sends fully set-up users away from auth/onboarding routes to /home', () {
      expect(computeRedirect(isLoggedIn: true, hasProfile: true, location: '/login'), '/home');
      expect(
        computeRedirect(isLoggedIn: true, hasProfile: true, location: '/onboarding'),
        '/home',
      );
    });

    test('does not redirect fully set-up users already on /home', () {
      expect(computeRedirect(isLoggedIn: true, hasProfile: true, location: '/home'), isNull);
    });
  });
}
