# F5+ R4b — Giriş/Kayıt, Onboarding ve Antrenör Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Giriş/kayıt ekranlarını ortalanmış logo düzenine, onboarding sihirbazını parçalı adım çubuğu + ikonlu seçim kartları + büyük sayı düzenine, antrenör tanıtım ekranını başlık + özellik kutuları düzenine geçirmek ve sohbet ekranını neon temaya uydurmak.

**Architecture:** Yalnız sunum katmanı değişir. Yeni `AuthHeader` bileşeni iki giriş ekranında ortak kullanılır. Sihirbazın tüm adımları `step_scaffolds.dart`'taki iskeletlerden geçtiği için değişikliklerin çoğu orada; adım tanımlarına yalnız ikon ve birim eklenir. Antrenör tarafında `coach_screen.dart` ve `message_bubble.dart` yeniden stillenir. Provider, servis, akış ve kayıt mantığı değişmez.

**Tech Stack:** Flutter, Riverpod 3, easy_localization, go_router, flutter_test.

**Spec:** `docs/superpowers/specs/2026-10-06-f5plus-r4b-giris-koc-design.md` (çerçeve: `docs/superpowers/specs/2026-10-03-f5plus-r1-tasarim-temeli-design.md` §3–§4)

## Global Constraints

- Düşük bellekli makine: görev içinde sadece ilgili test dosyaları çalıştırılır (`flutter test --no-pub <dosyalar>`). Tam paketi kullanıcı kendi terminalinde çalıştırır (`flutter test --no-pub -j 1`, Task 4). `flutter analyze --no-pub` birkaç dakika sürebilir; gerekirse arka planda çalıştır.
- `flutter analyze --no-pub` "No issues found!" vermeli (info dahil). `dart format` çalıştırılmaz (projede satır genişliği ayarı yok; dosyaları 80 sütuna göre yeniden sarar), mevcut biçime elle uyulur.
- Widget testlerinde `.tr()` çıktısına güvenilmez (testte çeviriler yüklenmeyebilir, ham anahtar görünür). Bulma işi `Key`, ikon ya da testin kendi verdiği metinle yapılır.
- Ekran/bileşen kodunda elle renk (`Color(0x…)`, `Colors.x`) yazılmaz. Renkler `Theme.of(context).colorScheme`'den: vurgu = `primary`, vurgu üstü yazı = `onPrimary`, ana metin = `onSurface`, ikincil metin = `onSurfaceVariant`, kart zemini (`AppColors.surface`) = `surfaceContainer`, çizgi (`AppColors.line`) = `outlineVariant`. Testlerde beklenen renkler `AppColors.accent`, `AppColors.surface`, `AppColors.line`.
- Başlık yazı tipi `AppFonts.heading` (`lib/core/theme/app_fonts.dart`). Büyük harfe çevirme yalnız `upperCaseFor(text, Localizations.localeOf(context).languageCode)` ile (`lib/shared/text_case.dart`).
- Korunan anahtarlar (testler kullanıyor): `login_screen`, `login_email_field`, `login_password_field`, `login_submit_button`, `login_google_button`, `login_go_to_register_button`, `register_screen`, `register_email_field`, `register_password_field`, `register_confirm_password_field`, `register_submit_button`, `onboarding_screen`, `wizard_next_button`, `numeric_step_field`, `text_step_field`, `choice_option_<değer>`, `coach_locked`, `coach_input`, `coach_send`, `coach_suggestion_<i>`, `coach_menu`, `coach_clear`, `coach_clear_confirm`, `coach_typing`, `coach_unsent_text`, `coach_send_error`, `coach_retry`, `coach_remaining`, `coach_reload`, `bubble_<id>`, `confirm_card_*`.
- Çeviri dosyaları (`assets/translations/tr.json`, `en.json`) UTF-8; düzenlemeyi Edit aracıyla yap, PowerShell `Set-Content` kullanma.
- Commit mesajları İngilizce, `feat(auth): …` / `feat(onboarding): …` / `feat(coach): …` biçiminde. Sonuna boş satır + `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`.

## Spec'ten küçük netleştirmeler (kullanıcıya bildirilecek)

