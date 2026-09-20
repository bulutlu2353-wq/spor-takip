const _loginPath = '/login';
const _registerPath = '/register';
const _onboardingPath = '/onboarding';
const _homePath = '/home';

/// go_router'ın `redirect` callback'i için saf karar fonksiyonu.
/// Yönlendirme gerekmiyorsa null döner (kullanıcı olduğu yerde kalır).
String? computeRedirect({
  required bool isLoggedIn,
  required bool hasProfile,
  required String location,
}) {
  final isAuthRoute = location == _loginPath || location == _registerPath;

  if (!isLoggedIn) {
    return isAuthRoute ? null : _loginPath;
  }
  if (!hasProfile) {
    return location == _onboardingPath ? null : _onboardingPath;
  }
  if (isAuthRoute || location == _onboardingPath) {
    return _homePath;
  }
  return null;
}
