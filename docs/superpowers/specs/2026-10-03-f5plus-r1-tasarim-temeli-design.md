# F5+ R1 — Görsel Tasarım Temeli ve Ana Sayfa: Tasarım Spec'i

> Durum: Bölümler kullanıcıyla tek tek onaylandı (2026-10-03). Sonraki adım: kullanıcı spec'i gözden geçirir → writing-plans ile R1 implementasyon planı.

## 1. Bağlam ve Ayrıştırma

PLAN.md yol haritasındaki **F5+** satırı üç bağımsız alt projeye ayrıldı. Her biri kendi spec → plan → uygulama döngüsünden geçer:

1. **Görsel tasarım yenileme** (bu spec, R1–R4 aşamaları)
2. **Kas haritası**: erkek/kadın vücudu; kasa dokununca o kası çalıştıran hareketler (kullanıcı 3B istedi; Flutter web + düşük RAM'li makinede gerçek 3B'nin ağırlığı ve lisanslı anatomi modeli ihtiyacı o projenin brainstorming'inde konuşulacak, hafif alternatif dokunulabilir 2B ön/arka harita)
3. **Oyunlaştırma**: seviye, XP, kazanılan unvanlar

Sıra (onaylandı): tasarım → kas haritası → oyunlaştırma. Sonraki iki proje yeni ekranlar getireceği için tasarım dili önce oturur.

## 2. Kararlar (kullanıcıyla onaylı)

| Konu | Karar |
|------|-------|
| His | Enerjik / sportif (Nike Training, Strava) |
| Vurgu rengi | Neon yeşil `#C6FF00` |
| Tema modu | **Sadece koyu**; açık tema yok |
| Başlık yazı tipi | Montserrat (800/900) |
| Gövde yazı tipi | Inter (400/600) |
| Kapsam | Uygulamadaki ~18 ekranın **hepsi** tek tek yeniden düzenlenir |
| Yürütme | Önce tasarım sistemi, sonra ekran grupları (R1–R4), her aşama ayrı plan |
| Ana sayfa | "Halka + kutucuklar" düzeni (§5) |

Taslak görseller: `.superpowers/brainstorm/1586-1791016108/content/` (`palette.html`, `typography.html`, `home-layout.html`; git'e girmez).

## 3. Aşamalar

| Aşama | Dal | Kapsam |
|-------|-----|--------|
| **R1** | `r1-tasarim-temeli` | Tema, yazı tipleri, ortak bileşenler, alt menü, ana sayfa (bu spec'in detaylı kısmı) |
| R2 | `r2-...` | Beslenme ekranı, fotoğrafla öğün ekleme |
| R3 | `r3-...` | Programlar, program detayı, program düzenleyici, hareket seçici, antrenman oturumu, oturum özeti, geçmiş, geçmiş detayı (8 ekran); haftalık "bu hafta / geçen hafta" tablosu geçmiş ekranının başına taşınır |
| R4 | `r4-...` | Kilo, güç, ölçüler ekranları; Antrenör (kilitli tanıtım ekranı dahil); giriş, kayıt, onboarding |

**Tüm aşamalar için kurallar:**
- Her aşama kendi dalında, kendi planıyla yürür; bitince `master`'a birleştirilir.
- Aşama başında o grubun ekranları için taslak görseller hazırlanıp kullanıcıya onaylatılır (dosya olarak; görsel yardımcı sunucusu yalnız kullanıcı isterse açılır — düşük RAM).
- **Yalnız görünüm değişir, davranış aynı kalır**: veri, kayıt, Supabase, iş mantığı ve yönlendirme değişmez. Akış değişikliği gerekirse kullanıcıya ayrıca sorulur. İstisna: R1'deki ana sayfa düzeni (§5) ve R3'teki haftalık tablo taşıma.
- Ekran kodunda elle renk (`Color(0x…)`, `Colors.x`) yazılmaz; yalnız tema ve `lib/shared/widgets/` bileşenleri kullanılır.

## 4. Tasarım Sistemi (R1)

### 4.1 Tema

Konum: `lib/core/theme/` (`app_colors.dart`, `app_theme.dart`).

- `AppTheme.dark()` tek tema; `MaterialApp.router` → `theme: AppTheme.dark()`, `themeMode: ThemeMode.dark`. Uygulamada şu an özel tema ve elle yazılmış renk olmadığı için değişiklik buradan tüm ekranlara yayılır.
- **Renkler (`AppColors`):**

  | Ad | Değer | Kullanım |
  |----|-------|----------|
  | `background` | `#0E0F12` | Scaffold, alt menü |
  | `surface` | `#181A20` | Kart, dialog, alt sayfa |
  | `line` | `#262830` | Ayırıcı, boş çubuk/halka |
  | `text` | `#F2F3F5` | Ana metin |
  | `muted` | `#8A8F98` | İkincil metin, seçili olmayan menü |
  | `accent` | `#C6FF00` | Ana buton, seçili menü, halka, olumlu değişim |
  | `onAccent` | `#0E0F12` | Vurgu üstündeki metin/ikon |
  | `error` | `#FF5C5C` | Hata metni, hedef aşımı |

  Bunlardan `ColorScheme` (brightness: dark) kurulur; `primary=accent`, `onPrimary=onAccent`, `surface=surface`, `error=error` vb.
- **Yazı (`TextTheme`):** `display*`, `headline*`, `titleLarge` → Montserrat 800/900; `titleMedium` ve altı, `body*`, `label*` → Inter 400/600. Büyük rakamlar (kalori, kilo, 1RM) `headline*` stilini kullanır.
- **Yazı tipi dosyaları:** `assets/fonts/` altına yalnız kullanılan kalınlıklar (Montserrat 800, 900; Inter 400, 600) eklenir, `pubspec.yaml` `fonts:` bölümünde tanımlanır. Yeni paket eklenmez (bu makinede `pub get` ağda takılıyor; `google_fonts` çalışma anında indirir). Lisans: her ikisi SIL Open Font License; lisans metinleri `assets/fonts/` altına konur.
- **Bileşen temaları:** `CardTheme` (renk `surface`, köşe 16, gölge 0, kenar boşluğu yok), `FilledButtonTheme` (zemin `accent`, metin `onAccent`, Montserrat büyük harf, köşe 12, yükseklik 48), `OutlinedButtonTheme`/`TextButtonTheme` (vurgu renkli), `InputDecorationTheme` (dolu `surface`, köşe 12, odakta `accent` kenar), `NavigationBarTheme` (zemin `background`, seçili `accent`, diğer `muted`, gösterge saydam/ince), `AppBarTheme` (zemin `background`, gölge 0, başlık Montserrat), `ChipTheme`, `DialogTheme`, `SnackBarTheme`, `ProgressIndicatorTheme` (`accent`), `DividerTheme` (`line`).
- **Grafik yardımcı:** `fl_chart` renkleri temadan otomatik almaz. `lib/core/theme/chart_style.dart` çizgi/ızgara/eksen renk ve metin stillerini temadan üretir; R1'de mevcut grafiklere bağlanır (ekran düzenleri R4'te).

### 4.2 Ortak Bileşenler

Konum: `lib/shared/widgets/`. Her biri tek iş yapar, yalnız temaya bağımlıdır, ayrı widget testi vardır.

- **`SectionHeader(title)`** — küçük, büyük harf, `muted`, Montserrat 800 bölüm başlığı.
- **`StatTile({label, value, change?, positive?, emptyHint?, onTap})`** — `surface` zeminli kutu: üstte etiket, ortada büyük rakam, altta değişim satırı. `positive == true` ise değişim `accent`, değilse `muted`. `value == null` ise "—" ve `emptyHint` gösterir. Tüm kutu dokunulabilir (`InkWell`, köşe 16).
- **`RingProgress({value, target, center})`** — dairesel ilerleme (`CustomPainter`), boş kısım `line`, dolu kısım `accent`. `value > target` ise halka tam dolu ve `error` renkli. Ortaya verilen widget (rakam + "/ hedef") yerleşir. `target <= 0` ise boş halka. Dolma, basit bir `TweenAnimationBuilder` ile (~600 ms) canlandırılır.
- **`MacroBar({label, value, target?, unit})`** — etiket ve "yenen / hedef birim" satırı; `target` varsa altında ince çubuk (aşımda `error`), yoksa yalnız "yenen birim".
- Ana buton ayrı bileşen değildir: temadaki `FilledButton` stili kullanılır.

### 4.3 Alt Menü

`AppShell`'deki 4 sekme (Ana sayfa, Beslenme, Antrenman, Antrenör) aynı kalır; görünüm `NavigationBarTheme`'den gelir. Davranış değişmez.

## 5. Ana Sayfa (R1)

`HomeScreen` yukarıdan aşağıya:

1. **Başlık** — tarih (örn. "CUMA, 3 EKİM", uygulama diline göre) ve saate göre selam: 05–12 "Günaydın", 12–18 "İyi günler", 18–05 "İyi akşamlar" (EN karşılıkları). Profilde ad alanı yok; ad eklemek kapsam dışı. Saat `nowProvider`'dan alınır.
2. **`TodayNutritionCard`** (yeni, `lib/features/nutrition/presentation/widgets/`) — solda `RingProgress` (bugün yenen kcal / `dailyCalorieTarget`), sağda `MacroBar` protein (yenen / `dailyProteinTargetG`), karbonhidrat ve yağ (yalnız yenen gram; profilde hedefleri yok, yeni hedef hesabı kapsam dışı). Veri: `todayMealsProvider` + `profileProvider`. Karta dokununca `/nutrition`. Bugünkü toplamların hesabı saf bir fonksiyonda (mevcut toplam hesabı varsa o yeniden kullanılır).
3. **`TodayWorkoutCard`** — mevcut kart; yalnız görünüm (tema + gerekirse başlık stili). Davranış (başla / devam et / dinlenme günü / program seç) aynı.
4. **2×2 `StatTile` ızgarası:**

   | Kutu | Değer | Değişim | Dokununca | Kaynak |
   |------|-------|---------|-----------|--------|
   | Kilo | son kilo (kg) | 30 günlük fark | `/home/weight` | `weightLogsProvider` |
   | Bu hafta | antrenman sayısı | "N set" | `/workout/history` | `weeklySummaryProvider` |
   | Güç | ilk serinin tahmini 1RM'i (kg) + hareket adı | 30 günlük fark | `/home/strength` | `strengthCardProvider` |
   | Ölçü | bel; yoksa ilk ölçülen bölge (cm) | son iki ölçüm farkı | `/home/measurements` | `measurementsProvider` |

   Kilo ve bel için **düşüş** olumlu (`accent`), güç ve antrenman için **artış** olumlu. Veri yoksa "—" ve kısa yönlendirme ("Kilo gir", "Antrenman başlat", "Ölçü ekle"). Mevcut fark hesapları (`formatDelta`, `measurementChange`, 30 günlük değişim) yeniden kullanılır.

**Ana sayfadan kaldırılanlar:** `TargetsCard`, `WeeklySummaryCard`, `BodyWeightCard`, `StrengthCard`, `MeasurementsCard`. İçerikleri (grafik, tablo, ekleme butonları) detay ekranlarında zaten var; haftalık karşılaştırma tablosu R3'te geçmiş ekranına taşınır. `TargetsCard`, `BodyWeightCard`, `StrengthCard`, `MeasurementsCard` dosyaları ve testleri R1'de silinir (yalnız başka yerde kullanılmıyorlarsa). `WeeklySummaryCard` R3'te geçmiş ekranına taşınacağı için dosyası ve testi kalır.

**Yükleme / hata:** Her kart ve kutu kendi `AsyncValue`'sunu ayrı işler: yüklenirken iskelet (sabit yükseklikte `surface` kutu), hatada kısa hata metni. Bir kaynağın hatası diğerlerini engellemez (mevcut davranışla aynı).

**Yenileme:** Mevcut aşağı çekip yenileme (varsa) ve kayıt sonrası provider yenilemeleri aynen korunur; yeni kartlar aynı provider'ları izlediği için ek iş gerekmez.

## 6. Test

- `lib/shared/widgets/` her bileşen için widget testi: `RingProgress` (normal, hedef aşımı → `error`, `target<=0`), `MacroBar` (hedefli/hedefsiz, aşım), `StatTile` (değer, boş durum, `positive` rengi, dokunma callback'i), `SectionHeader`.
- `AppTheme.dark()` için birim testi: `brightness == dark`, `primary == accent`, başlık stillerinin yazı tipi ailesi Montserrat.
- `TodayNutritionCard`: toplam hesabı (saf fonksiyon) birim testi + kart widget testi (yenen/hedef metni, dokunca `/nutrition`).
- `HomeScreen`: yeni düzen widget testi (4 kutu, boş durumlar, kutuya dokunca doğru rota, saat bazlı selam `nowProvider` ile).
- Kaldırılan kartların testleri silinir; mevcut testler `Key` ile bulduğu için diğerleri geçmeli.
- Kurallar: tüm `flutter` komutları `--no-pub`; görev içinde yalnız ilgili test dosyaları, görev sonunda tam paket; `flutter analyze` "No issues found!".
- Manuel: release web build (kullanıcının terminalinde) + kısa göz kontrolü listesi: tüm ekranlar koyu ve okunur, butonlar neon, ana sayfa düzeni, kutulardan detay ekranlarına geçiş, grafikler koyu zeminde görünür.

## 7. Riskler

- **Kontrast:** neon yeşil yalnız koyu zeminde kullanılır; vurgu üstünde metin her zaman `onAccent`. İkincil metin `#8A8F98` koyu zeminde okunur seviyede (WCAG AA büyük metin).
- **Grafikler:** `fl_chart` varsayılan renkleri koyu zeminde kaybolabilir → `chart_style.dart` (§4.1).
- **Paket boyutu:** 4 yazı tipi dosyası ≈ 1 MB; yalnız kullanılan kalınlıklar eklenir.
- **Diğer ekranlar R1 sonunda "ara durumda" kalır:** tema sayesinde koyu ve tutarlı renkte olurlar ama düzenleri R2–R4'te yenilenir. Bu kabul edildi.

## 8. Kapsam Dışı

- Açık tema, tema seçimi ayarı.
- Profile ad alanı eklemek.
- Karbonhidrat/yağ hedefleri hesaplamak.
- Halka dolması dışında animasyon.
- Kas haritası ve oyunlaştırma (ayrı projeler).
