# F5+ R1 — Tasarım Temeli ve Ana Sayfa Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Uygulamaya koyu + neon yeşil tema, gömülü Montserrat/Inter yazı tipleri ve ortak bileşenler eklemek; ana sayfayı "halka + kutucuklar" düzenine geçirmek.

**Architecture:** Tek `AppTheme.dark()` (`lib/core/theme/`) `MaterialApp.router`'a verilir; uygulamada elle renk olmadığı için tüm ekranlar temadan boyanır. `lib/shared/widgets/` altında yalnız temaya bağlı küçük bileşenler (`SectionHeader`, `StatTile`, `RingProgress`, `MacroBar`). Ana sayfa mevcut provider'ları (`todayMealsProvider`, `weightLogsProvider`, `weeklySummaryProvider`, `strengthCardProvider`, `measurementsProvider`) yeni kartlarla gösterir; veri/iş mantığı değişmez.

**Tech Stack:** Flutter (Material 3), flutter_riverpod 3, go_router, easy_localization, fl_chart 1.2.0.

**Spec:** `docs/superpowers/specs/2026-10-03-f5plus-r1-tasarim-temeli-design.md`

## Global Constraints

- Dal: `r1-tasarim-temeli` (master'dan açıldı, spec commit'i üstünde).
- Tüm `flutter` komutları `--no-pub` ile (`pub get` bu makinede ağda takılıyor). **Yeni paket eklenmez.**
- Düşük bellekli makine: görev içinde yalnız ilgili test dosyaları; tam paket (`flutter test --no-pub`, ~6 dk) yalnız Task 8'de.
- `flutter analyze --no-pub` "No issues found!" vermeli (info dahil). Her `await`'ten sonra `context` kullanmadan önce `context.mounted` kontrolü.
- Widget testlerinde `.tr()` çıktısına güvenilmez (çeviri testte yüklenmeyebilir); bulma `Key`, ikon veya veri metniyle yapılır.
- "Şimdi"ye bağlı kod `nowProvider`'ı (`lib/features/workout/application/session_providers.dart`) kullanır.
- Ekran/bileşen kodunda elle renk (`Color(0x…)`, `Colors.x`) yazılmaz; yalnız `lib/core/theme/` içinde. Bileşenler renkleri `Theme.of(context).colorScheme`'den alır: vurgu = `primary`, ikincil metin = `onSurfaceVariant`, çizgi/boş çubuk = `outlineVariant`, kutu zemini = `surfaceContainer`, hata/aşım = `error`.
- Renkler (spec §4.1): background `#0E0F12`, surface `#181A20`, line `#262830`, text `#F2F3F5`, muted `#8A8F98`, accent `#C6FF00`, onAccent `#0E0F12`, error `#FF5C5C`.
- Yazı tipleri: başlık `Montserrat` (800, 900), gövde `Inter` (400, 600).
- Büyük harfe çevirme yalnız `upperCaseFor(text, languageCode)` ile (Türkçe i/İ, ı/I). Butonlar büyük harfe çevrilmez (bkz. "Spec'ten sapmalar").
- Davranış değişmez: veri, kayıt, Supabase, yönlendirme aynı; yalnız ana sayfa düzeni yeni.
- Commit mesajları İngilizce, `feat(theme): …` / `feat(home): …` biçiminde; sonuna `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`.

## Spec'ten sapmalar (kullanıcıya bildirilecek)

1. **Buton metinleri büyük harfe çevrilmez.** Flutter'da tema düzeyinde "text-transform" yok; her butonda `.toUpperCase()` hem 30+ dosyaya dokunur hem Türkçede `i → I` hatası yapar. Butonlar Montserrat 800 + harf aralığıyla "kalın" görünür. Bölüm başlıkları ve kutu etiketleri `upperCaseFor` ile büyük harf olur.
2. **Kilo kutusunda "olumlu" yön kullanıcının amacına göre:** kilo verme → düşüş yeşil; kas kazanma → artış yeşil; formda kalma → renk yok. (Spec "düşüş olumlu" diyordu; kas kazanan kullanıcıya kilo artışını gri, düşüşü yeşil göstermek yanıltıcı olurdu.) Bel için düşüş olumlu kalır.
3. **Yazı tipi dosyaları ≈ 1,5 MB** (spec ≈ 1 MB diyordu): Google Fonts'un tam karakter setli statik TTF'leri (Türkçe karakterler dahil).

## Dosya Haritası

```
assets/fonts/                                   # Task 1: 4 TTF + 2 lisans
lib/core/theme/app_colors.dart                  # Task 1
lib/core/theme/app_fonts.dart                   # Task 1
lib/core/theme/app_theme.dart                   # Task 1
lib/core/theme/chart_style.dart                 # Task 4
lib/shared/text_case.dart                       # Task 1 (upperCaseFor)
lib/shared/widgets/section_header.dart          # Task 2
lib/shared/widgets/stat_tile.dart               # Task 2
lib/shared/widgets/ring_progress.dart           # Task 3
lib/shared/widgets/macro_bar.dart               # Task 3
lib/features/nutrition/presentation/widgets/today_nutrition_card.dart   # Task 5
lib/features/onboarding/domain/home_greeting.dart                       # Task 6
lib/features/progress/presentation/widgets/home_stat_grid.dart          # Task 6
lib/features/onboarding/presentation/home_screen.dart   # Task 7 (yeniden yazılır)
lib/main.dart                                   # Task 1 (theme)
lib/features/progress/presentation/widgets/progress_line_chart.dart     # Task 4
pubspec.yaml                                    # Task 1 (fonts)
assets/translations/{tr,en}.json                # Task 5 (home anahtarları)
test/core/theme/app_theme_test.dart             # Task 1
test/shared/text_case_test.dart                 # Task 1
test/shared/widgets/themed.dart                 # Task 2 (test yardımcısı)
test/shared/widgets/stat_tile_test.dart         # Task 2
test/shared/widgets/ring_progress_test.dart     # Task 3
test/shared/widgets/macro_bar_test.dart         # Task 3
test/features/progress/presentation/progress_line_chart_test.dart       # Task 4
test/features/nutrition/presentation/today_nutrition_card_test.dart     # Task 5
test/features/progress/presentation/home_stat_grid_test.dart            # Task 6
test/features/onboarding/home_greeting_test.dart                        # Task 6
test/features/onboarding/presentation/home_screen_test.dart             # Task 7
Silinir (Task 7): lib/features/progress/presentation/widgets/{targets_card,body_weight_card,strength_card,measurements_card}.dart
Değişir (Task 7): test/features/progress/presentation/{home_cards_test,weight_test,strength_test,measurements_test}.dart
```

---

### Task 1: Tema temeli (renkler, yazı tipleri, `AppTheme.dark()`)

**Files:**
- Create: `assets/fonts/Montserrat-ExtraBold.ttf`, `assets/fonts/Montserrat-Black.ttf`, `assets/fonts/Inter-Regular.ttf`, `assets/fonts/Inter-SemiBold.ttf`, `assets/fonts/OFL-Montserrat.txt`, `assets/fonts/OFL-Inter.txt`
- Create: `lib/core/theme/app_colors.dart`, `lib/core/theme/app_fonts.dart`, `lib/core/theme/app_theme.dart`, `lib/shared/text_case.dart`
- Modify: `pubspec.yaml` (`flutter:` altına `fonts:`), `lib/main.dart:43-49`, `test/features/progress/presentation/test_app.dart` (tema)
- Test: `test/core/theme/app_theme_test.dart`, `test/shared/text_case_test.dart`

**Interfaces:**
- Produces: `AppColors.{background,surface,line,text,muted,accent,onAccent,error}` (`Color` sabitleri); `AppFonts.heading == 'Montserrat'`, `AppFonts.body == 'Inter'`; `ThemeData AppTheme.dark()`; `String upperCaseFor(String text, String languageCode)`.
- ColorScheme eşlemesi (sonraki görevler bunlara dayanır): `primary=accent`, `onPrimary=onAccent`, `surface=background`, `onSurface=text`, `surfaceContainer=surface`, `surfaceContainerHigh=#1F2128`, `onSurfaceVariant=muted`, `outlineVariant=line`, `error=error`.

- [ ] **Step 1: Yazı tiplerini indir**

```bash
cd /d/spor_takip && mkdir -p assets/fonts && cd assets/fonts && \
curl -sSfL --max-time 120 -o Inter-Regular.ttf https://fonts.gstatic.com/s/inter/v20/UcCO3FwrK3iLTeHuS_nVMrMxCp50SjIw2boKoduKmMEVuLyfMZg.ttf && \
curl -sSfL --max-time 120 -o Inter-SemiBold.ttf https://fonts.gstatic.com/s/inter/v20/UcCO3FwrK3iLTeHuS_nVMrMxCp50SjIw2boKoduKmMEVuGKYMZg.ttf && \
curl -sSfL --max-time 120 -o Montserrat-ExtraBold.ttf https://fonts.gstatic.com/s/montserrat/v31/JTUHjIg1_i6t8kCHKm4532VJOt5-QNFgpCvr70w-.ttf && \
curl -sSfL --max-time 120 -o Montserrat-Black.ttf https://fonts.gstatic.com/s/montserrat/v31/JTUHjIg1_i6t8kCHKm4532VJOt5-QNFgpCvC70w-.ttf && \
curl -sSfL --max-time 60 -o OFL-Montserrat.txt https://raw.githubusercontent.com/JulietaUla/Montserrat/master/OFL.txt && \
curl -sSfL --max-time 60 -o OFL-Inter.txt https://raw.githubusercontent.com/google/fonts/main/ofl/inter/OFL.txt && ls -l
```

Expected: 6 dosya; her `.ttf` 250 KB'tan büyük (tam karakter seti). URL'ler `https://fonts.googleapis.com/css2?family=Inter:wght@400;600&family=Montserrat:wght@800;900` adresinden (tarayıcı başlığı olmadan istenince TTF döner) alındı; 404 verirse aynı adresi `curl -sS` ile tekrar isteyip yeni URL'leri kullan.

- [ ] **Step 2: `pubspec.yaml`'a yazı tiplerini ekle**

`flutter:` bölümünde, `assets:` listesinden sonra (aynı girinti, 2 boşluk):

```yaml
  fonts:
    - family: Montserrat
      fonts:
        - asset: assets/fonts/Montserrat-ExtraBold.ttf
          weight: 800
        - asset: assets/fonts/Montserrat-Black.ttf
          weight: 900
    - family: Inter
      fonts:
        - asset: assets/fonts/Inter-Regular.ttf
          weight: 400
        - asset: assets/fonts/Inter-SemiBold.ttf
          weight: 600
```

