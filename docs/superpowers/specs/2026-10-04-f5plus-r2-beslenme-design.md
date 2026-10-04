# F5+ R2 — Beslenme Ekranı ve Fotoğrafla Öğün Ekleme: Tasarım Spec'i

> Durum: Bölümler kullanıcıyla tek tek onaylandı (2026-10-04). Sonraki adım: kullanıcı spec'i gözden geçirir → writing-plans ile R2 implementasyon planı.

## 1. Bağlam

F5+ görsel yenilemenin ikinci aşaması. Çerçeve, tasarım sistemi ve kurallar R1 spec'inde: `docs/superpowers/specs/2026-10-03-f5plus-r1-tasarim-temeli-design.md` (§3–§4). R2 bu temeli (`AppColors`, `AppTheme.dark()`, `SectionHeader`, `MacroBar`) kullanır, yeni tema değeri eklemez.

Kapsam: `NutritionScreen` ve `MealCaptureScreen` (+ `FoodItemEditTile`).

Maketler (git'e girmez): `.superpowers/brainstorm/r2/nutrition-layout.html`, `.superpowers/brainstorm/r2/capture-layout.html`.

## 2. Kararlar (kullanıcıyla onaylı)

| Konu | Karar |
|------|-------|
| Beslenme ekranı | **B · "Kalan" odaklı**: büyük kalan kcal + yatay bar + üç makro kutusu; öğün tipi başına ara toplamlı kart |
| Öğün ekleme ekranı | **B · Fotoğraf önde, kompakt**: seçimde iki büyük kutu; düzeltmede fotoğraf önizleme, açılır satırlar, sabit toplam + Kaydet |
| Gram değişimi | Kcal ve makrolar **orantılı** güncellenir (küçük davranış düzeltmesi) |
| Boş öğün tipleri | Beslenme ekranında gizli (bugünkü gibi) |

## 3. Beslenme Ekranı

**Üst kısım:** AppBar başlığı (`nutrition.screen_title`) kalır. Gövdenin başında ana sayfadaki tarih satırıyla aynı stilde (`labelMedium`, gri, harf aralığı 1, büyük harf) bugünün tarihi; tarih `nowProvider`'dan alınır.

**`RemainingCaloriesCard`** (yeni, `lib/features/nutrition/presentation/widgets/remaining_calories_card.dart`). Girdi: `MacroTotals eaten`, `double calorieTarget`, `double proteinTarget`. `surface` kart, radius 16.

| Durum | Koşul | Etiket | Büyük rakam | Bar | Alt satır |
|-------|-------|--------|-------------|-----|-----------|
| Normal | `target > 0`, `eaten <= target` | `KALAN` | `target − eaten` | `accent`, oran `eaten/target` | "{eaten} yenen / {target} hedef" |
| Aşım | `target > 0`, `eaten > target` | `AŞIM` | `eaten − target`, `error` renginde | dolu, `error` | aynı |
| Hedefsiz | `target <= 0` (profil yok/yükleniyor) | `YENEN` | `eaten` | yok | yok |

- Büyük rakam Montserrat 900 (`displaySmall` ya da tema eşdeğeri), yanında küçük gri "kcal". Sayılar yuvarlanır.
- Bar: yükseklik 7, radius 4, zemin `line`.
- Altında üç eşit makro kutusu (`line` zemin, radius 12): Protein `{p}/{pTarget} g` (hedef ≤ 0 ise yalnız `{p} g`), Karbonhidrat `{c} g`, Yağ `{f} g`. Karb./yağ hedefi yok (R1 kararı).
- Anahtarlar: kart `remaining_calories_card`, etiket `remaining_calories_label`, rakam `remaining_calories_value`.

**Öğün kartları:** `MealType.values` sırasıyla, yalnız öğünü olan tipler. Her tip için `SectionHeader` (başlık `nutrition.meal_type_*`), sağında o tipin kcal ara toplamı; altında `surface` kart, her yemek bir satır: solda ad ve yanında gri "· {g} g", sağda kcal. Satırlar arasında `line` ayırıcı. Ara toplam, tipin öğünlerine `sumMealMacros` uygulanarak hesaplanır.

**Boş gün:** kalan kartı yine gösterilir (yenen 0). Altında `nutrition_empty_state` anahtarlı "Bugün henüz öğün yok" metni ve kamera butonuna yönlendiren kısa ipucu. (Bugün boş durum tüm gövdeyi kaplıyor; bu görsel değişiklik kabul edildi.)

**FAB:** neon kare FAB (tema), `Icons.add_a_photo_outlined`, davranış aynı (`/nutrition/capture`).

**Yükleme / hata:** bugünkü gibi (merkezde gösterge / `nutrition.load_error`).

**Korunan anahtarlar:** `nutrition_screen`, `nutrition_add_meal_fab`, `nutrition_empty_state`. **Kaldırılan:** `nutrition_daily_totals` (düz metin toplam) ve `nutrition.daily_totals_with_target` çevirisi.

## 4. Öğün Ekleme Ekranı

### 4.1 Seçim adımı (`MealCaptureIdle`)

- "HANGİ ÖĞÜN?" etiketi (`labelMedium`, gri, büyük harf), dört `ChoiceChip`; seçili çip neon dolgulu (tema `chipTheme` ya da çip seviyesinde `selectedColor`).
- İki büyük kutu (yükseklik ~120, radius 16), dikey: **Fotoğraf çek** (`accent` zemin, `onAccent` yazı, kamera ikonu, alt yazı "Yapay zekâ yemekleri tanır") ve **Galeriden seç** (`surface` zemin, `line` çerçeve, galeri ikonu). Öğün seçilmeden ikisi de `%40` opaklıkta ve dokunulamaz.
- Anahtarlar: `capture_take_photo_button`, `capture_gallery_button`, `meal_type_*_chip` (aynı).

### 4.2 Bekleme durumları

Yükleme / analiz / kaydetme: merkezde neon `CircularProgressIndicator` + metin (aynı çeviriler). Yükleme hatası ve "Tekrar dene" (`capture_upload_error`, `capture_retry_button`) aynı, yeni stilde.

### 4.3 Düzeltme adımı (`MealCaptureReviewing`)

- **AppBar başlığı** öğün tipinin adı (`nutrition.meal_type_*`); diğer durumlarda `nutrition.capture_title`.
- **Fotoğraf önizleme:** ekran, seçilen fotoğrafın baytlarını kendi `State`'inde (`Uint8List? _photoBytes`) tutar; `Image.memory`, yükseklik ~140, radius 16, `BoxFit.cover`. Üzerinde sol altta yarı saydam etiket "{n} yemek bulundu" (`nutrition.items_found`). Bayt yoksa kutu gösterilmez. Anahtar `capture_photo_preview`.
- **Yapay zekâ bandı** (`capture_ai_failure_banner`) listenin üstünde, `error` tonlu zeminde; metinler aynı.
- **Yemek satırları** (`FoodItemEditTile`, açılır satır olarak yeniden yazılır):
  - Kapalı: solda ad (boşsa gri "Yeni yemek") ve altında gri "{g} g · P {p} g"; sağda Montserrat kcal (kontrol gerekiyorsa "—"). Dokununca açılır/kapanır. Satır anahtarı `food_item_row_$index`.
  - Açık: ad, gram, kcal, protein, karb., yağ alanları (2'li satırlarda) + sil butonu. Alanlar **satır açık olduğu sürece** görünür — `needsReview` false olunca kaybolmaz (bugünkü hata: ilk rakamda alanlar kayboluyor).
  - Açılış durumu: `needsReview` olan ve elle eklenen satırlar açık başlar; diğerleri kapalı. Açık/kapalı durumu satırın kendi `State`'inde tutulur (satırlar zaten `itemKeys` ile anahtarlı).
  - `needsReview` satırında "Kontrol" rozeti (`food_item_needs_review_badge_$index`). `grams <= 0` ise kırmızı "Gram gir" ipucu (`food_item_grams_hint_$index`).
  - Korunan alan anahtarları: `food_item_name_field_$index`, `food_item_grams_field_$index`, `food_item_calories_field_$index`, `food_item_protein_field_$index`, `food_item_carbs_field_$index`, `food_item_fat_field_$index`, `food_item_remove_button_$index`.
- **"+ Elle yemek ekle"** neon metin butonu (`capture_add_item_button`).
- **Sabit alt bar:** `surface` zemin, üstte `line` çizgisi; solda "TOPLAM", sağda canlı toplam kcal (`items` üzerinden `calories` toplamı, anahtar `capture_total_calories`); altında tam genişlik Kaydet (`capture_save_button`), `canSave` kuralı aynı.

### 4.4 Gram → kcal orantısı

**Saf fonksiyonlar** (`lib/features/nutrition/domain/food_item_scaling.dart`):

```dart
/// 1 gram başına kcal/makro. grams <= 0 ise null.
MacroTotals? perGramOf(FoodItem item);

/// perGram null ise yalnız grams değişir; değilse kcal/makrolar perGram × grams.
FoodItem withGrams(FoodItem item, double grams, MacroTotals? perGram);
```

**Durum:** `MealCaptureReviewing`'e `List<MacroTotals?> perGram` eklenir (yalnız istemcide, kaydedilmez; `itemKeys` gibi `items` ile aynı uzunlukta, ekleme/silmede birlikte güncellenir).

- Analiz bitince: `needsReview == false && grams > 0` olan her yemek için `perGramOf(item)`, diğerleri için `null`.
- **`updateItemGrams(int index, double grams)`** (yeni notifier metodu): `withGrams(items[index], grams, perGram[index])`. `perGram` değişmez — böylece alan geçici olarak boşalıp gram 0 olsa bile oran korunur.
- **`updateItem(int index, FoodItem updated)`** (ad / kcal / makro değişimi için, mevcut): öğeyi yazar ve kcal veya makrolardan biri değiştiyse `perGram[index] = perGramOf(updated)` ile oranı yeniden hesaplar (gram 0 ise `null`).
- `addManualItem` → `perGram` sonuna `null`; `removeItem` → aynı indeksten siler.
- Tile, gram alanında `onGramsChanged(double)`, diğer alanlarda `onChanged(FoodItem)` çağırır.
- Gram ölçeklendiğinde açık satırdaki kcal/makro alanları yeni değerleri göstermelidir (alanlar `TextEditingController` ile yönetilir ve dışarıdan gelen değer, alan odakta değilken senkronlanır).

## 5. Çeviriler

`tr.json` / `en.json` altında `nutrition.*`: `remaining`, `over`, `eaten_label`, `eaten_of_target`, `kcal`, `protein_short`, `carbs_short`, `fat_short`, `empty_hint`, `which_meal`, `take_photo_hint`, `items_found`, `new_item`, `grams_hint`, `needs_review_short`, `total`. Kullanılmayan `daily_totals_with_target` silinir. Tam anahtar listesi planda kesinleşir.

## 6. Test

- **Birim:** `perGramOf` (grams 0 → null, normal oran), `withGrams` (ölçekleme, null perGram → yalnız gram, 0'a inip geri çıkınca oran korunur).
- **Notifier:** analiz sonrası `perGram` doluluğu; `updateItemGrams` kcal/makroyu ölçekler; `updateItem` ile makro değişince oran yenilenir; ekleme/silmede `perGram` hizalı kalır.
- **`RemainingCaloriesCard`:** normal / aşım (`error` rengi, `AŞIM`) / hedefsiz (`YENEN`, bar yok); protein hedefli/hedefsiz metni.
- **`NutritionScreen`:** kart görünür; öğün tipi başlıkları ve ara toplamlar; boş gün (kart + `nutrition_empty_state`); FAB rotası. `nutrition_daily_totals` beklentisi kaldırılır.
- **`FoodItemEditTile`:** kapalı satır özeti; dokununca açılır; `needsReview` açık başlar; makro yazarken alanlar kaybolmaz; gram ipucu; sil.
- **`MealCaptureScreen`:** önizleme görünürlüğü (`pickImageOverride` baytlarıyla); AppBar'da öğün adı; canlı toplam gram değişince güncellenir; mevcut akış testleri (kapalı satırlarda önce satıra dokunarak) geçer.
- Kurallar (R1 ile aynı): tüm `flutter` komutları `--no-pub`; görev içinde yalnız ilgili test dosyaları; tam paket kullanıcının terminalinde `flutter test --no-pub -j 1`; `flutter analyze` "No issues found!".
- **Elle kontrol** (release web build, kullanıcının terminalinde): kalan / aşım / boş gün görünümü; fotoğraf çek/seç → önizleme; satır aç/kapa; gram değişince kcal ve toplam güncellenir; kontrol gereken yemekte makro yazarken alanlar kaybolmaz; kaydet → beslenme ekranına dönüş ve yeni öğün listede.

## 7. Riskler

- **Alan senkronu:** dışarıdan ölçeklenen değerin alana yazılması imleci bozabilir → yalnız odakta olmayan alanlar senkronlanır.
- **Önizleme belleği:** fotoğraf baytları ekran yaşadıkça bellekte; tek fotoğraf olduğu için kabul edilebilir. Ekrandan çıkınca serbest kalır.
- **Test değişimi:** kapalı satırlarda alanlar ağaçta olmadığı için mevcut ekran testleri satıra dokunma adımı ister.

## 8. Kapsam Dışı

- Gün değiştirme (dün / yarın).
- Kaydedilmiş öğünü düzenleme ya da silme.
- Beslenme listesinde fotoğraf küçük resimleri.
- Karbonhidrat / yağ hedefleri.
- Öğün tipini önceden seçili getirme (maketteki C seçeneği).
- Veritabanı, edge function ve rota değişiklikleri.
