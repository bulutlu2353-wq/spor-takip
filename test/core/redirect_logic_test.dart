import 'package:flutter_test/flutter_test.dart';
import 'package:spor_takip/core/redirect_logic.dart';

void main() {
  group('computeRedirect', () {
    test('sends logged-out users to /login from anywhere except auth routes', () {
      expect(
        computeRedirect(
          isLoggedIn: false,
          profileState: ProfileState.absent,
          location: '/home',
        ),
        '/login',
      );
      expect(
        computeRedirect(
          isLoggedIn: false,
          profileState: ProfileState.absent,
          location: '/onboarding',
        ),
        '/login',
      );
    });

    test('does not redirect logged-out users already on /login or /register', () {
      expect(
        computeRedirect(
          isLoggedIn: false,
          profileState: ProfileState.absent,
          location: '/login',
        ),
        isNull,
      );
      expect(
        computeRedirect(
          isLoggedIn: false,
          profileState: ProfileState.absent,
          location: '/register',
        ),
        isNull,
      );
    });

    test('sends logged-in users without a profile to /onboarding', () {
      expect(
        computeRedirect(
          isLoggedIn: true,
          profileState: ProfileState.absent,
          location: '/home',
        ),
        '/onboarding',
      );
      expect(
        computeRedirect(
          isLoggedIn: true,
          profileState: ProfileState.absent,
          location: '/login',
        ),
        '/onboarding',
      );
    });

    test('does not redirect logged-in profile-less users already on /onboarding', () {
      expect(
        computeRedirect(
          isLoggedIn: true,
          profileState: ProfileState.absent,
          location: '/onboarding',
        ),
        isNull,
      );
    });

    test('sends fully set-up users away from auth/onboarding routes to /home', () {
      expect(
        computeRedirect(
          isLoggedIn: true,
          profileState: ProfileState.present,
          location: '/login',
        ),
        '/home',
      );
      expect(
        computeRedirect(
          isLoggedIn: true,
          profileState: ProfileState.present,
          location: '/onboarding',
        ),
        '/home',
      );
    });

    test('does not redirect fully set-up users already on /home', () {
      expect(
        computeRedirect(
          isLoggedIn: true,
          profileState: ProfileState.present,
          location: '/home',
        ),
        isNull,
      );
    });

    test('does not move logged-in users while profile is still loading', () {
      expect(
        computeRedirect(
          isLoggedIn: true,
          profileState: ProfileState.loading,
          location: '/login',
        ),
        isNull,
      );
      expect(
        computeRedirect(
          isLoggedIn: true,
          profileState: ProfileState.loading,
          location: '/home',
        ),
        isNull,
      );
    });

    test('sends logged-in users to /home on a profile fetch error, but leaves them on /home', () {
      expect(
        computeRedirect(
          isLoggedIn: true,
          profileState: ProfileState.error,
          location: '/onboarding',
        ),
        '/home',
      );
      expect(
        computeRedirect(
          isLoggedIn: true,
          profileState: ProfileState.error,
          location: '/home',
        ),
        isNull,
      );
    });

    test('logged-out check wins regardless of profile state', () {
      expect(
        computeRedirect(
          isLoggedIn: false,
          profileState: ProfileState.loading,
          location: '/home',
        ),
        '/login',
      );
    });
  });
}
