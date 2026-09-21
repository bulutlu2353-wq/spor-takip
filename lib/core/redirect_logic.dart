const _loginPath = '/login';
const _registerPath = '/register';
const _onboardingPath = '/onboarding';
const _homePath = '/home';

/// [profileProvider]'ın çözümlenme durumunu yansıtan durum.
///
/// `bool hasProfile` yerine kullanılır çünkü tek bir bool, "yükleniyor",
/// "profil yok" ve "profil çekilirken hata oluştu" durumlarını hepsini
/// `false`'a düşürüp birbirine karıştırıyordu.
enum ProfileState { loading, present, absent, error }

/// go_router'ın `redirect` callback'i için saf karar fonksiyonu.
/// Yönlendirme gerekmiyorsa null döner (kullanıcı olduğu yerde kalır).
String? computeRedirect({
  required bool isLoggedIn,
  required ProfileState profileState,
  required String location,
}) {
  final isAuthRoute = location == _loginPath || location == _registerPath;

  if (!isLoggedIn) {
    return isAuthRoute ? null : _loginPath;
  }
  switch (profileState) {
    case ProfileState.loading:
      // Profil hâlâ çözümleniyor; ne olduğunu bilene kadar kullanıcıyı
      // taşıma — her soğuk başlangıçta onboarding'in kısa süre
      // görünmesini (flash) önler.
      return null;
    case ProfileState.error:
      // /home'un profileAsync.error dalını (home.load_error) göstermesine
      // izin ver; profil çekme hatasında sessizce onboarding'e yönlendirip
      // mevcut profilin üzerine yazılma riskini almayalım.
      return location == _homePath ? null : _homePath;
    case ProfileState.absent:
      return location == _onboardingPath ? null : _onboardingPath;
    case ProfileState.present:
      return (isAuthRoute || location == _onboardingPath) ? _homePath : null;
  }
}