(Dosyanın sonundaki yorum satırlı `# fonts:` örneğine dokunma.)

- [ ] **Step 3: Failing testleri yaz**

`test/shared/text_case_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:spor_takip/shared/text_case.dart';

void main() {
  test('turkish upper case keeps the dotted and dotless i apart', () {
    expect(upperCaseFor('cuma, 3 ekim', 'tr'), 'CUMA, 3 EKİM');
    expect(upperCaseFor('ılık iğne', 'tr'), 'ILIK İĞNE');
  });

  test('other languages use the default upper case', () {
    expect(upperCaseFor('friday, 3 october', 'en'), 'FRIDAY, 3 OCTOBER');
  });
}
```

`test/core/theme/app_theme_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spor_takip/core/theme/app_colors.dart';
import 'package:spor_takip/core/theme/app_fonts.dart';
import 'package:spor_takip/core/theme/app_theme.dart';

void main() {
  final theme = AppTheme.dark();

  test('is a dark theme on the background color', () {
    expect(theme.brightness, Brightness.dark);
    expect(theme.scaffoldBackgroundColor, AppColors.background);
    expect(theme.colorScheme.surface, AppColors.background);
  });

  test('maps the palette onto the color scheme', () {
    final scheme = theme.colorScheme;
    expect(scheme.primary, AppColors.accent);
    expect(scheme.onPrimary, AppColors.onAccent);
    expect(scheme.surfaceContainer, AppColors.surface);
    expect(scheme.onSurfaceVariant, AppColors.muted);
    expect(scheme.outlineVariant, AppColors.line);
    expect(scheme.error, AppColors.error);
  });

  test('headings use Montserrat, body text uses Inter', () {
    expect(theme.textTheme.headlineSmall!.fontFamily, AppFonts.heading);
    expect(theme.textTheme.titleLarge!.fontFamily, AppFonts.heading);
    expect(theme.textTheme.bodyMedium!.fontFamily, AppFonts.body);
    expect(theme.textTheme.titleMedium!.fontFamily, AppFonts.body);
  });

  test('cards are flat surface boxes with 16 radius', () {
    expect(theme.cardTheme.color, AppColors.surface);
    expect(theme.cardTheme.elevation, 0);
    expect(theme.cardTheme.shape, isA<RoundedRectangleBorder>());
  });

  test('filled buttons are accent with dark text', () {
    final style = theme.filledButtonTheme.style!;
    expect(style.backgroundColor!.resolve({}), AppColors.accent);
    expect(style.foregroundColor!.resolve({}), AppColors.onAccent);
  });

  test('selected navigation items are accent, others muted', () {
    final icon = theme.navigationBarTheme.iconTheme!;
    expect(icon.resolve({WidgetState.selected})!.color, AppColors.accent);
    expect(icon.resolve({})!.color, AppColors.muted);
  });
}
```

- [ ] **Step 4: Testleri çalıştır, başarısız olduklarını gör**

Run: `flutter test --no-pub test/shared/text_case_test.dart test/core/theme/app_theme_test.dart`
Expected: FAIL (derleme hatası: `text_case.dart`, `app_theme.dart` yok).

- [ ] **Step 5: `text_case.dart`, `app_colors.dart`, `app_fonts.dart` yaz**

`lib/shared/text_case.dart`:

```dart
/// Dile duyarlı büyük harf. Dart'ın `toUpperCase`'i dil bilmez; Türkçede
/// "i" → "İ", "ı" → "I" olmalı.
String upperCaseFor(String text, String languageCode) {
  if (languageCode != 'tr') return text.toUpperCase();
  return text.replaceAll('i', 'İ').replaceAll('ı', 'I').toUpperCase();
}
```

`lib/core/theme/app_colors.dart`:

```dart
import 'package:flutter/material.dart';

/// F5+ koyu tema paleti (spec §4.1). Yalnız `lib/core/theme/` içinde
/// kullanılır; ekranlar ve bileşenler renkleri temadan alır.
abstract final class AppColors {
  static const background = Color(0xFF0E0F12);
  static const surface = Color(0xFF181A20);
  static const surfaceHigh = Color(0xFF1F2128);
  static const line = Color(0xFF262830);
  static const text = Color(0xFFF2F3F5);
  static const muted = Color(0xFF8A8F98);
  static const accent = Color(0xFFC6FF00);
  static const onAccent = Color(0xFF0E0F12);
  static const error = Color(0xFFFF5C5C);
}
```

`lib/core/theme/app_fonts.dart`:

```dart
/// `pubspec.yaml` `fonts:` bölümündeki aile adları.
abstract final class AppFonts {
  /// Başlıklar ve büyük rakamlar (800, 900).
  static const heading = 'Montserrat';

  /// Gövde metni (400, 600).
  static const body = 'Inter';
}
```

- [ ] **Step 6: `app_theme.dart` yaz**

```dart
import 'package:flutter/material.dart';

import 'app_colors.dart';
import 'app_fonts.dart';

/// Uygulamanın tek teması (spec §4.1): koyu zemin, neon yeşil vurgu.
abstract final class AppTheme {
  static const _radius12 = BorderRadius.all(Radius.circular(12));
  static const _radius16 = BorderRadius.all(Radius.circular(16));

  static ThemeData dark() {
    const scheme = ColorScheme(
      brightness: Brightness.dark,
      primary: AppColors.accent,
      onPrimary: AppColors.onAccent,
      primaryContainer: AppColors.surfaceHigh,
      onPrimaryContainer: AppColors.accent,
      secondary: AppColors.accent,
      onSecondary: AppColors.onAccent,
      secondaryContainer: AppColors.surfaceHigh,
      onSecondaryContainer: AppColors.accent,
      tertiary: AppColors.accent,
      onTertiary: AppColors.onAccent,
      error: AppColors.error,
      onError: AppColors.onAccent,
      surface: AppColors.background,
      onSurface: AppColors.text,
      surfaceContainerLowest: AppColors.background,
      surfaceContainerLow: AppColors.surface,
      surfaceContainer: AppColors.surface,
      surfaceContainerHigh: AppColors.surfaceHigh,
      surfaceContainerHighest: AppColors.line,
      onSurfaceVariant: AppColors.muted,
      outline: AppColors.muted,
      outlineVariant: AppColors.line,
      inverseSurface: AppColors.text,
      onInverseSurface: AppColors.background,
      inversePrimary: AppColors.onAccent,
    );
    final textTheme = _textTheme();
    final buttonText = TextStyle(fontFamily: AppFonts.heading, fontWeight: FontWeight.w800, letterSpacing: 0.6);

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: scheme,
      scaffoldBackgroundColor: AppColors.background,
      canvasColor: AppColors.background,
      textTheme: textTheme,
      appBarTheme: AppBarTheme(
        backgroundColor: AppColors.background,
        foregroundColor: AppColors.text,
        elevation: 0,
        scrolledUnderElevation: 0,
        titleTextStyle: textTheme.titleLarge,
      ),
      cardTheme: const CardThemeData(
        color: AppColors.surface,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(borderRadius: _radius16),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.accent,
          foregroundColor: AppColors.onAccent,
          minimumSize: const Size(0, 48),
          shape: const RoundedRectangleBorder(borderRadius: _radius12),
          textStyle: buttonText,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.accent,
          side: const BorderSide(color: AppColors.line),
          minimumSize: const Size(0, 48),
          shape: const RoundedRectangleBorder(borderRadius: _radius12),
          textStyle: buttonText,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(foregroundColor: AppColors.accent, textStyle: buttonText),
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: AppColors.accent,
        foregroundColor: AppColors.onAccent,
        shape: RoundedRectangleBorder(borderRadius: _radius16),
      ),
      inputDecorationTheme: const InputDecorationTheme(
        filled: true,
        fillColor: AppColors.surface,
        border: OutlineInputBorder(borderRadius: _radius12, borderSide: BorderSide(color: AppColors.line)),
        enabledBorder: OutlineInputBorder(borderRadius: _radius12, borderSide: BorderSide(color: AppColors.line)),
        focusedBorder: OutlineInputBorder(borderRadius: _radius12, borderSide: BorderSide(color: AppColors.accent, width: 2)),
        errorBorder: OutlineInputBorder(borderRadius: _radius12, borderSide: BorderSide(color: AppColors.error)),
        focusedErrorBorder: OutlineInputBorder(borderRadius: _radius12, borderSide: BorderSide(color: AppColors.error, width: 2)),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: AppColors.background,
        surfaceTintColor: AppColors.background,
        indicatorColor: AppColors.surfaceHigh,
        iconTheme: WidgetStateProperty.resolveWith(
          (states) => IconThemeData(color: states.contains(WidgetState.selected) ? AppColors.accent : AppColors.muted),
        ),
        labelTextStyle: WidgetStateProperty.resolveWith(
          (states) => TextStyle(
            fontFamily: AppFonts.body,
            fontWeight: FontWeight.w600,
            fontSize: 12,
            color: states.contains(WidgetState.selected) ? AppColors.accent : AppColors.muted,
          ),
        ),
      ),
      chipTheme: const ChipThemeData(
        backgroundColor: AppColors.surface,
        selectedColor: AppColors.surfaceHigh,
        side: BorderSide(color: AppColors.line),
        labelStyle: TextStyle(color: AppColors.text),
        checkmarkColor: AppColors.accent,
        shape: RoundedRectangleBorder(borderRadius: _radius12),
      ),
      dialogTheme: const DialogThemeData(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: _radius16),
      ),
      bottomSheetTheme: const BottomSheetThemeData(backgroundColor: AppColors.surface),
      popupMenuTheme: const PopupMenuThemeData(color: AppColors.surfaceHigh),
      snackBarTheme: const SnackBarThemeData(
        backgroundColor: AppColors.surfaceHigh,
        contentTextStyle: TextStyle(color: AppColors.text),
        actionTextColor: AppColors.accent,
        behavior: SnackBarBehavior.floating,
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: AppColors.accent,
        linearTrackColor: AppColors.line,
      ),
      dividerTheme: const DividerThemeData(color: AppColors.line, space: 1),
      listTileTheme: const ListTileThemeData(iconColor: AppColors.muted),
    );
  }

  static TextTheme _textTheme() {
    final base = ThemeData(brightness: Brightness.dark).textTheme.apply(
          fontFamily: AppFonts.body,
          bodyColor: AppColors.text,
          displayColor: AppColors.text,
        );
    TextStyle? heading(TextStyle? style, FontWeight weight) =>
        style?.copyWith(fontFamily: AppFonts.heading, fontWeight: weight);
    TextStyle? body(TextStyle? style, FontWeight weight) => style?.copyWith(fontWeight: weight);
    return base.copyWith(
      displayLarge: heading(base.displayLarge, FontWeight.w900),
      displayMedium: heading(base.displayMedium, FontWeight.w900),
      displaySmall: heading(base.displaySmall, FontWeight.w900),
      headlineLarge: heading(base.headlineLarge, FontWeight.w900),
      headlineMedium: heading(base.headlineMedium, FontWeight.w900),
      headlineSmall: heading(base.headlineSmall, FontWeight.w800),
      titleLarge: heading(base.titleLarge, FontWeight.w800),
      titleMedium: body(base.titleMedium, FontWeight.w600),
      titleSmall: body(base.titleSmall, FontWeight.w600),
      labelLarge: body(base.labelLarge, FontWeight.w600),
    );
  }
}
```