1. `AuthHeader` başlığı parametre olarak alır (`title`, `tagline`); ekranlar `'app.title'.tr()` geçirir. Böylece test, çeviri yüklenmese de "SPOR / TAKİP" ayrımını doğrulayabilir.
2. Sayı alanı içeriğe göre değil sabit 220 genişlikte; ipucu metni (ör. "0-7 arası bir sayı") 56px'e sığmadığından `bodyLarge` boyutunda gri gösterilir. Yazılan sayı 56px Montserrat 900.
3. Antrenör özellik kutuları `GridView` + sabit en/boy oranı yerine `IntrinsicHeight` satırlarıyla dizilir (2 sütun × 3 satır); uzun İngilizce metinlerde dar ekranda taşma olmaz, görünüm aynı.
4. Notun sol neon çizgisi tek kenarlık olduğu için köşe yuvarlama `ClipRRect` ile yapılır (Flutter tek kenarlı `Border` ile `borderRadius`'a izin vermez).

## Dosya Haritası

```
lib/features/onboarding/presentation/widgets/auth_header.dart        # Task 1 (yeni)
lib/features/onboarding/presentation/login_screen.dart               # Task 1
lib/features/onboarding/presentation/register_screen.dart            # Task 1
lib/features/onboarding/presentation/steps/step_scaffolds.dart       # Task 2
lib/features/onboarding/presentation/steps/onboarding_step_widgets.dart  # Task 2
lib/features/onboarding/presentation/onboarding_wizard_screen.dart   # Task 2
lib/features/chat/presentation/coach_screen.dart                     # Task 3
lib/features/chat/presentation/widgets/message_bubble.dart           # Task 3
assets/translations/tr.json, en.json                                 # Task 1, 2, 3
PLAN.md                                                              # Task 4

test/features/onboarding/presentation/auth_screens_test.dart         # Task 1 (yeni)
test/features/onboarding/presentation/steps/step_scaffolds_test.dart # Task 2
test/features/chat/presentation/coach_screen_test.dart               # Task 3
```

---

### Task 1: `AuthHeader`, giriş ve kayıt ekranları

**Files:**
- Create: `lib/features/onboarding/presentation/widgets/auth_header.dart`
- Modify: `lib/features/onboarding/presentation/login_screen.dart` (`build`, importlar)
- Modify: `lib/features/onboarding/presentation/register_screen.dart` (`build`, importlar)
- Modify: `assets/translations/tr.json`, `assets/translations/en.json` (`auth` bloğu)
- Test: `test/features/onboarding/presentation/auth_screens_test.dart` (yeni)

**Interfaces:**
- Consumes: `testApp`, `initTestLocalization` (`test/features/progress/presentation/test_app.dart`); `upperCaseFor`; `AppFonts.heading`; `AppColors`.
- Produces: `AuthHeader({Key? key, required String title, required String tagline})`; anahtarlar `auth_header`, `auth_header_title`, `auth_header_tagline`, `auth_or_divider`.

- [ ] **Step 1: Write the failing tests**

`test/features/onboarding/presentation/auth_screens_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spor_takip/core/theme/app_colors.dart';
import 'package:spor_takip/features/onboarding/presentation/login_screen.dart';
import 'package:spor_takip/features/onboarding/presentation/register_screen.dart';
import 'package:spor_takip/features/onboarding/presentation/widgets/auth_header.dart';

import '../../progress/presentation/test_app.dart';

void main() {
  setUpAll(initTestLocalization);

  testWidgets('AuthHeader shows the first title word plain and the rest in the accent', (tester) async {
    await tester.pumpWidget(testApp(const AuthHeader(title: 'Spor Takip', tagline: 'Slogan')));
    await tester.pumpAndSettle();

    final title = tester.widget<Text>(find.byKey(const Key('auth_header_title')));
    final spans = (title.textSpan! as TextSpan).children!.cast<TextSpan>();
    expect(spans.first.text, 'SPOR');
    expect(spans.last.text, anyOf(' TAKİP', ' TAKIP'));
    expect(spans.last.style!.color, AppColors.accent);
    expect(find.text('Slogan'), findsOneWidget);
  });

  testWidgets('login screen shows the header, the or divider and a filled submit button', (tester) async {
    await tester.pumpWidget(testApp(const LoginScreen(), scaffold: false));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('auth_header')), findsOneWidget);
    expect(find.byKey(const Key('auth_or_divider')), findsOneWidget);
    expect(find.byKey(const Key('login_google_button')), findsOneWidget);
    expect(find.byKey(const Key('login_go_to_register_button')), findsOneWidget);
    expect(tester.widget(find.byKey(const Key('login_submit_button'))), isA<FilledButton>());
  });

  testWidgets('register screen shows the header and a filled submit button', (tester) async {
    await tester.pumpWidget(testApp(const RegisterScreen(), scaffold: false));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('auth_header')), findsOneWidget);
    expect(find.byKey(const Key('register_confirm_password_field')), findsOneWidget);
    expect(tester.widget(find.byKey(const Key('register_submit_button'))), isA<FilledButton>());
  });
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `flutter test --no-pub test/features/onboarding/presentation/auth_screens_test.dart`
Expected: FAIL — derleme hatası (`auth_header.dart` yok).

- [ ] **Step 3: Create `AuthHeader`**

`lib/features/onboarding/presentation/widgets/auth_header.dart`:

```dart
import 'package:flutter/material.dart';

import '../../../../core/theme/app_fonts.dart';
import '../../../../shared/text_case.dart';

/// Giriş/kayıt ekranlarının üstü (spec §3.1): neon "S" logosu, büyük harfli
/// uygulama adı (ilk kelime beyaz, kalanı neon) ve slogan.
class AuthHeader extends StatelessWidget {
  const AuthHeader({super.key, required this.title, required this.tagline});

  final String title;
  final String tagline;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final upper = upperCaseFor(title, Localizations.localeOf(context).languageCode);
    final space = upper.indexOf(' ');
    final first = space < 0 ? upper : upper.substring(0, space);
    final rest = space < 0 ? '' : upper.substring(space);
    return Column(
      key: const Key('auth_header'),
      children: [
        Container(
          width: 56,
          height: 56,
          alignment: Alignment.center,
          decoration: BoxDecoration(color: scheme.primary, borderRadius: BorderRadius.circular(16)),
          child: Text(
            'S',
            style: TextStyle(fontFamily: AppFonts.heading, fontWeight: FontWeight.w900, fontSize: 30, color: scheme.onPrimary),
          ),
        ),
        const SizedBox(height: 16),
        Text.rich(
          key: const Key('auth_header_title'),
          TextSpan(
            style: TextStyle(
              fontFamily: AppFonts.heading,
              fontWeight: FontWeight.w900,
              fontSize: 26,
              letterSpacing: 1,
              color: scheme.onSurface,
            ),
            children: [
              TextSpan(text: first),
              if (rest.isNotEmpty) TextSpan(text: rest, style: TextStyle(color: scheme.primary)),
            ],
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 6),
        Text(
          tagline,
          key: const Key('auth_header_tagline'),
          textAlign: TextAlign.center,
          style: theme.textTheme.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
        ),
      ],
    );
  }
}
```

- [ ] **Step 4: Rewrite `LoginScreen.build`**

`login_screen.dart` importlarına ekle: `import 'widgets/auth_header.dart';`

`build` metodunun tamamını şununla değiştir, dosyanın sonuna `_OrDivider` ekle:

```dart
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: const Key('login_screen'),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  AuthHeader(title: 'app.title'.tr(), tagline: 'auth.login_tagline'.tr()),
                  const SizedBox(height: 32),
                  TextField(
                    key: const Key('login_email_field'),
                    controller: _emailController,
                    keyboardType: TextInputType.emailAddress,
                    decoration: InputDecoration(labelText: 'auth.email_label'.tr()),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    key: const Key('login_password_field'),
                    controller: _passwordController,
                    obscureText: true,
                    decoration: InputDecoration(labelText: 'auth.password_label'.tr()),
                  ),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: _isSubmitting ? null : _forgotPassword,
                      child: Text('auth.forgot_password'.tr()),
                    ),
                  ),
                  if (_errorMessage != null) ...[
                    Text(
                      _errorMessage!,
                      style: TextStyle(color: Theme.of(context).colorScheme.error),
                    ),
                    const SizedBox(height: 12),
                  ],
                  const SizedBox(height: 8),
                  FilledButton(
                    key: const Key('login_submit_button'),
                    onPressed: _isSubmitting ? null : _submit,
                    child: _isSubmitting
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Text('auth.login_button'.tr()),
                  ),
                  const _OrDivider(),
                  OutlinedButton.icon(
                    key: const Key('login_google_button'),
                    onPressed: _isSubmitting ? null : _signInWithGoogle,
                    icon: const Icon(Icons.login),
                    label: Text('auth.google_sign_in'.tr()),
                  ),
                  const SizedBox(height: 16),
                  TextButton(
                    key: const Key('login_go_to_register_button'),
                    onPressed: () => context.push('/register'),
                    child: Text('auth.go_to_register'.tr()),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Şifreli giriş ile Google girişi arasındaki "veya" ayracı.
class _OrDivider extends StatelessWidget {
  const _OrDivider();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      key: const Key('auth_or_divider'),
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Row(
        children: [
          const Expanded(child: Divider()),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Text(
              'auth.or'.tr(),
              style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
          ),
          const Expanded(child: Divider()),
        ],
      ),
    );
  }
}
```

(Dikkat: eski `build`'in kapanışındaki `}` sınıfı kapatıyordu; yukarıdaki blokta sınıfın kapanışı `_OrDivider`'dan önceki `}` ile yapılır. Sınıfın sonunda fazladan `}` kalmamalı.)

- [ ] **Step 5: Rewrite `RegisterScreen.build`**

`register_screen.dart` importlarına ekle: `import 'widgets/auth_header.dart';`

`build` metodunu şununla değiştir:

```dart
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: const Key('register_screen'),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  AuthHeader(title: 'app.title'.tr(), tagline: 'auth.register_tagline'.tr()),
                  const SizedBox(height: 32),
                  TextField(
                    key: const Key('register_email_field'),
                    controller: _emailController,
                    keyboardType: TextInputType.emailAddress,
                    decoration: InputDecoration(labelText: 'auth.email_label'.tr()),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    key: const Key('register_password_field'),
                    controller: _passwordController,
                    obscureText: true,
                    decoration: InputDecoration(labelText: 'auth.password_label'.tr()),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    key: const Key('register_confirm_password_field'),
                    controller: _confirmPasswordController,
                    obscureText: true,
                    decoration: InputDecoration(labelText: 'auth.confirm_password_label'.tr()),
                  ),
                  if (_errorMessage != null) ...[
                    const SizedBox(height: 12),
                    Text(
                      _errorMessage!,
                      style: TextStyle(color: Theme.of(context).colorScheme.error),
                    ),
                  ],
                  const SizedBox(height: 24),
                  FilledButton(
                    key: const Key('register_submit_button'),
                    onPressed: _isSubmitting ? null : _submit,
                    child: _isSubmitting
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Text('auth.register_button'.tr()),
                  ),
                  const SizedBox(height: 16),
                  TextButton(
                    onPressed: () => context.pop(),
                    child: Text('auth.go_to_login'.tr()),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
```

- [ ] **Step 6: Translations**

`tr.json` `auth` bloğunda:
- `"login_title": "Giriş Yap",` satırını sil.
- `"register_title": "Kayıt Ol",` satırını sil.
- `"google_sign_in": "Google ile giriş yap"` satırını şununla değiştir:

```json
    "google_sign_in": "Google ile giriş yap",
    "login_tagline": "Beslenme · Antrenman · İlerleme",
    "register_tagline": "Hesabını oluştur",
    "or": "veya"
```

`en.json` `auth` bloğunda aynı iki satırı sil ve `"google_sign_in": "Google ile giriş yap"` satırını şununla değiştir (mevcut değer olduğu gibi kalır):

```json
    "google_sign_in": "Google ile giriş yap",
    "login_tagline": "Nutrition · Training · Progress",
    "register_tagline": "Create your account",
    "or": "or"
```

Silinen anahtarların başka kullanımı olmadığını doğrula: `login_title|register_title` için `lib/` ve `test/` içinde arama → sonuç yok.

- [ ] **Step 7: Run tests to verify they pass**

Run: `flutter test --no-pub test/features/onboarding/presentation/auth_screens_test.dart test/widget_test.dart`
Expected: PASS (4 test).

- [ ] **Step 8: Analyze**

Run: `flutter analyze --no-pub`
Expected: "No issues found!"

- [ ] **Step 9: Commit**

```bash
git add lib/features/onboarding/presentation/widgets/auth_header.dart lib/features/onboarding/presentation/login_screen.dart lib/features/onboarding/presentation/register_screen.dart assets/translations/tr.json assets/translations/en.json test/features/onboarding/presentation/auth_screens_test.dart
git commit -m "feat(auth): redesign login and register with centered logo header

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 2: Onboarding sihirbazı

**Files:**
- Modify: `lib/features/onboarding/presentation/steps/step_scaffolds.dart` (tamamı)
- Modify: `lib/features/onboarding/presentation/steps/onboarding_step_widgets.dart` (seçenek listeleri, birimler)
- Modify: `lib/features/onboarding/presentation/onboarding_wizard_screen.dart:83` (hata ekranı butonu)
- Modify: `assets/translations/tr.json`, `en.json` (`onboarding.days_unit`)
- Test: `test/features/onboarding/presentation/steps/step_scaffolds_test.dart`

**Interfaces:**
- Consumes: `AppTheme.dark()`, `AppColors`, `AppFonts.heading`, `upperCaseFor`.
- Produces: `ChoiceStepScreen.options` tipi `List<(T value, String label, IconData icon)>`; `NumericStepScreen` yeni isteğe bağlı `String? unit`; anahtarlar `wizard_step_segments`, `wizard_segment_<i>`, `wizard_step_label`, `numeric_step_unit`.

- [ ] **Step 1: Update existing tests and add failing ones**

`step_scaffolds_test.dart`:
1. Importlara ekle:

```dart
import 'package:spor_takip/core/theme/app_colors.dart';
import 'package:spor_takip/core/theme/app_theme.dart';
```

2. `wrap` içindeki `MaterialApp(home: child)` → `MaterialApp(theme: AppTheme.dark(), home: child)`.
3. Dosyadaki tüm `tester.widget<ElevatedButton>(` → `tester.widget<FilledButton>(` (6 yer).
4. `ChoiceStepScreen` testindeki seçenekler: `options: const [('a', 'Seçenek A', Icons.star), ('b', 'Seçenek B', Icons.star_border)],`.
5. Dosyanın sonuna (son `}`'dan önce) ekle:

```dart
  testWidgets('step bar has one segment per step and lights done and current ones', (tester) async {
    await tester.pumpWidget(
      wrap(
        NumericStepScreen(
          title: 'Test',
          hintText: 'Değer gir',
          min: 20,
          max: 300,
          initialValue: null,
          unit: 'kg',
          onSave: (_) {},
          onNext: () {},
          onBack: null,
          stepNumber: 2,
          totalSteps: 5,
        ),
      ),
    );
    await tester.pumpAndSettle();

    Color segmentColor(int i) =>
        (tester.widget<Container>(find.byKey(Key('wizard_segment_$i'))).decoration! as BoxDecoration).color!;
    for (var i = 0; i < 5; i++) {
      expect(find.byKey(Key('wizard_segment_$i')), findsOneWidget);
    }
    expect(find.byKey(const Key('wizard_segment_5')), findsNothing);
    expect(segmentColor(1), AppColors.accent);
    expect(segmentColor(2), AppColors.line);
    expect(tester.widget<Text>(find.byKey(const Key('wizard_step_label'))).style!.color, AppColors.accent);
    expect(tester.widget<Text>(find.byKey(const Key('numeric_step_unit'))).data, 'kg');
  });

  testWidgets('ChoiceStepScreen: only the selected card shows a check mark', (tester) async {
    await tester.pumpWidget(
      wrap(
        ChoiceStepScreen<String>(
          title: 'Test',
          options: const [('a', 'Seçenek A', Icons.star), ('b', 'Seçenek B', Icons.star_border)],
          selected: 'b',
          onSave: (_) {},
          onNext: () {},
          onBack: null,
          stepNumber: 1,
          totalSteps: 1,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.check_circle), findsOneWidget);
    expect(
      find.descendant(of: find.byKey(const Key('choice_option_b')), matching: find.byIcon(Icons.check_circle)),
      findsOneWidget,
    );
    expect(find.byIcon(Icons.star), findsOneWidget);
  });
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `flutter test --no-pub test/features/onboarding/presentation/steps/step_scaffolds_test.dart`
Expected: FAIL — derleme hatası (`unit` parametresi yok, seçenek kaydı 3 alanlı değil).

- [ ] **Step 3: Rewrite `step_scaffolds.dart`**

1. Importları şöyle yap:

```dart
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../../../../core/theme/app_fonts.dart';
import '../../../../shared/text_case.dart';
```

2. `WizardStepScaffold.build`'i şununla değiştir ve sınıftan sonra `_StepSegments` ekle:

```dart
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final stepLabel = 'onboarding.step_of'.tr(namedArgs: {
      'current': stepNumber.toString(),
      'total': totalSteps.toString(),
    });
    return Scaffold(
      appBar: AppBar(
        leading: onBack == null
            ? null
            : IconButton(icon: const Icon(Icons.arrow_back), onPressed: onBack),
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _StepSegments(current: stepNumber, total: totalSteps),
            const SizedBox(height: 12),
            Text(
              upperCaseFor(stepLabel, Localizations.localeOf(context).languageCode),
              key: const Key('wizard_step_label'),
              style: theme.textTheme.labelMedium?.copyWith(
                color: scheme.primary,
                fontFamily: AppFonts.heading,
                fontWeight: FontWeight.w800,
                letterSpacing: 1,
              ),
            ),
            const SizedBox(height: 12),
            Text(title, style: theme.textTheme.headlineMedium),
            const SizedBox(height: 24),
            Expanded(child: child),
            FilledButton(
              key: const Key('wizard_next_button'),
              onPressed: isValid ? onNext : null,
              child: Text(nextLabel ?? 'onboarding.next'.tr()),
            ),
          ],
        ),
      ),
    );
  }
}

