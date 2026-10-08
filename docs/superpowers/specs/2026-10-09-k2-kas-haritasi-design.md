# K2 — Kas Haritası: Kadın Figürü ve Stitch Yerleşimi — Tasarım Spec'i

> Durum: Bölümler kullanıcıyla tek tek onaylandı (2026-10-09). Sonraki adım: kullanıcı spec'i gözden geçirir → writing-plans ile K2 implementasyon planı. Dal: `f5p-kas-haritasi-k2`.

## 1. Bağlam

K1 (2026-10-09, master `9cfb6a1`) kas haritasını getirdi: erkek figürü, ön/arka görünüm, `MuscleMapScreen`, hareket seçicide "Haritadan seç" alt sayfası. K1 spec §10'daki dört K2 maddesinden kullanıcı ikisini seçti:

1. **Kadın figürü**
2. **Stitch ile yerleşim iyileştirmesi**: kas haritası ekranı, "Haritadan seç" alt sayfası ve hareket seçici ekranının tamamı.

Isı haritası ve programdan haritaya bağlantı K3'e kalır (§9).

Mevcut kod:
- Veri: `lib/features/workout/domain/muscle_map_data.dart`. `tool/generate_muscle_paths.py` tarafından üretilir; `BodyView`, `bodySilhouettes`, `muscleShapes` görünüme göre tutulur.
- Domain: `lib/features/workout/domain/muscle_map.dart`. Tek `bodyCrop`, `BodyFit(size)`, `musclePaths`, `silhouettePath`, `muscleAt`, `musclesIn`.
- Widget'lar: `presentation/widgets/muscle_map.dart` (`MuscleMap`, `BodyViewToggle`) ve `widgets/muscle_map_sheet.dart` (`showMuscleMapSheet`).
- Ekranlar: `presentation/muscle_map_screen.dart`, `presentation/exercise_picker_screen.dart`.
- Profil: `profileProvider` (`FutureProvider<Profile?>`), `Profile.gender` (`Gender.male / female / unspecified`).
- Tema: `lib/core/theme/app_colors.dart`. Arka plan `#0E0F12`, kart `#181A20`, yükseltilmiş yüzey `#1F2128`, çizgi `#262830`, metin `#F2F3F5`, soluk metin `#8A8F98`, vurgu `#C6FF00`. Başlıklarda Montserrat, gövdede Inter.

## 2. Kararlar (kullanıcıyla onaylı)

1. **Figür seçimi:** Varsayılan figür profilden gelir. Kadın → kadın figürü; erkek ve belirtilmemiş → erkek figürü. Haritada ♂/♀ düğmesiyle o oturumluk değiştirilebilir; seçim kalıcı olarak saklanmaz.
2. **Yaklaşım 1:** Stitch taslakları tasarım aşamasında üretildi ve seçildi; seçilen yerleşim aşağıda yazılıdır. Uygulama tek dalda yapılır: önce veri ve domain, sonra yeniden yerleşim. Mevcut davranış ve test anahtarları korunur.
3. **Stitch taslakları:** Stitch'te "LevelUp Fit" projeleri var (tema: koyu, `#C6FF00`, Montserrat/Inter, 12 px köşe). Görseller `.superpowers/brainstorm/k2-stitch/` altında; bu klasör git'e girmez:
   - `muscle_map_screen.png`
   - `muscle_map_sheet.png`
   - `exercise_picker.png`

   Taslaklarda görünen ama kapsam dışında bırakılanlar: AppBar'daki filtre ikonu, figür kartındaki "ortala" düğmesi, "… ANTRENMANI BAŞLAT" butonu, "A-Z Sırala" düğmesi ve Latince kas adları.
4. **Figür verisi:** Stitch figürü kullanılmaz. Figür her zaman MIT lisanslı body-highlighter verisinden çizilir.

## 3. Veri

### 3.1 Kaynak dosyalar

Şu dosyalar `tool/body_highlighter/` altına kopyalanır ve değiştirilmez. Kaynak: `https://github.com/HichamELBSI/react-native-body-highlighter`, `main` dalı.

- `bodyFemaleFront.ts` — yaklaşık 32308 bayt
- `bodyFemaleBack.ts` — yaklaşık 22650 bayt
- `SvgFemaleWrapper.tsx` — yaklaşık 21276 bayt; iki `d="…"`: ön ve arka siluet

Lisans erkek figürüyle aynı (`LICENSE`, MIT, © 2022 ELABBASSI Hicham); mevcut `LICENSES/body-highlighter.txt` kaydı yeterli.