- [ ] **Step 7: Testleri çalıştır, geçtiklerini gör**

Run: `flutter test --no-pub test/shared/text_case_test.dart test/core/theme/app_theme_test.dart`
Expected: PASS (8 test). `analyze` const uyarısı verirse (`prefer_const_constructors`) ilgili ifadeyi `const` yap.

- [ ] **Step 8: Temayı uygulamaya ve test uygulamasına bağla**

`lib/main.dart` — import ekle ve `MaterialApp.router`'a iki satır:

```dart
import 'core/theme/app_theme.dart';
```

```dart
    return MaterialApp.router(
      title: 'Spor Takip',
      theme: AppTheme.dark(),
      themeMode: ThemeMode.dark,
      routerConfig: router,
```

`test/features/progress/presentation/test_app.dart` — import ekle (`import 'package:spor_takip/core/theme/app_theme.dart';`) ve son satırı değiştir:

```dart
      child: MaterialApp.router(theme: AppTheme.dark(), routerConfig: router),
```

(Böylece ekran testleri gerçek temayla çalışır.)

- [ ] **Step 9: Analyze + ilgili testler**

Run: `flutter analyze --no-pub lib/core lib/shared lib/main.dart test/core test/shared test/features/progress/presentation/test_app.dart`
Expected: No issues found!

Run: `flutter test --no-pub test/features/progress/presentation/weight_test.dart`
Expected: PASS (tema eklenmesi mevcut testleri bozmamalı).

- [ ] **Step 10: Commit**

```bash
git add assets/fonts pubspec.yaml lib/core/theme lib/shared/text_case.dart lib/main.dart test/core test/shared/text_case_test.dart test/features/progress/presentation/test_app.dart
git commit -m "feat(theme): add dark neon theme with bundled Montserrat and Inter"
```

---

### Task 2: `SectionHeader` ve `StatTile`

**Files:**
- Create: `lib/shared/widgets/section_header.dart`, `lib/shared/widgets/stat_tile.dart`, `test/shared/widgets/themed.dart`
- Test: `test/shared/widgets/stat_tile_test.dart`

**Interfaces:**
- Consumes: `upperCaseFor` (Task 1), `AppTheme.dark()`, `AppColors` (yalnız testte).
- Produces:
  - `SectionHeader(String title, {Key? key})`
  - `StatTile({Key? key, required String label, required VoidCallback onTap, String? value, String? detail, bool highlight = false, String? emptyHint})`; `static const double height = 112`. İçteki metin anahtarları: `ValueKey('stat_tile_value')` (değer ya da "—"), `ValueKey('stat_tile_detail')` (detay ya da boşken `emptyHint`).
  - `StatTileSkeleton({Key? key})` — aynı yükseklikte boş kutu.
  - Test yardımcısı `Widget themed(Widget child)` (`test/shared/widgets/themed.dart`).

- [ ] **Step 1: Test yardımcısını ve failing testleri yaz**

`test/shared/widgets/themed.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:spor_takip/core/theme/app_theme.dart';

/// Bileşeni gerçek temayla, kaydırılabilir bir Scaffold içinde gösterir.
Widget themed(Widget child) => MaterialApp(
      theme: AppTheme.dark(),
      home: Scaffold(body: SingleChildScrollView(padding: const EdgeInsets.all(16), child: child)),
    );
```

`test/shared/widgets/stat_tile_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spor_takip/core/theme/app_colors.dart';
import 'package:spor_takip/shared/widgets/section_header.dart';
import 'package:spor_takip/shared/widgets/stat_tile.dart';

import 'themed.dart';

Text _text(WidgetTester tester, String key) => tester.widget<Text>(find.byKey(ValueKey(key)));

void main() {
  testWidgets('shows the label upper-cased, the value and the detail', (tester) async {
    await tester.pumpWidget(themed(StatTile(label: 'Kilo', value: '82.4 kg', detail: '▼ 0.6 kg', onTap: () {})));

    expect(find.text('KILO'), findsOneWidget); // test yerel ayarı en
    expect(_text(tester, 'stat_tile_value').data, '82.4 kg');
    expect(_text(tester, 'stat_tile_detail').data, '▼ 0.6 kg');
    expect(_text(tester, 'stat_tile_detail').style!.color, AppColors.muted);
  });

  testWidgets('a highlighted detail uses the accent color', (tester) async {
    await tester.pumpWidget(themed(StatTile(label: 'Güç', value: '110 kg', detail: '▲ 10', highlight: true, onTap: () {})));

    expect(_text(tester, 'stat_tile_detail').style!.color, AppColors.accent);
  });

  testWidgets('without a value it shows a dash and the hint', (tester) async {
    await tester.pumpWidget(themed(StatTile(label: 'Ölçü', emptyHint: 'Ölçü ekle', highlight: true, onTap: () {})));

    expect(_text(tester, 'stat_tile_value').data, '—');
    expect(_text(tester, 'stat_tile_detail').data, 'Ölçü ekle');
    expect(_text(tester, 'stat_tile_detail').style!.color, AppColors.muted);
  });

  testWidgets('tapping calls onTap', (tester) async {
    var taps = 0;
    await tester.pumpWidget(themed(StatTile(label: 'Kilo', value: '80 kg', onTap: () => taps++)));

    await tester.tap(find.byType(StatTile));
    expect(taps, 1);
  });

  testWidgets('skeleton has the tile height', (tester) async {
    await tester.pumpWidget(themed(const StatTileSkeleton()));

    expect(tester.getSize(find.byType(StatTileSkeleton)).height, StatTile.height);
  });

  testWidgets('section header is upper-cased and muted', (tester) async {
    await tester.pumpWidget(themed(const SectionHeader('İlerleme')));

    final text = tester.widget<Text>(find.byType(Text));
    expect(text.data, 'İLERLEME');
    expect(text.style!.color, AppColors.muted);
  });
}
```

- [ ] **Step 2: Testleri çalıştır, başarısız olduklarını gör**

Run: `flutter test --no-pub test/shared/widgets/stat_tile_test.dart`
Expected: FAIL (derleme hatası: `stat_tile.dart` yok).

- [ ] **Step 3: `section_header.dart` yaz**

```dart
import 'package:flutter/material.dart';

import '../../core/theme/app_fonts.dart';
import '../text_case.dart';

/// Küçük, büyük harfli, gri bölüm başlığı (spec §4.2).
class SectionHeader extends StatelessWidget {
  const SectionHeader(this.title, {super.key});

  final String title;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: 20, bottom: 8),
      child: Text(
        upperCaseFor(title, Localizations.localeOf(context).languageCode),
        style: theme.textTheme.labelLarge?.copyWith(
          fontFamily: AppFonts.heading,
          fontWeight: FontWeight.w800,
          letterSpacing: 1.2,
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }
}
```

- [ ] **Step 4: `stat_tile.dart` yaz**

```dart
import 'package:flutter/material.dart';

import '../text_case.dart';

/// Ana sayfadaki özet kutusu (spec §4.2): etiket, büyük değer, detay satırı.
/// [value] null ise "—" ve [emptyHint] gösterilir.
class StatTile extends StatelessWidget {
  const StatTile({
    super.key,
    required this.label,
    required this.onTap,
    this.value,
    this.detail,
    this.highlight = false,
    this.emptyHint,
  });

  static const double height = 112;

  final String label;
  final VoidCallback onTap;
  final String? value;
  final String? detail;

  /// Detay satırı vurgu renginde (olumlu değişim); boş kutuda yok sayılır.
  final bool highlight;
  final String? emptyHint;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final empty = value == null;
    final bottom = empty ? emptyHint : detail;
    return Material(
      color: scheme.surfaceContainer,
      borderRadius: BorderRadius.circular(16),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: SizedBox(
          height: height,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  upperCaseFor(label, Localizations.localeOf(context).languageCode),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.labelSmall?.copyWith(color: scheme.onSurfaceVariant, letterSpacing: 1),
                ),
                const Spacer(),
                Text(
                  value ?? '—',
                  key: const ValueKey('stat_tile_value'),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.headlineSmall,
                ),
                if (bottom != null)
                  Text(
                    bottom,
                    key: const ValueKey('stat_tile_detail'),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: highlight && !empty ? scheme.primary : scheme.onSurfaceVariant,
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

/// Veri yüklenirken [StatTile] yerine duran boş kutu.
class StatTileSkeleton extends StatelessWidget {
  const StatTileSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: StatTile.height,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainer,
          borderRadius: BorderRadius.circular(16),
        ),
      ),
    );
  }
}
```

- [ ] **Step 5: Testleri çalıştır, geçtiklerini gör**

Run: `flutter test --no-pub test/shared/widgets/stat_tile_test.dart`
Expected: PASS (6 test).

- [ ] **Step 6: Commit**

```bash
git add lib/shared/widgets/section_header.dart lib/shared/widgets/stat_tile.dart test/shared/widgets/themed.dart test/shared/widgets/stat_tile_test.dart
git commit -m "feat(theme): add section header and stat tile widgets"
```

---

### Task 3: `RingProgress` ve `MacroBar`

**Files:**
- Create: `lib/shared/widgets/ring_progress.dart`, `lib/shared/widgets/macro_bar.dart`
- Test: `test/shared/widgets/ring_progress_test.dart`, `test/shared/widgets/macro_bar_test.dart`