/// Her adım için bir parça; tamamlanan ve şu anki adımlar neon (spec §4.1).
class _StepSegments extends StatelessWidget {
  const _StepSegments({required this.current, required this.total});

  final int current;
  final int total;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Row(
      key: const Key('wizard_step_segments'),
      children: [
        for (var i = 0; i < total; i++) ...[
          if (i > 0) const SizedBox(width: 4),
          Expanded(
            child: Container(
              key: Key('wizard_segment_$i'),
              height: 4,
              decoration: BoxDecoration(
                color: i < current ? scheme.primary : scheme.outlineVariant,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
        ],
      ],
    );
  }
}
```

3. `NumericStepScreen`: kurucuya `this.unit,` ekle (`required this.totalSteps,` satırından sonra), alanlara `final String? unit;` ekle. `_NumericStepScreenState.build`'i şununla değiştir:

```dart
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return WizardStepScaffold(
      title: widget.title,
      stepNumber: widget.stepNumber,
      totalSteps: widget.totalSteps,
      isValid: _isValid,
      onBack: widget.onBack,
      onNext: () {
        widget.onSave(_value!);
        widget.onNext();
      },
      child: Center(
        child: Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            SizedBox(
              width: 220,
              child: TextField(
                key: const Key('numeric_step_field'),
                controller: _controller,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                textAlign: TextAlign.center,
                style: const TextStyle(fontFamily: AppFonts.heading, fontWeight: FontWeight.w900, fontSize: 56),
                decoration: InputDecoration.collapsed(
                  hintText: widget.hintText,
                  hintStyle: theme.textTheme.bodyLarge?.copyWith(color: scheme.onSurfaceVariant),
                ),
                onChanged: (text) => setState(() => _value = double.tryParse(text)),
              ),
            ),
            if (widget.unit != null) ...[
              const SizedBox(width: 8),
              Text(
                widget.unit!,
                key: const Key('numeric_step_unit'),
                style: theme.textTheme.titleLarge?.copyWith(color: scheme.onSurfaceVariant),
              ),
            ],
          ],
        ),
      ),
    );
  }
