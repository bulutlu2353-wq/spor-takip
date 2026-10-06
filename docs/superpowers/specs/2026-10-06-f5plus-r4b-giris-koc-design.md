# F5+ R4b — Giriş/Kayıt, Onboarding ve Antrenör: Tasarım Spec'i

> Durum: Bölümler kullanıcıyla tek tek onaylandı (2026-10-06). Sonraki adım: kullanıcı spec'i gözden geçirir → writing-plans ile R4b implementasyon planı.

## 1. Bağlam

F5+ görsel yenilemenin son aşaması (R4'ün ikinci yarısı). Çerçeve ve tasarım sistemi R1 spec'inde: `docs/superpowers/specs/2026-10-03-f5plus-r1-tasarim-temeli-design.md` (§3–§4). R4b; `AppTheme.dark()`, `AppColors`, `AppFonts` ve `upperCaseFor` kullanır, yeni tema değeri eklemez.

Kapsam:
- `LoginScreen`, `RegisterScreen` (`lib/features/onboarding/presentation/`)
- Onboarding sihirbazı: `WizardStepScaffold`, `NumericStepScreen`, `ChoiceStepScreen`, `TextStepScreen` (`steps/step_scaffolds.dart`), adım tanımları (`steps/onboarding_step_widgets.dart`), `OnboardingWizardScreen` hata ekranı
- `CoachScreen` kilitli tanıtım (`_CoachLocked`) ve sohbet görünümü (`_CoachChat`, `MessageBubble`) (`lib/features/chat/presentation/`)

Maketler (git'e girmez): `.superpowers/brainstorm/r4b/auth-layout.html`, `onboarding-layout.html`, `coach-layout.html`.

## 2. Kararlar (kullanıcıyla onaylı)

| Konu | Karar |
|------|-------|
| Giriş/kayıt | **A · Ortalanmış logo**: neon kare "S" + "SPOR TAKİP" yazısı + slogan, altında form, Google öncesi "veya" ayracı, geçiş bağlantısı formun sonunda |
| Onboarding | **A**: parçalı neon adım çubuğu, neon "ADIM x/y", büyük Montserrat soru, ikonlu seçim kartları, büyük ortalı sayı + birim |
| Antrenör tanıtım | **A**: neon rozet, büyük başlık, 2×3 özellik kutuları, neon sol çizgili not |
| Sohbet | Mockup yok; yalnız görsel restil (neon kullanıcı balonu, kart AI balonu, neon gönder) |
| Davranış | Hiçbir yerde değişmez: akışlar, doğrulamalar, kayıt, hata metinleri, `coachEnabledProvider=false` kilidi aynen |
| Dal | Tek dal `r4b-giris-koc`, tek spec + tek plan |

## 3. Giriş / Kayıt

### 3.1 `AuthHeader` (`lib/features/onboarding/presentation/widgets/auth_header.dart`)

- Girdi: `String tagline`.
- Görünüm (ortalı sütun):
  - 56×56 neon (`AppColors.accent`) kare, radius 16; içinde "S", Montserrat 900, 30px, `onAccent`.
  - 16 boşluk; `app.title` büyük harfe çevrilmiş (`upperCaseFor`), Montserrat 900, 26px, harf aralığı 1: ilk kelime `onSurface`, kalan kelimeler `primary` (tek `Text.rich`). "Spor Takip" → "SPOR **TAKİP**".
  - 6 boşluk; `tagline`, `bodyMedium`, `onSurfaceVariant`.
- Anahtar: `auth_header`.

### 3.2 Ekran iskeleti (iki ekran)

`Scaffold` → `SafeArea` → `Center` → `SingleChildScrollView` (padding 24) → `ConstrainedBox(maxWidth: 420)` → `Column(crossAxisAlignment: stretch)`. Klavye açıldığında kayar; geniş ekranda form 420'yi geçmez.

### 3.3 `LoginScreen`

Yukarıdan aşağı:
1. `AuthHeader(tagline: 'auth.login_tagline'.tr())`, 32 boşluk.
2. E-posta, şifre alanları (anahtarlar aynen).
3. "Şifremi unuttum" `TextButton` sağa yaslı (`Align.centerRight`), şifre alanının hemen altında.
4. Hata metni (varsa, aynen).
5. `FilledButton` (`login_submit_button`), yükleniyor göstergesi aynen.
6. "veya" ayracı: `Row` [`Divider` | `auth.or` gri `bodySmall` | `Divider`], dikey 16. Anahtar `auth_or_divider`.
7. Google `OutlinedButton.icon` (`login_google_button`) aynen.
8. 16 boşluk; kayıt bağlantısı `TextButton` (`login_go_to_register_button`) formun sonunda (alta sabitlenmez).

`auth.login_title` ekranda artık gösterilmez.

### 3.4 `RegisterScreen`

1. `AuthHeader(tagline: 'auth.register_tagline'.tr())`, 32 boşluk.
2. E-posta, şifre, şifre tekrar alanları; hata metni (aynen).
3. `FilledButton` (`register_submit_button`).
4. Girişe dön `TextButton` (`context.pop()`) formun sonunda.

`auth.register_title` ekranda artık gösterilmez. Kayıt ekranına Google butonu eklenmez.

## 4. Onboarding sihirbazı

### 4.1 `WizardStepScaffold`

- `LinearProgressIndicator` yerine dosyaya özel `_StepSegments(current, total)`: `total` adet eşit genişlikte parça (yükseklik 4, radius 2, aralık 4); `index < current` olanlar `primary`, kalanlar `AppColors.line`. Anahtar `wizard_step_segments`; her parça `wizard_segment_$i`.
- 12 boşluk; adım etiketi: `onboarding.step_of` büyük harf (`upperCaseFor`) → "ADIM 3/9", `labelMedium`, `primary`, Montserrat 800, harf aralığı 1.
- 12 boşluk; soru başlığı `headlineMedium` (tema zaten Montserrat 800).
- 24 boşluk; `Expanded(child)`.
- Alt buton: `ElevatedButton` → tam genişlik `FilledButton`, anahtar `wizard_next_button` aynen.
- Geri butonu AppBar'da aynen.

### 4.2 `ChoiceStepScreen`

- Seçenek kaydı `(T value, String label)` → `(T value, String label, IconData icon)`.
- `RadioGroup` + `RadioListTile` kalkar; `ListView` içinde her seçenek için dosyaya özel `_ChoiceCard` (aralık 10):
  - `Material` + `InkWell`, radius 16, `AppColors.surface` zemin; kenarlık seçiliyse 2px `primary`, değilse 1px `AppColors.line`.
  - İç boşluk 16; `Row`: neon ikon (24) · 14 · etiket (`titleMedium`, 600, `Expanded`) · seçiliyse `Icons.check_circle` `primary`.
  - Anahtar `choice_option_${value}` aynen; `onTap` → `onSave(value)`.
- İkonlar:
  - Cinsiyet: `male`, `female`, `person_outline`
  - Aktivite: `weekend_outlined`, `directions_walk`, `directions_run`, `fitness_center`, `bolt`
  - Spor yapıyor mu: `check`, `close`
  - Hedef: `trending_down`, `fitness_center`, `balance`

### 4.3 `NumericStepScreen`

- Yeni isteğe bağlı parametre `String? unit`.
- `child`: `Center` → `Row(mainAxisSize: min, crossAxisAlignment: baseline)`:
  - `TextField` (`numeric_step_field` aynen) genişlik `IntrinsicWidth` ile içeriğe göre (en az 120), `textAlign: center`, stil Montserrat 900 56px; `InputDecoration.collapsed(hintText: ...)` (kenarlık/dolgu yok), ipucu aynı boyutta `onSurfaceVariant` ile.
  - `unit` varsa 8 boşluk + birim metni `titleLarge`, `onSurfaceVariant`.
- Birimler: kilo "kg", boy "cm", haftalık gün `onboarding.days_unit` ("gün"/"days"); doğum yılı birimsiz. "kg"/"cm" çevrilmez (sabit).
- Doğrulama (min/max), kayıt ve `initialValue` davranışı aynen.

### 4.4 `TextStepScreen` ve hata ekranı

- `TextStepScreen`: düzen aynen, tema stilini alır.
- `OnboardingWizardScreen` kayıt hatası ekranındaki `ElevatedButton` → `FilledButton` (metin aynen).

## 5. Antrenör

### 5.1 Kilitli tanıtım (`_CoachLocked`)

AppBar aynen. Gövde `SingleChildScrollView` (`coach_locked` anahtarı korunur), padding 24, `maxWidth: 480`, `Column(crossAxisAlignment: start)`:
1. Rozet: `Container` neon zemin, radius 8, yatay 10 / dikey 4; `coach.locked_badge` büyük harf, `labelSmall`, Montserrat 800, `onAccent`, harf aralığı 1. Anahtar `coach_locked_badge`.
2. 16 boşluk; başlık `coach.locked_title`, satırları `\n` ile ayrılmış metin ("Yapay zekâ\nantrenörün\nyakında."); `upperCaseFor`, Montserrat 900, `headlineMedium` boyutu, satır yüksekliği 1.05. Tek `Text.rich`: ikinci satır `primary`, diğerleri `onSurface` (maketteki gibi "ANTRENÖRÜN" neon). Anahtar `coach_locked_title`.
3. 10 boşluk; `coach.locked_body` `bodyMedium`, `onSurfaceVariant`.
4. 20 boşluk; özellik ızgarası: `GridView.count(crossAxisCount: 2, shrinkWrap, physics: never, mainAxisSpacing/crossAxisSpacing 10, childAspectRatio 1.6)`; her kutu `AppColors.surface`, radius 16, padding 14: üstte neon ikon (22), altta metin `bodySmall` 600. Mevcut `_lockedFeatures` aynen; anahtar `coach_feature_$i`.
5. 20 boşluk; not: `Container` sol kenarlığı 3px `primary`, zemin `AppColors.surface`, radius 8 (sağ köşeler), padding 12; `coach.locked_note` `bodySmall`, `onSurfaceVariant`.
- Üstteki `construction_outlined` ikonu ve `Chip` kalkar.

### 5.2 Sohbet (`_CoachChat`, yalnız görsel)

- `MessageBubble`: kullanıcı balonu zemin `primary`, metin `onPrimary`; AI balonu zemin `AppColors.surface`, 1px `AppColors.line` kenarlık, metin `onSurface`. Radius 16; konuşanın tarafındaki alt köşe 4 (kullanıcı: sağ alt, AI: sol alt). Anahtar `bubble_${id}` aynen.
- `_InputBar`: `TextField`'daki `border: OutlineInputBorder()` kaldırılır (tema input stili); gönder `IconButton.filled` (`coach_send` aynen, `Icons.arrow_upward`), tema `primary` zemin.
- `_Suggestions`: üstteki `forum_outlined` ikonu `primary` renk alır; `ActionChip` → dosyaya özel `_SuggestionChip` (`Material` + `InkWell`, radius 20, 1px `primary` kenarlık, yatay 14 / dikey 8, `bodySmall` 600). `AccentChip` seçili/seçisiz filtre çipi olduğu için burada kullanılmaz. Anahtarlar `coach_suggestion_$i` aynen.
- `ConfirmCard`, `_UnsentRow`, kota metni, yazıyor göstergesi, yükleme/hata durumları: düzen aynen, tema stili.

## 6. Çeviriler (tr / en)

Eklenir:
- `auth.login_tagline`: "Beslenme · Antrenman · İlerleme" / "Nutrition · Training · Progress"
- `auth.register_tagline`: "Hesabını oluştur" / "Create your account"
- `auth.or`: "veya" / "or"
- `onboarding.days_unit`: "gün" / "days"
- `coach.locked_title`: "Yapay zekâ\nantrenörün\nyakında." / "Your AI\ncoach is\ncoming soon."

Değişir:
- `coach.locked_body`: "Sohbet ederek şunları yapabileceksin:" / "By chatting you'll be able to:"

Silinir (artık kullanılmaz): `auth.login_title`, `auth.register_title`.

## 7. Test

- Widget: `AuthHeader` (başlık metni, slogan); `_StepSegments` parça sayısı = toplam adım, `current` kadarı `primary`.
- Ekran testleri (mevcut dosyalar genişler):
  - Giriş: `auth_header` ve `auth_or_divider` var; mevcut giriş/Google/şifremi unuttum/kayıt geçişi testleri aynen geçer.
  - Kayıt: `auth_header` var; mevcut testler aynen.
  - Onboarding: seçim kartına dokununca seçim kaydedilir ve `Icons.check_circle` görünür; sayı adımında "kg" birimi görünür; adım çubuğu parça sayısı; mevcut sihirbaz akış testleri (`choice_option_*`, `numeric_step_field`, `wizard_next_button`) aynen geçer.
  - Antrenör: kilitliyken `coach_locked_title` ve 6 `coach_feature_*` var; sohbet testlerinde kullanıcı balonunun zemini `primary`.
- Doğrulama: görev içinde yalnız ilgili testler; sonunda kullanıcının terminalinde `flutter test --no-pub -j 1`, `flutter analyze` temiz, web release derlemesi ve elle kontrol listesi. Sohbet ekranı kilitli olduğundan elle değil yalnız widget testleriyle doğrulanır.

## 8. Kapsam dışı

Davranış/akış değişiklikleri, kayıt ekranına Google girişi, antrenör kilidinin açılması, `ConfirmCard`/kart gövdelerinin yeniden tasarımı, onboarding adımlarının sırası veya içeriği, light tema.