**Interfaces:**
- Consumes: `themed()` (Task 2 test yardımcısı).
- Produces:
  - `RingProgress({Key? key, required double value, required double target, double size = 120, double strokeWidth = 12, Widget? center})`; `static double fraction(double value, double target)` (hedef ≤ 0 → 0, sonuç 0–1 arası), `static bool isOver(double value, double target)`.
  - `RingPainter({required double progress, required Color color, required Color trackColor, required double strokeWidth})` (public; testte okunur). `RingProgress` içindeki `CustomPaint`'in anahtarı `ValueKey('ring_paint')`.
  - `MacroBar({Key? key, required String label, required double value, double? target, String unit = 'g'})`. İç anahtarlar: `ValueKey('macro_bar_value')` (metin `"30 / 176 g"` ya da `"30 g"`), `ValueKey('macro_bar_progress')` (yalnız hedef varsa `LinearProgressIndicator`).

- [ ] **Step 1: Failing testleri yaz**

`test/shared/widgets/ring_progress_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spor_takip/core/theme/app_colors.dart';
import 'package:spor_takip/shared/widgets/ring_progress.dart';

import 'themed.dart';

RingPainter _painter(WidgetTester tester) =>
    tester.widget<CustomPaint>(find.byKey(const ValueKey('ring_paint'))).painter! as RingPainter;

void main() {
  test('fraction is clamped and zero without a target', () {
    expect(RingProgress.fraction(500, 2000), 0.25);
    expect(RingProgress.fraction(2500, 2000), 1);
    expect(RingProgress.fraction(500, 0), 0);
    expect(RingProgress.isOver(2001, 2000), isTrue);
    expect(RingProgress.isOver(2000, 2000), isFalse);
    expect(RingProgress.isOver(10, 0), isFalse);
  });

  testWidgets('fills to the fraction in the accent color', (tester) async {
    await tester.pumpWidget(themed(const RingProgress(value: 1000, target: 2000, center: Text('1000'))));
    await tester.pumpAndSettle();

    expect(_painter(tester).progress, 0.5);
    expect(_painter(tester).color, AppColors.accent);
    expect(_painter(tester).trackColor, AppColors.line);
    expect(find.text('1000'), findsOneWidget);
  });

  testWidgets('over the target it is full and uses the error color', (tester) async {
    await tester.pumpWidget(themed(const RingProgress(value: 2500, target: 2000)));
    await tester.pumpAndSettle();

    expect(_painter(tester).progress, 1);
    expect(_painter(tester).color, AppColors.error);
  });

  testWidgets('without a target the ring stays empty', (tester) async {
    await tester.pumpWidget(themed(const RingProgress(value: 500, target: 0)));
    await tester.pumpAndSettle();

    expect(_painter(tester).progress, 0);
  });
}
```

`test/shared/widgets/macro_bar_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spor_takip/core/theme/app_colors.dart';
import 'package:spor_takip/shared/widgets/macro_bar.dart';

import 'themed.dart';

void main() {
  String valueText(WidgetTester tester) =>
      tester.widget<Text>(find.byKey(const ValueKey('macro_bar_value'))).data!;
  LinearProgressIndicator bar(WidgetTester tester) =>
      tester.widget<LinearProgressIndicator>(find.byKey(const ValueKey('macro_bar_progress')));

  testWidgets('with a target shows eaten / target and a bar', (tester) async {
    await tester.pumpWidget(themed(const MacroBar(label: 'Protein', value: 29.6, target: 176)));

    expect(find.text('Protein'), findsOneWidget);
    expect(valueText(tester), '30 / 176 g');
    expect(bar(tester).value, closeTo(29.6 / 176, 1e-9));
    expect(bar(tester).color, AppColors.accent);
  });

  testWidgets('without a target shows only the eaten amount', (tester) async {
    await tester.pumpWidget(themed(const MacroBar(label: 'Yağ', value: 42)));

    expect(valueText(tester), '42 g');
    expect(find.byKey(const ValueKey('macro_bar_progress')), findsNothing);
  });

  testWidgets('over the target the bar is full and red', (tester) async {
    await tester.pumpWidget(themed(const MacroBar(label: 'Protein', value: 200, target: 176)));

    expect(bar(tester).value, 1);
    expect(bar(tester).color, AppColors.error);
  });
}
```

- [ ] **Step 2: Testleri çalıştır, başarısız olduklarını gör**

Run: `flutter test --no-pub test/shared/widgets/ring_progress_test.dart test/shared/widgets/macro_bar_test.dart`
Expected: FAIL (derleme hatası: dosyalar yok).

- [ ] **Step 3: `ring_progress.dart` yaz**

```dart
import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Dairesel ilerleme (spec §4.2): boş kısım çizgi rengi, dolu kısım vurgu;
/// hedef aşılınca tam dolu ve hata renginde. Dolma ~600 ms canlandırılır.
class RingProgress extends StatelessWidget {
  const RingProgress({
    super.key,
    required this.value,
    required this.target,
    this.size = 120,
    this.strokeWidth = 12,
    this.center,
  });

  final double value;
  final double target;
  final double size;
  final double strokeWidth;
  final Widget? center;

  /// 0–1 doluluk; hedef yoksa 0, aşımda 1.
  static double fraction(double value, double target) =>
      target <= 0 ? 0 : (value / target).clamp(0.0, 1.0).toDouble();

  static bool isOver(double value, double target) => target > 0 && value > target;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final color = isOver(value, target) ? scheme.error : scheme.primary;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: fraction(value, target)),
      duration: const Duration(milliseconds: 600),
      curve: Curves.easeOutCubic,
      builder: (context, progress, child) => CustomPaint(
        key: const ValueKey('ring_paint'),
        painter: RingPainter(
          progress: progress,
          color: color,
          trackColor: scheme.outlineVariant,
          strokeWidth: strokeWidth,
        ),
        child: child,
      ),
      child: SizedBox.square(dimension: size, child: Center(child: center)),
    );
  }
}

class RingPainter extends CustomPainter {
  const RingPainter({
    required this.progress,
    required this.color,
    required this.trackColor,
    required this.strokeWidth,
  });

  final double progress;
  final Color color;
  final Color trackColor;
  final double strokeWidth;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final arcRect = rect.deflate(strokeWidth / 2);
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(arcRect, 0, math.pi * 2, false, paint..color = trackColor);
    if (progress > 0) {
      canvas.drawArc(arcRect, -math.pi / 2, math.pi * 2 * progress, false, paint..color = color);
    }
  }

  @override
  bool shouldRepaint(RingPainter old) =>
      old.progress != progress || old.color != color || old.trackColor != trackColor || old.strokeWidth != strokeWidth;
}
```

- [ ] **Step 4: `macro_bar.dart` yaz**

```dart
import 'package:flutter/material.dart';

import 'ring_progress.dart';

/// Makro satırı (spec §4.2): "yenen / hedef birim" ve ince çubuk; hedef
/// yoksa yalnız "yenen birim".
class MacroBar extends StatelessWidget {
  const MacroBar({super.key, required this.label, required this.value, this.target, this.unit = 'g'});

  final String label;
  final double value;
  final double? target;
  final String unit;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final target = this.target;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(label, style: theme.textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant)),
            ),
            Text(
              target == null ? '${value.round()} $unit' : '${value.round()} / ${target.round()} $unit',
              key: const ValueKey('macro_bar_value'),
              style: theme.textTheme.labelLarge,
            ),
          ],
        ),
        if (target != null) ...[
          const SizedBox(height: 4),
          ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: LinearProgressIndicator(
              key: const ValueKey('macro_bar_progress'),
              value: RingProgress.fraction(value, target),
              minHeight: 5,
              color: RingProgress.isOver(value, target) ? scheme.error : scheme.primary,
              backgroundColor: scheme.outlineVariant,
            ),
          ),
        ],
      ],
    );
  }
}
```

- [ ] **Step 5: Testleri çalıştır, geçtiklerini gör**

Run: `flutter test --no-pub test/shared/widgets/ring_progress_test.dart test/shared/widgets/macro_bar_test.dart`
Expected: PASS (7 test).

- [ ] **Step 6: Commit**

```bash
git add lib/shared/widgets/ring_progress.dart lib/shared/widgets/macro_bar.dart test/shared/widgets/ring_progress_test.dart test/shared/widgets/macro_bar_test.dart
git commit -m "feat(theme): add ring progress and macro bar widgets"
```

---

### Task 4: Grafik renklerini temaya bağla

**Files:**
- Create: `lib/core/theme/chart_style.dart`
- Modify: `lib/features/progress/presentation/widgets/progress_line_chart.dart` (`gridData` ve `touchTooltipData`)
- Test: `test/features/progress/presentation/progress_line_chart_test.dart`

**Interfaces:**
- Consumes: `AppTheme.dark()` (Task 1), `themed()` (Task 2).
- Produces: `FlLine chartGridLine(BuildContext context)`, `Color chartTooltipColor(BuildContext context)`, `Color chartTooltipTextColor(BuildContext context)`.

- [ ] **Step 1: Failing testi yaz**

`test/features/progress/presentation/progress_line_chart_test.dart`:

```dart
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spor_takip/core/theme/app_colors.dart';
import 'package:spor_takip/features/progress/domain/trend.dart';
import 'package:spor_takip/features/progress/presentation/widgets/progress_line_chart.dart';

import '../../../shared/widgets/themed.dart';

void main() {
  testWidgets('chart colors come from the dark theme', (tester) async {
    await tester.pumpWidget(themed(ProgressLineChart(points: [
      ValuePoint(DateTime(2026, 9, 1), 80),
      ValuePoint(DateTime(2026, 9, 20), 79),
    ])));
    await tester.pumpAndSettle();

    final data = tester.widget<LineChart>(find.byType(LineChart)).data;
    final bar = data.lineBarsData.single;
    expect(bar.color, AppColors.accent);
    expect(data.gridData.getDrawingHorizontalLine(0).color, AppColors.line);
    final tooltipColor = data.lineTouchData.touchTooltipData.getTooltipColor(LineBarSpot(bar, 0, bar.spots.first));
    expect(tooltipColor, AppColors.surfaceHigh);
  });
}
```

- [ ] **Step 2: Testi çalıştır, başarısız olduğunu gör**

Run: `flutter test --no-pub test/features/progress/presentation/progress_line_chart_test.dart`
Expected: FAIL (ızgara rengi fl_chart varsayılanı, `AppColors.line` değil).

- [ ] **Step 3: `chart_style.dart` yaz**

```dart
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

// fl_chart renkleri temadan otomatik almaz (spec §4.1); grafikler bunları kullanır.

FlLine chartGridLine(BuildContext context) =>
    FlLine(color: Theme.of(context).colorScheme.outlineVariant, strokeWidth: 1);

Color chartTooltipColor(BuildContext context) => Theme.of(context).colorScheme.surfaceContainerHigh;

Color chartTooltipTextColor(BuildContext context) => Theme.of(context).colorScheme.onSurface;
```