```

4. `ChoiceStepScreen`: alan tipini `final List<(T value, String label, IconData icon)> options;` yap. `build` içindeki `child: RadioGroup<T>(...)` bloğunun tamamını şununla değiştir, dosyaya `_ChoiceCard` ekle (`ChoiceStepScreen` sınıfından sonra):

```dart
      child: ListView.separated(
        itemCount: options.length,
        separatorBuilder: (context, index) => const SizedBox(height: 10),
        itemBuilder: (context, index) {
          final (value, label, icon) = options[index];
          return _ChoiceCard(
            key: Key('choice_option_$value'),
            label: label,
            icon: icon,
            selected: value == selected,
            onTap: () => onSave(value),
          );
        },
      ),
```

```dart
/// İkonlu seçim kartı; seçiliyse neon kenarlık ve onay işareti (spec §4.2).
class _ChoiceCard extends StatelessWidget {
  const _ChoiceCard({
    super.key,
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    const radius = BorderRadius.all(Radius.circular(16));
    return Material(
      color: scheme.surfaceContainer,
      shape: RoundedRectangleBorder(
        borderRadius: radius,
        side: selected ? BorderSide(color: scheme.primary, width: 2) : BorderSide(color: scheme.outlineVariant),
      ),
      child: InkWell(
        customBorder: const RoundedRectangleBorder(borderRadius: radius),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Icon(icon, color: scheme.primary),
              const SizedBox(width: 14),
              Expanded(
                child: Text(label, style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
              ),
              if (selected) Icon(Icons.check_circle, color: scheme.primary),
            ],
          ),
        ),
      ),
    );
  }
}
```

- [ ] **Step 4: Step definitions (`onboarding_step_widgets.dart`)**

- `WeightStep`: `NumericStepScreen(` içine `unit: 'kg',` ekle (`max: 300,` satırından sonra).
- `HeightStep`: `unit: 'cm',` ekle (`max: 250,` satırından sonra).
- `ExerciseDaysStep`: `unit: 'onboarding.days_unit'.tr(),` ekle (`max: 7,` satırından sonra).
- `BirthYearStep`: değişmez (birimsiz).
- Seçenek listeleri:

```dart
      options: [
        (Gender.male, 'onboarding.gender_male'.tr(), Icons.male),
        (Gender.female, 'onboarding.gender_female'.tr(), Icons.female),
        (Gender.unspecified, 'onboarding.gender_unspecified'.tr(), Icons.person_outline),
      ],
```

```dart
      options: [
        (ActivityLevel.sedentary, 'onboarding.activity_sedentary'.tr(), Icons.weekend_outlined),
        (ActivityLevel.light, 'onboarding.activity_light'.tr(), Icons.directions_walk),
        (ActivityLevel.moderate, 'onboarding.activity_moderate'.tr(), Icons.directions_run),
        (ActivityLevel.active, 'onboarding.activity_active'.tr(), Icons.fitness_center),
        (ActivityLevel.veryActive, 'onboarding.activity_very_active'.tr(), Icons.bolt),
      ],
```

```dart
      options: [
        (true, 'onboarding.yes'.tr(), Icons.check),
        (false, 'onboarding.no'.tr(), Icons.close),
      ],
```

```dart
      options: [
        (Goal.loseWeight, 'onboarding.goal_lose_weight'.tr(), Icons.trending_down),
        (Goal.gainMuscle, 'onboarding.goal_gain_muscle'.tr(), Icons.fitness_center),
        (Goal.maintain, 'onboarding.goal_maintain'.tr(), Icons.balance),
      ],
```

- [ ] **Step 5: Wizard save-error button**

`onboarding_wizard_screen.dart` hata ekranında:

```dart
              ElevatedButton(onPressed: _finish, child: Text('onboarding.retry'.tr())),
```

→

```dart
              const SizedBox(height: 12),
              FilledButton(onPressed: _finish, child: Text('onboarding.retry'.tr())),
```

- [ ] **Step 6: Translations**

`tr.json` `onboarding` bloğunda `"exercise_days_hint": "0-7 arası bir sayı",` satırından sonra ekle:

```json
    "days_unit": "gün",
```

`en.json` aynı yerde (aynı `exercise_days_hint` satırından sonra):

```json
    "days_unit": "days",
```

- [ ] **Step 7: Run tests to verify they pass**

Run: `flutter test --no-pub test/features/onboarding/`
Expected: PASS (step_scaffolds 7 test + domain/application + Task 1 auth testleri).

- [ ] **Step 8: Analyze**

Run: `flutter analyze --no-pub`
Expected: "No issues found!"

- [ ] **Step 9: Commit**

```bash
git add lib/features/onboarding/presentation/steps/step_scaffolds.dart lib/features/onboarding/presentation/steps/onboarding_step_widgets.dart lib/features/onboarding/presentation/onboarding_wizard_screen.dart assets/translations/tr.json assets/translations/en.json test/features/onboarding/presentation/steps/step_scaffolds_test.dart
git commit -m "feat(onboarding): add segmented step bar, icon choice cards and big number input

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 3: Antrenör tanıtım ekranı ve sohbet restili

**Files:**
- Modify: `lib/features/chat/presentation/coach_screen.dart` (`_CoachLocked`, `_Suggestions`, `_InputBar`, importlar)
- Modify: `lib/features/chat/presentation/widgets/message_bubble.dart`
- Modify: `assets/translations/tr.json`, `en.json` (`coach` bloğu)
- Test: `test/features/chat/presentation/coach_screen_test.dart`

**Interfaces:**
- Consumes: `AppColors`, `AppFonts.heading`, `upperCaseFor`; test yardımcıları `userMessage`, `assistantMessage` (`test/features/chat/fixtures.dart`).
- Produces: anahtarlar `coach_locked_badge`, `coach_locked_title`, `coach_feature_<0..5>`.

- [ ] **Step 1: Write the failing tests**

`coach_screen_test.dart` importlarına ekle: `import 'package:spor_takip/core/theme/app_colors.dart';`

Mevcut `'disabled coach shows the in-development screen and never loads the chat'` testinin sonuna (`expect(repo.loadCount, 0);` satırından sonra) ekle:

```dart
    expect(find.byKey(const Key('coach_locked_badge')), findsOneWidget);
    expect(find.byKey(const Key('coach_locked_title')), findsOneWidget);
    for (var i = 0; i < 6; i++) {
      expect(find.byKey(Key('coach_feature_$i')), findsOneWidget);
    }
```

Dosyanın sonuna (son `}`'dan önce) ekle:

```dart
  testWidgets('user bubbles use the accent, assistant bubbles the card surface', (tester) async {
    await pumpScreen(tester, messages: [userMessage('selam'), assistantMessage(null, content: 'merhaba')]);

    BoxDecoration decorationOf(String key) =>
        tester.widget<Container>(find.byKey(Key(key))).decoration! as BoxDecoration;
    expect(decorationOf('bubble_u1').color, AppColors.accent);
    expect(decorationOf('bubble_a1').color, AppColors.surface);
  });
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `flutter test --no-pub test/features/chat/presentation/coach_screen_test.dart`
Expected: FAIL — `coach_locked_badge` bulunamaz; kullanıcı balonu rengi `AppColors.surfaceHigh` (`primaryContainer`).

- [ ] **Step 3: Rewrite `_CoachLocked` and add `_FeatureTile`**

`coach_screen.dart` importlarına ekle:

```dart
import '../../../core/theme/app_fonts.dart';
import '../../../shared/text_case.dart';
```

`_CoachLocked.build`'i şununla değiştir ve sınıftan sonra `_FeatureTile` ekle:

```dart
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final languageCode = Localizations.localeOf(context).languageCode;
    final titleLines = upperCaseFor('coach.locked_title'.tr(), languageCode).split('\n');
    return Scaffold(
      appBar: AppBar(title: Text('coach.title'.tr())),
      body: Center(
        child: SingleChildScrollView(
          key: const Key('coach_locked'),
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  key: const Key('coach_locked_badge'),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(color: scheme.primary, borderRadius: BorderRadius.circular(8)),
                  child: Text(
                    upperCaseFor('coach.locked_badge'.tr(), languageCode),
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: scheme.onPrimary,
                      fontFamily: AppFonts.heading,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                // İkinci satır neon (maketteki "ANTRENÖRÜN"); satırlar çeviride \n ile ayrılır.
                Text.rich(
                  key: const Key('coach_locked_title'),
                  TextSpan(
                    style: theme.textTheme.headlineMedium?.copyWith(
                      fontFamily: AppFonts.heading,
                      fontWeight: FontWeight.w900,
                      height: 1.05,
                    ),
                    children: [
                      for (var i = 0; i < titleLines.length; i++)
                        TextSpan(
                          text: i < titleLines.length - 1 ? '${titleLines[i]}\n' : titleLines[i],
                          style: TextStyle(color: i == 1 ? scheme.primary : scheme.onSurface),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  'coach.locked_body'.tr(),
                  style: theme.textTheme.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
                ),
                const SizedBox(height: 20),
                for (var row = 0; row < _lockedFeatures.length; row += 2) ...[
                  if (row > 0) const SizedBox(height: 10),
                  IntrinsicHeight(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        for (var i = row; i < row + 2 && i < _lockedFeatures.length; i++) ...[
                          if (i > row) const SizedBox(width: 10),
                          Expanded(
                            child: _FeatureTile(
                              key: Key('coach_feature_$i'),
                              icon: _lockedFeatures[i].$1,
                              text: _lockedFeatures[i].$2.tr(),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 20),
                ClipRRect(
                  borderRadius: const BorderRadius.horizontal(right: Radius.circular(8)),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: scheme.surfaceContainer,
                      border: Border(left: BorderSide(color: scheme.primary, width: 3)),
                    ),
                    child: Text(
                      'coach.locked_note'.tr(),
                      style: theme.textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _FeatureTile extends StatelessWidget {
  const _FeatureTile({super.key, required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainer,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 22, color: theme.colorScheme.primary),
          const SizedBox(height: 8),
          Text(text, style: theme.textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
```

(Dikkat: yukarıdaki blok `_CoachLocked`'ın kapanış `}`'ını içerir ve `_FeatureTile`'ın kapanış `}`'ı ile biter; eski `_CoachLocked` sınıf kapanışı yerinde kalmalı, fazladan/eksik `}` olmamalı.)

- [ ] **Step 4: Suggestions and input bar**

`_Suggestions.build` içinde:
- `const Icon(Icons.forum_outlined, size: 48),` → `Icon(Icons.forum_outlined, size: 48, color: Theme.of(context).colorScheme.primary),`
- `ActionChip(...)` bloğunu şununla değiştir:

```dart
                  _SuggestionChip(
                    key: Key('coach_suggestion_$i'),
                    label: _suggestions[i].tr(),
                    onTap: () => onTap(_suggestions[i].tr()),
                  ),
```

`_Suggestions` sınıfından sonra ekle:

```dart
/// Neon kenarlı öneri çipi; seçili durumu yok (AccentChip filtre çipi olduğu için kullanılmaz).
class _SuggestionChip extends StatelessWidget {
  const _SuggestionChip({super.key, required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    const radius = BorderRadius.all(Radius.circular(20));
    return Material(
      color: theme.colorScheme.surface,
      shape: RoundedRectangleBorder(borderRadius: radius, side: BorderSide(color: theme.colorScheme.primary)),
      child: InkWell(
        customBorder: const RoundedRectangleBorder(borderRadius: radius),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          child: Text(label, style: theme.textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w600)),
        ),
      ),
    );
  }
}
```

`_InputBar.build` içindeki `Padding`'i şununla değiştir:

```dart
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
        child: Row(
          children: [
            Expanded(
              child: TextField(
                key: const Key('coach_input'),
                controller: controller,
                enabled: enabled,
                minLines: 1,
                maxLines: 4,
                textInputAction: TextInputAction.send,
                onSubmitted: (_) => onSend(),
                decoration: InputDecoration(hintText: 'coach.input_hint'.tr()),
              ),
            ),
            const SizedBox(width: 8),
            IconButton.filled(
              key: const Key('coach_send'),
              icon: const Icon(Icons.arrow_upward),
              onPressed: enabled ? onSend : null,
            ),
          ],
        ),
      ),
```

- [ ] **Step 5: Message bubble**

`message_bubble.dart` içinde `Container(...)` bloğunu şununla değiştir:

```dart
              Container(
                key: Key('bubble_${message.id}'),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: isUser ? scheme.primary : scheme.surfaceContainer,
                  border: isUser ? null : Border.all(color: scheme.outlineVariant),
                  // Konuşan tarafın alt köşesi sivri (spec §5.2).
                  borderRadius: BorderRadius.only(
                    topLeft: const Radius.circular(16),
                    topRight: const Radius.circular(16),
                    bottomLeft: Radius.circular(isUser ? 16 : 4),
                    bottomRight: Radius.circular(isUser ? 4 : 16),
                  ),
                ),
                child: Text(
                  message.content,
                  style: TextStyle(color: isUser ? scheme.onPrimary : scheme.onSurface),
                ),
              ),
```

- [ ] **Step 6: Translations**

`tr.json` `coach` bloğunda:

```json
    "locked_badge": "Geliştirme aşamasında",
    "locked_body": "Yapay zekâ antrenörün yakında burada olacak. Sohbet ederek şunları yapabileceksin:",
```

→

```json
    "locked_badge": "Geliştirme aşamasında",
    "locked_title": "Yapay zekâ\nantrenörün\nyakında.",
    "locked_body": "Sohbet ederek şunları yapabileceksin:",
```

`en.json` `coach` bloğunda:

```json
    "locked_badge": "In development",
    "locked_body": "Your AI coach is coming soon. By chatting you'll be able to:",
```

→

```json
    "locked_badge": "In development",
    "locked_title": "Your AI\ncoach is\ncoming soon.",
    "locked_body": "By chatting you'll be able to:",
```

- [ ] **Step 7: Run tests to verify they pass**

Run: `flutter test --no-pub test/features/chat/`
Expected: PASS (coach_screen 12 test + confirm_card ve diğer chat testleri).

- [ ] **Step 8: Analyze**

Run: `flutter analyze --no-pub`
Expected: "No issues found!"

- [ ] **Step 9: Commit**

```bash
git add lib/features/chat/presentation/coach_screen.dart lib/features/chat/presentation/widgets/message_bubble.dart assets/translations/tr.json assets/translations/en.json test/features/chat/presentation/coach_screen_test.dart
git commit -m "feat(coach): redesign locked intro and restyle chat bubbles and input

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 4: Doğrulama, elle kontrol ve PLAN.md

**Files:**
- Modify: `PLAN.md`

- [ ] **Step 1: Analyze**

Run: `flutter analyze --no-pub`
Expected: "No issues found!"

- [ ] **Step 2: Full test suite (user's terminal)**

Kullanıcıdan kendi terminalinde çalıştırmasını iste:

```
flutter test --no-pub -j 1
```

Expected: `All tests passed!`. Toplam test sayısını not et (R4a sonunda +398; R4b net artışı +6: auth 3, onboarding 2, sohbet balonu 1; kilitli ekran kontrolleri mevcut teste eklendi → +404).

- [ ] **Step 3: Release web build + manual check (user's terminal)**

Kullanıcıdan: `flutter build web --release --no-pub`, ardından `build\web` klasöründen `python -m http.server 5555 --bind 127.0.0.1` ve tarayıcıda önbelleği temizleyerek açması (yeni çeviriler). Elle kontrol listesi (oturumu kapatıp başlamak gerekir):

1. Giriş: ortada neon "S" kare, "SPOR TAKİP" (TAKİP neon), slogan; e-posta/şifre, sağda "Şifremi unuttum", neon "Giriş Yap", "veya" ayracı, Google butonu, en altta kayıt bağlantısı.
2. Giriş: yanlış şifre hatası görünüyor; "Şifremi unuttum" boş e-postada uyarı veriyor; giriş çalışıyor.
3. Kayıt: aynı başlık + "Hesabını oluştur"; üç alan, neon "Kayıt Ol", girişe dön bağlantısı çalışıyor.
4. Dar pencerede (telefon genişliği) ve klavye açıkken giriş/kayıt formu kayıyor, taşma yok; geniş pencerede form 420 genişliği geçmiyor.
5. Onboarding (yeni hesap ya da profili olmayan kullanıcı): üstte parçalı neon çubuk + "ADIM x/y"; geri/ileri çalışıyor, çubuk ilerliyor.
6. Onboarding sayı adımları: büyük ortalı sayı; kiloda "kg", boyda "cm", gün sayısında "gün"; aralık dışı değerde İleri pasif.
7. Onboarding seçim adımları: ikonlu kartlar, seçilende neon kenarlık + ✓; spor yapmıyorum seçilince spor türü/gün adımları atlanıyor; Bitir ile ana sayfaya geçiş.
8. Antrenör sekmesi: neon "GELİŞTİRME AŞAMASINDA" rozeti, 3 satırlık başlık (ortadaki satır neon), kısa açıklama, 2×3 özellik kutuları, sol neon çizgili not; dar ekranda taşma yok.

(Sohbet ekranı kilitli olduğundan elle kontrol edilmez; widget testleri kapsar.)

- [ ] **Step 4: PLAN.md row and commit**

`PLAN.md` dosyasındaki tarihçe tablosunun son satırının altına (CRLF satır sonu) ekle:

```
| <tarih> | **F5+ R4b (giriş/kayıt, onboarding, antrenör) tamamlandı — F5+ görsel yenileme bitti** (`r4b-giris-koc` dalı, 4 görev). Giriş/kayıt ortalanmış logo düzeninde (`AuthHeader`: neon "S", "SPOR TAKİP", slogan; "veya" ayracı). Onboarding: parçalı neon adım çubuğu, "ADIM x/y", ikonlu seçim kartları, büyük ortalı sayı + birim (kg/cm/gün). Antrenör tanıtımı: neon rozet, 3 satırlık başlık, 2×3 özellik kutuları; sohbet: neon kullanıcı balonu, kart AI balonu, neon gönder butonu (sekme hâlâ kilitli). Davranış değişmedi; `auth.login_title`/`register_title` kaldırıldı. Otomatik: <N> Flutter testi geçiyor (kullanıcının terminalinde `-j 1`), `flutter analyze` temiz. Manuel: <sonuç>. Sıradaki: F5+ 2. alt proje (kas haritası). |
```

`<tarih>`, `<N>` ve `<sonuç>` yerine gerçek değerleri yaz.

```bash
git add PLAN.md
git commit -m "docs: record F5+ R4b verification

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

- [ ] **Step 5: Finish the branch**

superpowers:finishing-a-development-branch becerisiyle devam et (R1–R4a'da: yerelde master'a fast-forward, dal silindi, kullanıcı onayıyla push).