Kaynakta ölçülen değerler (2026-10-09):
- Kadın ön figür: kas parçaları x 6–635 / y 85–1428; siluet x 0–641 / y 88–1433.
- Kadın arka figür: kas parçaları x 828–1457 / y 218–1428; siluet x 822–1463 / y 206–1433.
- Bölge adları erkek figürüyle aynı. Tek fark: kadın arka görünümde `head` ve `ankles` yok; ikisi de zaten süs parçası.
- Yüksekliğe göre bölme:
  - `upper-back`: 54,9 / 162,2 / 54,9 / 162,1 (eşik 120: lats ya da orta sırt)
  - `gluteal`: 79,4 / 159,0 / 158,8 / 79,7 (eşik 80: kalça ya da abdüktör)

  Mevcut eşikler kadın figüründe de doğru ayırır.

### 3.2 Üretici `tool/generate_muscle_paths.py`

- **Kaynak tablosu:** Figür ve görünüm başına kaynak dosya, siluet dosyası ve x kaydırması:
  - erkek: ön 0, arka 724 (`BACK_SHIFT`)
  - kadın: ön 0, arka 822

  Kaydırma, arka görünümü ön görünümle aynı x aralığına taşır.
- **Kas eşlemesi:** Aynı tablolar (`FRONT_MUSCLES`, `BACK_MUSCLES`, `BACK_SPLIT`, `DECOR`, `SKIP`) iki figür için de kullanılır.
- **Eşik payı:** `BACK_SPLIT` eşiğine 0,25 birimden yakın bir yükseklik çıkarsa betik `SystemExit` ile durur. Böylece kaynak değişirse yanlış eşleme sessizce oluşmaz.
- **Çıktı (`muscle_map_data.dart`):**
  - `enum BodyFigure { male, female }`
  - `bodySilhouettes`: `Map<BodyFigure, Map<BodyView, List<double>>>`
  - `muscleShapes`: `Map<BodyFigure, Map<BodyView, List<MuscleShape>>>`
  - **Erkek verisinin korunması:** Erkek figürünün komut listeleri K1 çıktısıyla birebir aynı kalmalı. Plan bunu yeniden üretip farkı karşılaştırarak doğrular.
- **Çıktı satırı:** Figür ve görünüm başına şekil sayısı: erkek ön 88, erkek arka 69, kadın ön 90, kadın arka 64 (plan yazılırken gerçek kaynakla doğrulandı). Üretilen dosya yaklaşık 92 KB'tan 186 KB'a çıkar.
- `bodyCanvasWidth` / `bodyCanvasHeight` (724 × 1448) iki figür için de geçerli kalır; kaydırılmış kadın yolları bu tuvalin içindedir.

## 4. Domain (`muscle_map.dart`)

- `bodyCrops`: `Map<BodyFigure, Rect>`.
  - Erkek: `Rect.fromLTWH(40, 120, 644, 1250)`, değişmez.
  - Kadın: `Rect.fromLTWH(-10, 78, 661, 1365)`. Kaydırılmış siluetler x 0–641, y 88–1433 aralığında; her yanda 10 birim pay.
- `BodyFit(Size size, BodyFigure figure)`: figürün kırpma alanını kullanır.
- `musclePaths(figure, view)`, `silhouettePath(figure, view)`, `muscleAt(figure, view, canvasPoint)`, `musclesIn(figure, view)`: önbellek anahtarı `(figure, view)`.
- `BodyFigure figureFor(Gender? gender)`: `Gender.female` → `female`, diğer her durum (null dahil) → `male`.
- **Değişmezlik:** Her görünümde `musclesIn(female, v) == musclesIn(male, v)`.

## 5. Arayüz

### 5.1 Ortak parçalar

- **`MuscleMap`:** Bir `figure` parametresi alır (varsayılan `BodyFigure.male`). Seçili kas lime dolguyla çizilir; altına aynı yolun blur'lu (`MaskFilter.blur`) yarı saydam lime kopyası parlama olarak çizilir.
- **`FigureToggle`:** ♂/♀ simgeli iki parçalı hap.
  - Anahtarlar: `figure_toggle_male`, `figure_toggle_female`.
  - Erişilebilirlik etiketleri: `workout.muscle_map.figure_male` / `figure_female`.
  - Seçili parça yükseltilmiş yüzey rengiyle dolgulu ve lime simgeli; seçili olmayan parça soluk renkli.