- [ ] **Step 4: `ProgressLineChart`'ı bağla**

`progress_line_chart.dart`'a import: `import '../../../../core/theme/chart_style.dart';`

`gridData` satırını değiştir:

```dart
          gridData: FlGridData(
            show: !compact,
            drawVerticalLine: false,
            getDrawingHorizontalLine: (_) => chartGridLine(context),
          ),
```

`touchTooltipData`'yı değiştir:

```dart
                  touchTooltipData: LineTouchTooltipData(
                    getTooltipColor: (_) => chartTooltipColor(context),
                    getTooltipItems: (touched) => [
                      for (final spot in touched)
                        LineTooltipItem(
                          label(spot.spotIndex),
                          TextStyle(color: chartTooltipTextColor(context)),
                        ),
                    ],
                  ),
```

- [ ] **Step 5: Testleri çalıştır**

Run: `flutter test --no-pub test/features/progress/presentation/progress_line_chart_test.dart test/features/progress/presentation/strength_test.dart`
Expected: PASS.

- [ ] **Step 6: Commit**

```bash
git add lib/core/theme/chart_style.dart lib/features/progress/presentation/widgets/progress_line_chart.dart test/features/progress/presentation/progress_line_chart_test.dart
git commit -m "feat(theme): style progress charts from the theme"
```

---

### Task 5: Çeviriler ve `TodayNutritionCard`

**Files:**
- Modify: `assets/translations/tr.json`, `assets/translations/en.json` (`home` bölümü)
- Create: `lib/features/nutrition/presentation/widgets/today_nutrition_card.dart`
- Test: `test/features/nutrition/presentation/today_nutrition_card_test.dart`