- **`MuscleMapControls`:** Solda `BodyViewToggle`, sağda `FigureToggle`; araları `Spacer`.
- **`MuscleMapCard`:** Figürü saran kart.
  - Görünüm: kart rengi, 16 px köşe, ince noktalı doku (`CustomPainter`, çizgi rengi, 16 px aralık).
  - İsteğe bağlı `label` sol üstte hap olarak görünür: lime nokta, kas adı, ince lime çerçeve; anahtarı `muscle_map_card_label`.
  - Sınırlı yükseklik ister.
- **`equipmentIcon(String? equipment)`:** `equipmentTypes` değerlerini `IconData`'ya eşler; bilinmeyen ya da null için `Icons.fitness_center`. Kesin eşleme planda belirlenir.
- **`ExerciseIconBadge`:** 40 px yuvarlak, yükseltilmiş yüzey rengi zemin, lime ikon.

### 5.2 Figür durumu

- `mapFigureProvider`: `NotifierProvider<…, BodyFigure>`.
  - İlk değer `figureFor(profileProvider.valueOrNull?.gender)`.
  - Profil yüklendiğinde, kullanıcı henüz elle değiştirmemişse figür profile uyar.
  - Elle seçim uygulama açık kaldığı sürece geçerlidir; ekran ve alt sayfa aynı değeri paylaşır.
  - Kalıcı saklama yok.

### 5.3 Kas haritası ekranı (`muscle_map_screen.png`)

Yukarıdan aşağıya:

1. **AppBar:** Başlık `workout.muscle_map.title`, büyük harf, Montserrat w900.
2. **Kontrol satırı:** `MuscleMapControls`, 16 px kenar boşluğu.
3. **Figür kartı:** `MuscleMapCard`, yüksekliği ekranın yaklaşık %45'i.
4. **Başlık satırı:** Solda büyük kas adı (titleLarge, w900, büyük harf; anahtar `muscle_map_selected`), aynı satırda soluk renkte "N hareket" (`muscle_map_count`). Sağda "İkincil dahil" çipi (`muscle_map_secondary_chip`). Dar ekranda sayı alta kayabilir; taşma olmaz.
5. **Liste:** Kart içinde. Her satır:
   - Başında `ExerciseIconBadge`
   - Hareket adı
   - Alt yazı: ekipman · seviye · özel
   - Sonda ok işareti

   Satıra dokununca detay açılır (`selectable: false`).

Kas seçili değilken ipucu (`muscle_map_hint`) gösterilir; boş, yükleniyor ve hata durumları K1'deki gibi kalır.

### 5.4 Kas seç alt sayfası (`muscle_map_sheet.png`)

- Tutamaç; başlık satırında solda "KAS SEÇ" (`workout.muscle_map.pick_title`, büyük harf, w900), sağda yuvarlak kapatma düğmesi (`muscle_map_sheet_close`).
- `MuscleMapControls`.
- `MuscleMapCard`. Kas seçiliyse sol üstte o kasın adı hap olarak görünür.
- En altta soluk ipucu: `workout.muscle_map.sheet_hint` — "Bir kasa dokun — liste o kasa süzülür".
- Davranış aynı: kasa dokununca sayfa o kasla kapanır; kapatma düğmesi ya da dışarı dokunma `null` döner.

### 5.5 Hareket seçici (`exercise_picker.png`)

- **AppBar:** Başlık büyük harf, w900.
- **Arama:** Hap biçimli alan (`exercise_search_field`). Metin varken sağda temizleme düğmesi (`exercise_search_clear`) görünür; metni ve `_query`'yi sıfırlar.
- **Kas çipleri:** `muscle_filter_row`. Baştaki "Haritadan seç" çipi (`muscle_filter_map`) figür ikonlu ve lime çerçeveli; kas seçiliyken de bu görünüm değişmez.
- **Ekipman çipleri:** `equipment_filter_row`, değişmez.
- **Sayı satırı:** Soluk renk, büyük harf, harf aralıklı "N HAREKET" (`exercise_picker_count`, çeviri `workout.picker_count`). Yalnız veri yüklendiğinde görünür.
- **Liste:** Kart içinde. Her satır (`exercise_tile_<id>`):
  - Başında `ExerciseIconBadge`
  - Hareket adı
  - Alt yazı: birincil kaslar ` · ` ile
  - Özel harekette adın yanında küçük "ÖZEL" rozeti (lime çerçeve ve metin; yeni çeviri `workout.custom_badge_short`, büyük harfle; anahtar `exercise_custom_badge_<id>`). Bu rozet alt yazıdaki "Senin hareketin" ekinin yerini alır.
  - Sonda ok işareti
- Dokununca detay, uzun basınca (özel harekette) silme ve FAB aynı kalır.