**Interfaces:**
- Consumes: `RingProgress`, `MacroBar` (Task 3); `todayMealsProvider` (`lib/features/nutrition/application/today_meals_provider.dart`, `FutureProvider.autoDispose<List<Meal>>`); `sumMealMacros(List<Meal>) → MacroTotals{calories, proteinG, carbsG, fatG}` (`lib/features/nutrition/domain/macro_totals.dart`); `Profile.dailyCalorieTarget`, `Profile.dailyProteinTargetG`; `CardError({required VoidCallback onRetry})` (`lib/features/progress/presentation/widgets/card_states.dart`).
- Produces: `TodayNutritionCard({Key? key, required Profile profile})`, kök anahtar `Key('today_nutrition_card')`; içte `Key('today_nutrition_calories')` (yenen kcal metni), `Key('today_nutrition_protein')`, `Key('today_nutrition_carbs')`, `Key('today_nutrition_fat')` (`MacroBar`'lar). Dokununca `context.go('/nutrition')`.
- Produces (çeviri anahtarları, Task 6–7 kullanır): `home.greeting_morning|greeting_day|greeting_evening`, `home.weekday_1..7`, `home.month_1..12`, `home.kcal_of` (`{target}`), `home.protein|carbs|fat`, `home.section_progress`, `home.tile_weight|tile_week|tile_strength|tile_measurement`, `home.week_sets` (`{count}`), `home.hint_weight|hint_workout|hint_strength|hint_measurement`. `home.calorie_target` ve `home.protein_target` Task 7'de silinir.

- [ ] **Step 1: Çeviri anahtarlarını ekle**

Bu betiği `scratchpad`'e `add_home_keys.py` olarak yaz ve `python add_home_keys.py` ile proje kökünde çalıştır (sıra ve biçim korunur):

```python
import json, collections

KEYS = {
  'tr': {
    'greeting_morning': 'Günaydın', 'greeting_day': 'İyi günler', 'greeting_evening': 'İyi akşamlar',
    'weekday_1': 'Pazartesi', 'weekday_2': 'Salı', 'weekday_3': 'Çarşamba', 'weekday_4': 'Perşembe',
    'weekday_5': 'Cuma', 'weekday_6': 'Cumartesi', 'weekday_7': 'Pazar',
    'month_1': 'Ocak', 'month_2': 'Şubat', 'month_3': 'Mart', 'month_4': 'Nisan', 'month_5': 'Mayıs',
    'month_6': 'Haziran', 'month_7': 'Temmuz', 'month_8': 'Ağustos', 'month_9': 'Eylül',
    'month_10': 'Ekim', 'month_11': 'Kasım', 'month_12': 'Aralık',
    'kcal_of': '/ {target} kcal', 'protein': 'Protein', 'carbs': 'Karbonhidrat', 'fat': 'Yağ',
    'section_progress': 'İlerleme',
    'tile_weight': 'Kilo', 'tile_week': 'Bu hafta antrenman', 'tile_strength': 'Güç (1RM)', 'tile_measurement': 'Ölçü',
    'week_sets': '{count} set',
    'hint_weight': 'Kilo gir', 'hint_workout': 'Antrenman başlat', 'hint_strength': 'Antrenman kaydet',
    'hint_measurement': 'Ölçü ekle',
  },
  'en': {
    'greeting_morning': 'Good morning', 'greeting_day': 'Good afternoon', 'greeting_evening': 'Good evening',
    'weekday_1': 'Monday', 'weekday_2': 'Tuesday', 'weekday_3': 'Wednesday', 'weekday_4': 'Thursday',
    'weekday_5': 'Friday', 'weekday_6': 'Saturday', 'weekday_7': 'Sunday',
    'month_1': 'January', 'month_2': 'February', 'month_3': 'March', 'month_4': 'April', 'month_5': 'May',
    'month_6': 'June', 'month_7': 'July', 'month_8': 'August', 'month_9': 'September',
    'month_10': 'October', 'month_11': 'November', 'month_12': 'December',
    'kcal_of': '/ {target} kcal', 'protein': 'Protein', 'carbs': 'Carbs', 'fat': 'Fat',
    'section_progress': 'Progress',
    'tile_weight': 'Weight', 'tile_week': 'Workouts this week', 'tile_strength': 'Strength (1RM)', 'tile_measurement': 'Measurement',
    'week_sets': '{count} sets',
    'hint_weight': 'Log weight', 'hint_workout': 'Start a workout', 'hint_strength': 'Log a workout',
    'hint_measurement': 'Add measurement',
  },
}

for lang, keys in KEYS.items():
    path = f'assets/translations/{lang}.json'
    with open(path, encoding='utf-8') as f:
        data = json.load(f, object_pairs_hook=collections.OrderedDict)
    data['home'].update(keys)
    with open(path, 'w', encoding='utf-8', newline='\n') as f:
        f.write(json.dumps(data, ensure_ascii=False, indent=2) + '\n')
```

Run: `git diff --stat assets/translations` → her dosyada yalnız `home` bölümüne eklemeler.

- [ ] **Step 2: Failing testi yaz**

`test/features/nutrition/presentation/today_nutrition_card_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spor_takip/features/nutrition/application/today_meals_provider.dart';
import 'package:spor_takip/features/nutrition/domain/meal.dart';
import 'package:spor_takip/features/nutrition/presentation/widgets/today_nutrition_card.dart';

import '../../progress/fixtures.dart';
import '../../progress/presentation/test_app.dart';

void main() {
  setUpAll(initTestLocalization);

  Future<void> pump(WidgetTester tester, Future<List<Meal>> Function() meals) async {
    await tester.pumpWidget(testApp(
      const TodayNutritionCard(profile: testProfile),
      overrides: [todayMealsProvider.overrideWith((ref) => meals())],
      stubRoutes: {'/nutrition': 'NUTRITION'},
    ));
    await tester.pumpAndSettle();
  }

  String macroValue(WidgetTester tester, String key) => tester
      .widget<Text>(find.descendant(of: find.byKey(Key(key)), matching: find.byKey(const ValueKey('macro_bar_value'))))
      .data!;

  testWidgets('shows today\'s calories and protein against the targets', (tester) async {
    await pump(tester, () async => [
          testMeal(DateTime(2026, 10, 3, 8), calories: 400, proteinG: 20),
          testMeal(DateTime(2026, 10, 3, 13), calories: 600, proteinG: 40),
        ]);

    expect(tester.widget<Text>(find.byKey(const Key('today_nutrition_calories'))).data, '1000');
    expect(macroValue(tester, 'today_nutrition_protein'), '60 / 176 g');
    expect(macroValue(tester, 'today_nutrition_carbs'), '0 g');
    expect(macroValue(tester, 'today_nutrition_fat'), '0 g');
  });

  testWidgets('with no meals the ring is at zero', (tester) async {
    await pump(tester, () async => const []);

    expect(tester.widget<Text>(find.byKey(const Key('today_nutrition_calories'))).data, '0');
  });

  testWidgets('tapping opens the nutrition tab', (tester) async {
    await pump(tester, () async => const []);

    await tester.tap(find.byKey(const Key('today_nutrition_card')));
    await tester.pumpAndSettle();
    expect(find.text('NUTRITION'), findsOneWidget);
  });

  testWidgets('a load error offers a retry', (tester) async {
    await pump(tester, () async => throw Exception('offline'));

    expect(find.byKey(const Key('card_retry')), findsOneWidget);
  });
}
```

- [ ] **Step 3: Testi çalıştır, başarısız olduğunu gör**

Run: `flutter test --no-pub test/features/nutrition/presentation/today_nutrition_card_test.dart`
Expected: FAIL (derleme hatası: `today_nutrition_card.dart` yok).

- [ ] **Step 4: `today_nutrition_card.dart` yaz**

```dart
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../shared/widgets/macro_bar.dart';
import '../../../../shared/widgets/ring_progress.dart';
import '../../../onboarding/domain/profile.dart';
import '../../../progress/presentation/widgets/card_states.dart';
import '../../application/today_meals_provider.dart';
import '../../domain/macro_totals.dart';

/// Ana sayfa beslenme kartı (spec §5): bugün yenen kalori halkası ve makrolar.
class TodayNutritionCard extends ConsumerWidget {
  const TodayNutritionCard({super.key, required this.profile});

  final Profile profile;

  Widget _content(BuildContext context, MacroTotals totals) {
    final theme = Theme.of(context);
    return Row(
      children: [
        RingProgress(
          value: totals.calories,
          target: profile.dailyCalorieTarget,
          size: 112,
          center: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '${totals.calories.round()}',
                key: const Key('today_nutrition_calories'),
                style: theme.textTheme.headlineSmall,
              ),
              Text(
                'home.kcal_of'.tr(namedArgs: {'target': '${profile.dailyCalorieTarget.round()}'}),
                style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
              ),
            ],
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            children: [
              MacroBar(
                key: const Key('today_nutrition_protein'),
                label: 'home.protein'.tr(),
                value: totals.proteinG,
                target: profile.dailyProteinTargetG,
              ),
              const SizedBox(height: 10),
              MacroBar(key: const Key('today_nutrition_carbs'), label: 'home.carbs'.tr(), value: totals.carbsG),
              const SizedBox(height: 10),
              MacroBar(key: const Key('today_nutrition_fat'), label: 'home.fat'.tr(), value: totals.fatG),
            ],
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mealsAsync = ref.watch(todayMealsProvider);
    return Card(
      key: const Key('today_nutrition_card'),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => context.go('/nutrition'),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: mealsAsync.when(
            loading: () => const SizedBox(height: 112, child: Center(child: CircularProgressIndicator())),
            error: (error, stackTrace) => CardError(onRetry: () => ref.invalidate(todayMealsProvider)),
            data: (meals) => _content(context, sumMealMacros(meals)),
          ),
        ),
      ),
    );
  }
}
```

- [ ] **Step 5: Testi çalıştır, geçtiğini gör**

Run: `flutter test --no-pub test/features/nutrition/presentation/today_nutrition_card_test.dart`
Expected: PASS (4 test).

- [ ] **Step 6: Commit**

```bash
git add assets/translations lib/features/nutrition/presentation/widgets/today_nutrition_card.dart test/features/nutrition/presentation/today_nutrition_card_test.dart
git commit -m "feat(home): add today nutrition card with calorie ring"
```

---

### Task 6: Selam ve 2×2 özet kutuları (`HomeStatGrid`)

**Files:**
- Create: `lib/features/onboarding/domain/home_greeting.dart`, `lib/features/progress/presentation/widgets/home_stat_grid.dart`
- Test: `test/features/onboarding/home_greeting_test.dart`, `test/features/progress/presentation/home_stat_grid_test.dart`

**Interfaces:**
- Consumes: `StatTile`, `StatTileSkeleton` (Task 2); `weightLogsProvider` (`List<BodyWeightLog>`, eskiden yeniye), `weeklySummaryProvider` (`WeeklySummary{thisWeek: WeekStats{workouts, sets}}`), `strengthCardProvider` (`List<StrengthSeries>`, `series.latest.estimateKg`, `series.valuePoints`, `series.exerciseName`), `measurementsProvider` (`List<BodyMeasurement>`, eskiden yeniye) — hepsi `lib/features/progress/application/progress_providers.dart`; `changeOver30Days(List<ValuePoint>) → double?` (`trend.dart`); `measurementChange(List<BodyMeasurement>, MeasurementSite) → double?` (`body_measurement.dart`); `formatOneDecimal`, `formatDelta` (`progress_format.dart`); `Goal` (`profile.dart`).
- Produces:
  - `String greetingKey(DateTime now)` → `'home.greeting_morning'` (05:00–11:59), `'home.greeting_day'` (12:00–17:59), `'home.greeting_evening'` (diğer).
  - `bool weightChangeIsGood(double change, Goal goal)` — kilo verme: `change < 0`; kas kazanma: `change > 0`; formda kalma: `false`.
  - `MeasurementSite homeMeasurementSite(BodyMeasurement latest)` — bel varsa bel, yoksa `latest.values.keys.first`.
  - `HomeStatGrid({Key? key, required Profile profile})`; kutu anahtarları `Key('home_tile_weight')`, `Key('home_tile_week')`, `Key('home_tile_strength')`, `Key('home_tile_measurement')`. Dokununca: kilo → `context.push('/home/weight')`, hafta → `context.go('/workout/history')`, güç → `context.push('/home/strength')`, ölçü → `context.push('/home/measurements')`.

- [ ] **Step 1: Failing testleri yaz**

`test/features/onboarding/home_greeting_test.dart`:

```dart
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
```

`test/features/progress/presentation/home_stat_grid_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spor_takip/core/theme/app_colors.dart';
import 'package:spor_takip/features/onboarding/domain/profile.dart';
import 'package:spor_takip/features/progress/application/progress_providers.dart';
import 'package:spor_takip/features/progress/domain/body_measurement.dart';
import 'package:spor_takip/features/progress/domain/body_weight_log.dart';
import 'package:spor_takip/features/progress/domain/strength.dart';
import 'package:spor_takip/features/progress/domain/weekly_summary.dart';
import 'package:spor_takip/features/progress/presentation/widgets/home_stat_grid.dart';
import 'package:spor_takip/features/workout/application/session_providers.dart';

import '../fixtures.dart';
import 'test_app.dart';

final _now = DateTime(2026, 9, 28, 12);

final _summary = WeeklySummary(
  weekStart: DateTime(2026, 9, 28),
  thisWeek: const WeekStats(workouts: 3, sets: 45, volumeKg: 12000, nutritionDays: 4, lastWeightKg: 80),
  lastWeek: const WeekStats(workouts: 2, sets: 30, volumeKg: 9000, nutritionDays: 0, lastWeightKg: 80.5),
);

final _emptySummary = WeeklySummary(
  weekStart: DateTime(2026, 9, 28),
  thisWeek: const WeekStats(workouts: 0, sets: 0, volumeKg: 0, nutritionDays: 0),
  lastWeek: const WeekStats(workouts: 0, sets: 0, volumeKg: 0, nutritionDays: 0),
);

final _squat = StrengthSeries(exerciseId: 'squat', exerciseName: 'Squat', points: [
  StrengthPoint(date: DateTime(2026, 8, 1), estimateKg: 100, weightKg: 100, reps: 1),
  StrengthPoint(date: DateTime(2026, 9, 20), estimateKg: 110, weightKg: 110, reps: 1),
]);

void main() {
  setUpAll(initTestLocalization);

  Future<void> pump(
    WidgetTester tester, {
    Profile profile = testProfile,
    List<BodyWeightLog> weights = const [],
    WeeklySummary? summary,
    List<StrengthSeries> strength = const [],
    List<BodyMeasurement> measurements = const [],
    Object? weightError,
  }) async {
    await tester.pumpWidget(testApp(
      HomeStatGrid(profile: profile),
      overrides: [
        nowProvider.overrideWithValue(() => _now),
        weightLogsProvider.overrideWith((ref) async => weightError != null ? throw weightError : weights),
        weeklySummaryProvider.overrideWith((ref) async => summary ?? _emptySummary),
        strengthCardProvider.overrideWith((ref) async => strength),
        measurementsProvider.overrideWith((ref) async => measurements),
      ],
      stubRoutes: {
        '/home/weight': 'WEIGHT',
        '/workout/history': 'HISTORY',
        '/home/strength': 'STRENGTH',
        '/home/measurements': 'MEASUREMENTS',
      },
    ));
    await tester.pumpAndSettle();
  }

  Text part(WidgetTester tester, String tile, String part) => tester.widget<Text>(
      find.descendant(of: find.byKey(Key(tile)), matching: find.byKey(ValueKey('stat_tile_$part'))));

  testWidgets('fills the four tiles from the progress data', (tester) async {
    await pump(
      tester,
      weights: [
        BodyWeightLog(date: DateTime(2026, 8, 1), weightKg: 82),
        BodyWeightLog(date: DateTime(2026, 9, 20), weightKg: 80),
      ],
      summary: _summary,
      strength: [_squat],
      measurements: [
        BodyMeasurement(date: DateTime(2026, 9, 1), values: {MeasurementSite.waist: 85}),
        BodyMeasurement(date: DateTime(2026, 9, 20), values: {MeasurementSite.waist: 83, MeasurementSite.arm: 35}),
      ],
    );

    expect(part(tester, 'home_tile_weight', 'value').data, '80 kg');
    expect(part(tester, 'home_tile_week', 'value').data, '3');
    expect(part(tester, 'home_tile_strength', 'value').data, '110 kg');
    expect(part(tester, 'home_tile_measurement', 'value').data, '83 cm');
    // Detay metinleri `.tr()` içinde; yalnızca renkleri doğrulanır.
    expect(part(tester, 'home_tile_strength', 'detail').style!.color, AppColors.accent); // ▲ 10
    expect(part(tester, 'home_tile_measurement', 'detail').style!.color, AppColors.accent); // bel ▼ 2
  });

  testWidgets('weight change color follows the goal', (tester) async {
    final weights = [
      BodyWeightLog(date: DateTime(2026, 8, 1), weightKg: 82),
      BodyWeightLog(date: DateTime(2026, 9, 20), weightKg: 80),
    ];
    // testProfile hedefi kas kazanma: düşüş olumlu değil.
    await pump(tester, weights: weights);
    expect(part(tester, 'home_tile_weight', 'detail').style!.color, AppColors.muted);

    await pump(tester, weights: weights, profile: testProfile.copyWith(goal: Goal.loseWeight));
    expect(part(tester, 'home_tile_weight', 'detail').style!.color, AppColors.accent);
  });

  testWidgets('empty data shows dashes', (tester) async {
    await pump(tester);

    for (final tile in ['home_tile_weight', 'home_tile_week', 'home_tile_strength', 'home_tile_measurement']) {
      expect(part(tester, tile, 'value').data, '—', reason: tile);
    }
  });

  testWidgets('a failed source only empties its own tile', (tester) async {
    await pump(tester, weightError: Exception('offline'), summary: _summary);

    expect(part(tester, 'home_tile_weight', 'value').data, '—');
    expect(part(tester, 'home_tile_week', 'value').data, '3');
  });

  for (final (tile, screen) in [
    ('home_tile_weight', 'WEIGHT'),
    ('home_tile_week', 'HISTORY'),
    ('home_tile_strength', 'STRENGTH'),
    ('home_tile_measurement', 'MEASUREMENTS'),
  ]) {
    testWidgets('tapping $tile opens $screen', (tester) async {
      await pump(tester);

      await tester.tap(find.byKey(Key(tile)));
      await tester.pumpAndSettle();
      expect(find.text(screen), findsOneWidget);
    });
  }
}

```

(`Profile.copyWith` F5'te eklendi: `lib/features/onboarding/domain/profile.dart:75`. `WeekStats`'ta `avgCalories`, `avgProteinG`, `lastWeightKg` isteğe bağlı.)

- [ ] **Step 2: Testleri çalıştır, başarısız olduklarını gör**

Run: `flutter test --no-pub test/features/onboarding/home_greeting_test.dart test/features/progress/presentation/home_stat_grid_test.dart`
Expected: FAIL (derleme hatası: dosyalar yok).

- [ ] **Step 3: `home_greeting.dart` yaz**

```dart
/// Saate göre selam çeviri anahtarı (spec §5): 05–12 sabah, 12–18 gün, 18–05 akşam.
String greetingKey(DateTime now) {
  final hour = now.hour;
  if (hour >= 5 && hour < 12) return 'home.greeting_morning';
  if (hour >= 12 && hour < 18) return 'home.greeting_day';
  return 'home.greeting_evening';
}
```

- [ ] **Step 4: `home_stat_grid.dart` yaz**

```dart
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../shared/widgets/stat_tile.dart';
import '../../../onboarding/domain/profile.dart';
import '../../application/progress_providers.dart';
import '../../domain/body_measurement.dart';
import '../../domain/progress_format.dart';
import '../../domain/trend.dart';

/// Kilo değişimi kullanıcının amacına göre olumlu mu? (bkz. plan "Spec'ten sapmalar").
bool weightChangeIsGood(double change, Goal goal) => switch (goal) {
      Goal.loseWeight => change < 0,
      Goal.gainMuscle => change > 0,
      Goal.maintain => false,
    };

/// Ana sayfada gösterilecek bölge: bel varsa bel, yoksa ilk ölçülen.
MeasurementSite homeMeasurementSite(BodyMeasurement latest) =>
    latest.values.containsKey(MeasurementSite.waist) ? MeasurementSite.waist : latest.values.keys.first;

/// Ana sayfadaki 2×2 özet kutuları (spec §5).
class HomeStatGrid extends StatelessWidget {
  const HomeStatGrid({super.key, required this.profile});

  final Profile profile;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(child: _WeightTile(goal: profile.goal)),
            const SizedBox(width: 12),
            const Expanded(child: _WeekTile()),
          ],
        ),
        const SizedBox(height: 12),
        const Row(
          children: [
            Expanded(child: _StrengthTile()),
            SizedBox(width: 12),
            Expanded(child: _MeasurementTile()),
          ],
        ),
      ],
    );
  }
}

/// Yüklenirken iskelet; hatada "yüklenemedi" ve dokununca yeniden dene.
Widget _asyncTile<T>({
  required Key key,
  required String label,
  required AsyncValue<T> value,
  required VoidCallback onRetry,
  required Widget Function(T data) data,
}) {
  return value.when(
    loading: () => StatTileSkeleton(key: key),
    error: (error, stackTrace) => StatTile(key: key, label: label, emptyHint: 'progress.load_error'.tr(), onTap: onRetry),
    data: data,
  );
}

class _WeightTile extends ConsumerWidget {
  const _WeightTile({required this.goal});

  final Goal goal;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    const key = Key('home_tile_weight');
    final label = 'home.tile_weight'.tr();
    void open() => context.push('/home/weight');
    return _asyncTile(
      key: key,
      label: label,
      value: ref.watch(weightLogsProvider),
      onRetry: () => ref.invalidate(weightLogsProvider),
      data: (logs) {
        if (logs.isEmpty) return StatTile(key: key, label: label, emptyHint: 'home.hint_weight'.tr(), onTap: open);
        final change = changeOver30Days([for (final log in logs) ValuePoint(log.date, log.weightKg)]);
        return StatTile(
          key: key,
          label: label,
          value: '${formatOneDecimal(logs.last.weightKg)} kg',
          detail: change == null ? null : 'progress.change_30d'.tr(namedArgs: {'value': '${formatDelta(change)} kg'}),
          highlight: change != null && weightChangeIsGood(change, goal),
          onTap: open,
        );
      },
    );
  }
}

class _WeekTile extends ConsumerWidget {
  const _WeekTile();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    const key = Key('home_tile_week');
    final label = 'home.tile_week'.tr();
    void open() => context.go('/workout/history');
    return _asyncTile(
      key: key,
      label: label,
      value: ref.watch(weeklySummaryProvider),
      onRetry: () => ref.invalidate(weeklySummaryProvider),
      data: (summary) {
        final week = summary.thisWeek;
        if (week.workouts == 0) {
          return StatTile(key: key, label: label, emptyHint: 'home.hint_workout'.tr(), onTap: open);
        }
        return StatTile(
          key: key,
          label: label,
          value: '${week.workouts}',
          detail: 'home.week_sets'.tr(namedArgs: {'count': '${week.sets}'}),
          onTap: open,
        );
      },
    );
  }
}

class _StrengthTile extends ConsumerWidget {
  const _StrengthTile();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    const key = Key('home_tile_strength');
    final label = 'home.tile_strength'.tr();
    void open() => context.push('/home/strength');
    return _asyncTile(
      key: key,
      label: label,
      value: ref.watch(strengthCardProvider),
      onRetry: () => ref.invalidate(recentSessionsProvider),
      data: (series) {
        if (series.isEmpty) return StatTile(key: key, label: label, emptyHint: 'home.hint_strength'.tr(), onTap: open);
        final top = series.first;
        final change = changeOver30Days(top.valuePoints);
        return StatTile(
          key: key,
          label: label,
          value: '${formatOneDecimal(top.latest.estimateKg)} kg',
          detail: change == null ? top.exerciseName : '${top.exerciseName} · ${formatDelta(change)}',
          highlight: change != null && change > 0,
          onTap: open,
        );
      },
    );
  }
}

class _MeasurementTile extends ConsumerWidget {
  const _MeasurementTile();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    const key = Key('home_tile_measurement');
    final label = 'home.tile_measurement'.tr();
    void open() => context.push('/home/measurements');
    return _asyncTile(
      key: key,
      label: label,
      value: ref.watch(measurementsProvider),
      onRetry: () => ref.invalidate(measurementsProvider),
      data: (list) {
        if (list.isEmpty || list.last.values.isEmpty) {
          return StatTile(key: key, label: label, emptyHint: 'home.hint_measurement'.tr(), onTap: open);
        }
        final site = homeMeasurementSite(list.last);
        final change = measurementChange(list, site);
        final siteName = 'progress.sites.${site.name}'.tr();
        return StatTile(
          key: key,
          label: label,
          value: '${formatOneDecimal(list.last.values[site]!)} cm',
          detail: change == null ? siteName : '$siteName · ${formatDelta(change)}',
          highlight: site == MeasurementSite.waist && change != null && change < 0,
          onTap: open,
        );
      },
    );
  }
}
```

- [ ] **Step 5: Testleri çalıştır, geçtiklerini gör**

Run: `flutter test --no-pub test/features/onboarding/home_greeting_test.dart test/features/progress/presentation/home_stat_grid_test.dart`
Expected: PASS (1 + 8 test). `strengthCardProvider` hata durumunda yeniden deneme `recentSessionsProvider`'ı geçersiz kılar (eski `StrengthCard` ile aynı).

- [ ] **Step 6: Commit**

```bash
git add lib/features/onboarding/domain/home_greeting.dart lib/features/progress/presentation/widgets/home_stat_grid.dart test/features/onboarding/home_greeting_test.dart test/features/progress/presentation/home_stat_grid_test.dart
git commit -m "feat(home): add greeting and progress stat tiles"
```

---

### Task 7: Yeni ana sayfa; eski kartları kaldır

**Files:**
- Modify: `lib/features/onboarding/presentation/home_screen.dart` (tamamı)
- Delete: `lib/features/progress/presentation/widgets/targets_card.dart`, `body_weight_card.dart`, `strength_card.dart`, `measurements_card.dart`
- Modify: `test/features/progress/presentation/home_cards_test.dart` (targets testi + importu), `weight_test.dart` (`group('card')` + `openAddDialog`), `strength_test.dart` (`group('card')`), `measurements_test.dart` (`group('card')` + `openAddForm`), `assets/translations/{tr,en}.json` (`home.calorie_target`, `home.protein_target` silinir)
- Test: `test/features/onboarding/presentation/home_screen_test.dart`

**Interfaces:**
- Consumes: `TodayNutritionCard` (Task 5), `HomeStatGrid`, `greetingKey` (Task 6), `SectionHeader` (Task 2), `upperCaseFor` (Task 1), `TodayWorkoutCard` (değişmez), `nowProvider`.
- Produces: `HomeScreen` — anahtarlar `Key('home_screen')`, `Key('home_list')`, `Key('home_sign_out_button')` (korunur), yeni `Key('home_date')`, `Key('home_greeting')`.

- [ ] **Step 1: Failing ekran testini yaz**

`test/features/onboarding/presentation/home_screen_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spor_takip/features/nutrition/application/today_meals_provider.dart';
import 'package:spor_takip/features/onboarding/application/profile_providers.dart';
import 'package:spor_takip/features/onboarding/presentation/home_screen.dart';
import 'package:spor_takip/features/progress/application/progress_providers.dart';
import 'package:spor_takip/features/progress/domain/weekly_summary.dart';
import 'package:spor_takip/features/workout/application/session_providers.dart';
import 'package:spor_takip/features/workout/application/workout_providers.dart';
import 'package:spor_takip/features/workout/domain/today_workout.dart';

import '../../progress/fixtures.dart';
import '../../progress/presentation/test_app.dart';

void main() {
  setUpAll(initTestLocalization);

  testWidgets('shows the header, nutrition, today\'s workout and four tiles', (tester) async {
    tester.view.physicalSize = const Size(800, 2000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(testApp(
      const HomeScreen(),
      scaffold: false,
      overrides: [
        nowProvider.overrideWithValue(() => DateTime(2026, 10, 3, 9)),
        profileProvider.overrideWith((ref) async => testProfile),
        todayMealsProvider.overrideWith((ref) async => const []),
        todayWorkoutProvider.overrideWith((ref) async => const NoActiveProgram()),
        inProgressSessionProvider.overrideWith((ref) async => null),
        weightLogsProvider.overrideWith((ref) async => const []),
        weeklySummaryProvider.overrideWith((ref) async => weeklySummary(
              now: DateTime(2026, 10, 3, 9),
              sessions: const [],
              meals: const [],
              weights: const [],
            )),
        strengthCardProvider.overrideWith((ref) async => const []),
        measurementsProvider.overrideWith((ref) async => const []),
      ],
    ));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('home_date')), findsOneWidget);
    expect(find.byKey(const Key('home_greeting')), findsOneWidget);
    expect(find.byKey(const Key('home_sign_out_button')), findsOneWidget);
    expect(find.byKey(const Key('today_nutrition_card')), findsOneWidget);
    expect(find.byKey(const Key('today_no_program')), findsOneWidget);
    for (final tile in ['home_tile_weight', 'home_tile_week', 'home_tile_strength', 'home_tile_measurement']) {
      expect(find.byKey(Key(tile)), findsOneWidget, reason: tile);
    }
    // Eski kartlar yok.
    expect(find.byKey(const Key('home_targets_card')), findsNothing);
    expect(find.byKey(const Key('weight_card')), findsNothing);
  });

  testWidgets('without a profile it shows the no-profile message', (tester) async {
    await tester.pumpWidget(testApp(
      const HomeScreen(),
      scaffold: false,
      overrides: [profileProvider.overrideWith((ref) async => null)],
    ));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('home_list')), findsNothing);
  });
}
```

(`today_no_program` anahtarı `TodayWorkoutCard`'ın mevcut "aktif program yok" satırıdır; `today_workout_card_test.dart:75`.)

- [ ] **Step 2: Testi çalıştır, başarısız olduğunu gör**

Run: `flutter test --no-pub test/features/onboarding/presentation/home_screen_test.dart`
Expected: FAIL (`home_date` bulunamadı; eski kartlar var).

- [ ] **Step 3: `home_screen.dart`'ı yeniden yaz**

```dart
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/text_case.dart';
import '../../../shared/widgets/section_header.dart';
import '../../nutrition/presentation/widgets/today_nutrition_card.dart';
import '../../progress/presentation/widgets/home_stat_grid.dart';
import '../../workout/application/session_providers.dart';
import '../../workout/presentation/widgets/today_workout_card.dart';
import '../application/auth_providers.dart';
import '../application/onboarding_wizard_notifier.dart';
import '../application/profile_providers.dart';
import '../domain/home_greeting.dart';

/// Ana sayfa (spec §5): başlık, beslenme halkası, bugünkü antrenman, 2×2 özet.
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileAsync = ref.watch(profileProvider);
    final now = ref.watch(nowProvider)();
    return Scaffold(
      key: const Key('home_screen'),
      appBar: AppBar(
        title: Text('home.title'.tr()),
        actions: [
          IconButton(
            key: const Key('home_sign_out_button'),
            icon: const Icon(Icons.logout),
            onPressed: () {
              ref.invalidate(onboardingWizardProvider);
              ref.read(authRepositoryProvider).signOut();
            },
          ),
        ],
      ),
      body: profileAsync.when(
        data: (profile) {
          if (profile == null) {
            return Center(child: Text('home.no_profile'.tr()));
          }
          return ListView(
            key: const Key('home_list'),
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
            children: [
              _HomeHeader(now: now),
              const SizedBox(height: 16),
              TodayNutritionCard(profile: profile),
              const SizedBox(height: 12),
              const TodayWorkoutCard(),
              SectionHeader('home.section_progress'.tr()),
              HomeStatGrid(profile: profile),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stackTrace) => Center(child: Text('home.load_error'.tr())),
      ),
    );
  }
}

class _HomeHeader extends StatelessWidget {
  const _HomeHeader({required this.now});

  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final date = '${'home.weekday_${now.weekday}'.tr()}, ${now.day} ${'home.month_${now.month}'.tr()}';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          upperCaseFor(date, context.locale.languageCode),
          key: const Key('home_date'),
          style: theme.textTheme.labelMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant, letterSpacing: 1),
        ),
        const SizedBox(height: 4),
        Text(greetingKey(now).tr(), key: const Key('home_greeting'), style: theme.textTheme.headlineMedium),
      ],
    );
  }
}
```

- [ ] **Step 4: Ekran testini çalıştır, geçtiğini gör**

Run: `flutter test --no-pub test/features/onboarding/presentation/home_screen_test.dart`
Expected: PASS (2 test).

- [ ] **Step 5: Eski kartları ve testlerini kaldır**

```bash
git rm lib/features/progress/presentation/widgets/targets_card.dart \
       lib/features/progress/presentation/widgets/body_weight_card.dart \
       lib/features/progress/presentation/widgets/strength_card.dart \
       lib/features/progress/presentation/widgets/measurements_card.dart
```

Test dosyalarında:

1. `home_cards_test.dart`: `targets_card.dart` importunu ve `testWidgets('targets card shows the calorie and protein targets', …)` bloğunu (üstündeki iki satırlık yorumla birlikte) sil. Weekly summary testleri kalır.
2. `weight_test.dart`: `body_weight_card.dart` importunu ve `group('card', () { … });` bloğunun tamamını sil. `openAddDialog`'u ekrandan açacak şekilde değiştir:

   ```dart
   Future<void> openAddDialog(WidgetTester tester) async {
     await tester.pumpWidget(testApp(const WeightScreen(), overrides: overrides(), scaffold: false));
     await tester.pumpAndSettle();
     await tester.tap(find.byKey(const Key('weight_screen_add')));
     await tester.pumpAndSettle();
   }
   ```

3. `strength_test.dart`: `strength_card.dart` importunu ve `group('card', () { … });` bloğunu sil.
4. `measurements_test.dart`: `measurements_card.dart` importunu ve `group('card', () { … });` bloğunu sil. `openAddForm`'u değiştir:

   ```dart
   Future<void> openAddForm(WidgetTester tester) async {
     await tester.pumpWidget(testApp(const MeasurementsScreen(), overrides: overrides(), scaffold: false));
     await tester.pumpAndSettle();
     await tester.tap(find.byKey(const Key('measurements_screen_add')));
     await tester.pumpAndSettle();
   }
   ```

5. Çevirilerden eski anahtarları sil:

   ```bash
   python -c "
   import json, collections
   for lang in ('tr', 'en'):
       p = f'assets/translations/{lang}.json'
       d = json.load(open(p, encoding='utf-8'), object_pairs_hook=collections.OrderedDict)
       for k in ('calorie_target', 'protein_target'):
           d['home'].pop(k)
       open(p, 'w', encoding='utf-8', newline='\n').write(json.dumps(d, ensure_ascii=False, indent=2) + '\n')
   "
   ```

6. Kalan referans olmadığını doğrula:

   Run: `grep -rn "TargetsCard\|BodyWeightCard\|StrengthCard\b\|MeasurementsCard\|home.calorie_target\|home.protein_target" lib test`
   Expected: çıktı yok.

- [ ] **Step 6: İlgili testleri çalıştır**

Run: `flutter test --no-pub test/features/onboarding/presentation/home_screen_test.dart test/features/progress/presentation/`
Expected: PASS. Bir dialog testi ekran üzerinden açıldığı için kayıttan sonra ekranın listesinde yeni değer görünmesini bekliyorsa (`weight_test.dart:72-82`), yalnız `repo.logged` ve dialogun kapandığını doğrulayan mevcut beklentiler yeterli; ek beklenti ekleme.

- [ ] **Step 7: Analyze**

Run: `flutter analyze --no-pub`
Expected: No issues found!

- [ ] **Step 8: Commit**

```bash
git add -A lib/features/onboarding/presentation/home_screen.dart lib/features/progress/presentation/widgets test/features/onboarding/presentation/home_screen_test.dart test/features/progress/presentation assets/translations
git commit -m "feat(home): switch home to ring and stat tile layout"
```

---

### Task 8: Doğrulama ve kayıt

**Files:**
- Modify: `PLAN.md` (Değişiklik Günlüğü tablosu)

- [ ] **Step 1: Tam test paketi**

Run: `flutter test --no-pub` (~6 dk; arka planda değil, ön planda 600 sn zaman aşımıyla)
Expected: Tüm testler geçer. Sayıyı not et (R1 öncesi: 323 + bu plandaki yeni testler − silinen kart testleri).

- [ ] **Step 2: Analyze**

Run: `flutter analyze --no-pub`
Expected: No issues found!

- [ ] **Step 3: Elle renk kontrolü**

Run: `grep -rn "Color(0x\|Colors\.\(red\|green\|blue\|orange\|grey\|black\|white\)" lib --include=*.dart | grep -v "lib/core/theme/"`
Expected: çıktı yok.

- [ ] **Step 4: Kullanıcı: release web build ve göz kontrolü**

Kullanıcıya kendi terminalinde çalıştırmasını söyle (bu makinede arka plan build'i bellek yüzünden öldürülüyor):

```powershell
cd D:\spor_takip
flutter build web --release --no-pub
cd build\web
python -m http.server 5555 --bind 127.0.0.1
```

Gizli pencerede `http://127.0.0.1:5555` → kontrol listesi:
1. Tüm uygulama koyu zeminli; yazılar okunur; ana butonlar neon yeşil, üzerindeki yazı koyu.
2. Başlıklar Montserrat (kalın, geniş), metinler Inter; Türkçe karakterler (ğ, ş, ı, İ) düzgün.
3. Ana sayfa: tarih + selam; kalori halkası bugünkü öğünlerle doluyor; protein çubuğu; karbonhidrat/yağ gramları.
4. Bir öğün ekleyip ana sayfaya dön → halka ilerledi.
5. Bugünkü antrenman kartı eskisi gibi çalışıyor (başla / devam et).
6. 4 kutu doğru değerleri gösteriyor; her birine dokununca kilo, geçmiş, güç, ölçüler ekranı açılıyor.
7. Alt menüde seçili sekme neon yeşil.
8. Kilo/güç/ölçü ekranlarındaki grafikler koyu zeminde görünür; dokununca ipucu okunur.
9. Diğer ekranlar (beslenme, antrenman, onboarding, giriş) koyu temada bozulmadan çalışıyor (düzenleri R2–R4'te yenilenecek).

- [ ] **Step 5: `PLAN.md` satırı ve commit**

`PLAN.md` Değişiklik Günlüğü tablosunun sonuna, gerçek bulgularla (test sayısı, manuel listede bulunan/düzeltilen sorunlar) bir satır ekle:

```markdown
| 2026-10-0X | **F5+ R1 (tasarım temeli + ana sayfa) tamamlandı** (`r1-tasarim-temeli` dalı, 8 görev): koyu tema + neon yeşil (#C6FF00), gömülü Montserrat/Inter, ortak bileşenler (SectionHeader, StatTile, RingProgress, MacroBar), grafik renkleri temadan. Ana sayfa: tarih + selam, bugünkü kalori halkası ve makrolar, bugünkü antrenman, 2×2 özet kutuları (kilo, bu hafta, güç, ölçü); eski hedef/kilo/güç/ölçü kartları kaldırıldı. Spec'ten sapmalar: buton metinleri büyük harf değil; kilo değişim rengi amaca göre. Otomatik: N Flutter testi geçiyor, `flutter analyze` temiz. Manuel: … |
```

```bash
git add PLAN.md
git commit -m "docs: record F5+ R1 verification"
```

Sonra kullanıcıya master'a birleştirmeyi sor (superpowers:finishing-a-development-branch).