### 5.6 Çeviriler (TR / EN)

`workout.muscle_map.*` altına:

| Anahtar | TR | EN |
|---|---|---|
| `pick_title` | "Kas seç" | "Pick a muscle" |
| `sheet_hint` | "Bir kasa dokun — liste o kasa süzülür" | "Tap a muscle — the list filters to it" |
| `figure_male` | "Erkek figürü" | "Male figure" |
| `figure_female` | "Kadın figürü" | "Female figure" |

`workout.*` altına:

| Anahtar | TR | EN |
|---|---|---|
| `picker_count` | "{n} hareket" | "{n} exercises" |
| `picker_search_clear` | "Aramayı temizle" | "Clear search" |
| `custom_badge_short` | "Özel" | "Custom" |

## 6. Hata ve kenar durumları

- Profil yüklenemezse ya da `null` ise erkek figürü gösterilir.
- Figür değişince seçili kas korunur; kas iki figürde de aynı olduğu için her zaman geçerlidir.
- Dar ekran (yaklaşık 360 px): kontrol satırı, başlık satırı ve seçicinin çip satırları taşmaz; çip satırları yatay kaydırılır.

## 7. Testler (TDD)

- **Veri** (`muscle_map_data_test`):
  - Her figür ve görünüm için şekiller boş değil ve kas adları `muscleGroups` içinde.
  - Kadın figürünün kas kümeleri her görünümde erkek figürününkiyle aynı.
  - Kadın figüründe örnek noktalarda dokunuş doğru kası veriyor: ön görünümde göğüs ve karın; arka görünümde lats, orta sırt, kalça ve abdüktör. Noktalar planda ölçülerek belirlenir.
  - Siluetler figürün kırpma alanı içinde.
- **Domain:**
  - `figureFor` üç cinsiyet ve `null` için doğru figürü veriyor.
  - `BodyFit(size, female)` ölçek ve ortalamayı doğru yapıyor.
  - Mevcut `muscleAt` testleri iki figür için de geçiyor.
- **Widget:**
  - `FigureToggle` geçişi.
  - `MuscleMap` kadın figürüyle çiziliyor ve dokunuşa yanıt veriyor.
  - `MuscleMapCard` etiketi gösteriyor.
- **Ekranlar:**
  - Kadın profilinde varsayılan figür kadın.
  - ♂/♀ geçişi seçili kası koruyor.
  - Alt sayfada etiket, kapatma ve seçim davranışı.
  - Seçicide temizleme düğmesi, sonuç sayısı, ÖZEL rozeti ve harita çipi.
- **Mevcut testler:** Hepsi yeniden geçmeli; anahtarlar korunur.

## 8. Dal, sıra, manuel kontrol

Dal: `f5p-kas-haritasi-k2`, master'dan açılır.

Görev sırası:
1. Kaynak dosyalar ve üretici betik
2. Domain
3. Ortak widget'lar ve `mapFigureProvider`
4. Kas haritası ekranı
5. Alt sayfa
6. Hareket seçici
7. Doğrulama

Doğrulama adımları:
- `flutter analyze`
- Tam test paketi, kullanıcının terminalinde `-j 1`
- Web release derlemesi: `flutter build web --release --no-pub`, kullanıcı kendi terminalinden sunar

Manuel kontrol listesi:
1. Kadın profilinde harita kadın figürüyle açılıyor; ön ve arka görünüm düzgün, kesik ya da kayma yok.
2. ♂/♀ geçişi figürü değiştiriyor ve seçili kas korunuyor; seçim ekrandan alt sayfaya taşınıyor.
3. Kadın figüründe göğüs, kanat, kalça ve abdüktör dokunuşları doğru kası seçiyor.
4. Kas haritası ekranı taslağa benziyor: figür kartı, parlama, başlık satırı, ikonlu liste.
5. Alt sayfa taslağa benziyor; etiket hapı ve kapatma düğmesi çalışıyor.
6. Hareket seçici taslağa benziyor; arama temizleme, sonuç sayısı, ÖZEL rozeti ve ikonlar doğru.
7. Haritadan seçilen kas listeyi süzüyor; ilgili çip seçili görünüyor.
8. Yaklaşık 360 px genişlikte taşma yok.

## 9. Kapsam dışı (K3 ve sonrası)

- Isı haritası
- Programdan haritaya bağlantı
- Listede A-Z sıralama
- Seçicide filtre ikonu
- "Antrenmanı başlat" butonu
- Figür seçiminin kalıcı ayarı
- Latince kas adları
