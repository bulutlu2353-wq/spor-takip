# F5+ R4a — İlerleme Ekranları: Tasarım Spec'i

> Durum: Bölümler kullanıcıyla tek tek onaylandı (2026-10-05). Sonraki adım: kullanıcı spec'i gözden geçirir → writing-plans ile R4a implementasyon planı.

## 1. Bağlam

F5+ görsel yenilemenin dördüncü aşamasının ilk yarısı. R4 kullanıcı kararıyla ikiye bölündü: **R4a** ilerleme ekranları (bu spec), **R4b** antrenör + giriş/kayıt/onboarding (ayrı dal, spec ve plan). Çerçeve ve tasarım sistemi R1 spec'inde: `docs/superpowers/specs/2026-10-03-f5plus-r1-tasarim-temeli-design.md` (§3–§4). R4a; `AppTheme.dark()`, `SectionHeader`, `upperCaseFor`, `AccentChip` (R3) ve `chart_style.dart`'ı kullanır, yeni tema değeri eklemez.

Kapsam (3 ekran): `WeightScreen`, `StrengthScreen`, `MeasurementsScreen` (`lib/features/progress/presentation/`).

Maket (git'e girmez): `.superpowers/brainstorm/r4a/progress-layout.html`.

## 2. Kararlar (kullanıcıyla onaylı)

| Konu | Karar |
|------|-------|
| Düzen | **B · Büyük sayı üstte**: güncel değer + seçili aralıktaki değişim, altında grafik kartı (aralık çipleri kartın içinde), altında kayıt listesi. Üç ekran aynı iskelet |
| Silme | Satırda kalır (gri çöp kutusu ikonu); diyaloglara silme eklenmez |
| Değişim rengi | Kilo: profil hedefine göre (`weightChangeIsGood`); güç: artış neon; ölçü: hep gri |
| Liste tarihi | "20 Eylül" (yıl yalnız farklıysa); grafik ipucu ve diyaloglar mevcut `formatShortDate` ile kalır |
| Diyaloglar | Yeniden düzenlenmez (tema ile zaten koyu/neon) |
| Davranış | Değişmez; yalnız görünüm ve liste tarih biçimi |

## 3. Ortak parçalar

### 3.1 `changeInRange` (`lib/features/progress/domain/trend.dart`)

`double? changeInRange(List<ValuePoint> points)`: girdi aralığa süzülmüş, eskiden yeniye noktalar. 2'den az nokta → `null`; aksi halde `points.last.value - points.first.value`.

### 3.2 `shortDateLabel` (`lib/shared/date_label.dart`)

R3'teki `historyDateLabel` (`history_screen.dart`) buraya taşınır ve `shortDateLabel(DateTime date, DateTime now)` adını alır: "4 Ekim"; yıl `now`'unkinden farklıysa "30 Aralık 2025". Ay adları mevcut `home.month_N` anahtarları. Geçmiş ve geçmiş detayı ekranları yeni fonksiyonu kullanır; `historyDateLabel` kaldırılır.

### 3.3 `ProgressHero` (`lib/features/progress/presentation/widgets/progress_hero.dart`)

- Girdi: `String label`, `String value`, `String unit`, `String? change` (hazır metin, ör. "−1,6 kg · 3 ay"), `bool highlight`.
- Görünüm: üstte etiket (`labelMedium`, `onSurfaceVariant`, `upperCaseFor`, harf aralığı 1); altında değer (Montserrat 900, `displaySmall` boyutu) + boşluk + birim (`titleMedium`, `onSurfaceVariant`); en altta değişim (`bodySmall`, kalın 600; `highlight` ise `primary`, değilse `onSurfaceVariant`). `change == null` ise satır çizilmez.
- Anahtarlar: değer metni `valueKey`, değişim metni `changeKey` (çağıran verir).

### 3.4 Değişim metni

Çeviri `progress.change_in_range`: `"{delta} · {range}"`. `delta` = `formatDelta(change)` + " " + birim (ör. "−1,6 kg"); `range` = mevcut `progress.range.*` etiketi ("3 ay", "Tümü").

### 3.5 `ChartCard` (`lib/features/progress/presentation/widgets/chart_card.dart`)

- Girdi: `ChartRange range`, `ValueChanged<ChartRange> onRangeChanged`, `Widget chart`.
- Görünüm: `Card`, iç boşluk 12. Başlık satırı: solda "TREND" (`progress.trend`, `labelSmall`, gri, büyük harf), sağda 4 küçük `AccentChip` (1A/3A/1Y/Tümü). Altında `chart`.
- Çip anahtarları `range_${range.name}` (bugünkü `RangeSelector` testleri aynen çalışır). Çip etiketleri kısaltılmış yeni anahtarlar: `progress.range_short.month` "1A" / "1M", `three_months` "3A" / "3M", `year` "1Y" / "1Y", `all` "Tümü" / "All".
- `range_selector.dart` silinir.

## 4. Kilo (`WeightScreen`)

Yukarıdan aşağı (`ListView`, padding 16 / alt 88):

1. `ProgressHero`: etiket `progress.weight.current` ("Güncel"), değer = son kaydın `formatOneDecimal(weightKg)`, birim "kg". Değişim = `changeInRange(pointsInRange(...))`; `highlight` = değişim ≠ null ve `weightChangeIsGood(değişim, profile.goal)` (`home_stat_grid.dart`'tan `progress/domain`'e taşınmaz; aynı dosyadan import edilir). Profil yüklenmediyse `highlight = false`. Anahtarlar: `weight_current`, `weight_change`.
2. `ChartCard` + `ProgressLineChart` (`weight_chart`).
3. `SectionHeader('progress.records'.tr())` ("Kayıtlar").
4. Tek `Card`, içinde satırlar (yeniden eskiye), aralarında 1 px `Divider`:
   - Sol: "78,4 kg" (`bodyLarge`, 600).
   - Fark: bir önceki (daha eski) kayda göre `formatDelta`, `bodySmall`; rengi aynı hedef kuralı (iyi → `primary`, değil → `onSurfaceVariant`). En eski kayıtta yok. Anahtar `weight_delta_${formatDbDate(date)}`.
   - Sağda gri `shortDateLabel`, ardından gri çöp kutusu `IconButton` (anahtar `weight_delete_*`, son kayıtta pasif + mevcut ipucu).
   - Satır `InkWell` (anahtar `weight_log_*`) → `showWeightLogDialog(existing:)`.
5. FAB, boş durum, yükleniyor, hata: değişmez.

## 5. Güç (`StrengthScreen`)

1. Hareket seçici: `DropdownButton` (`strength_exercise_picker`) `surfaceContainer` zeminli, radius 12, yatay iç boşluk 12 olan bir kutuda; `underline` yok. Üstteki "Hareket" etiketi kalkar.
2. `ProgressHero`: etiket `progress.strength.estimated_1rm` ("Tahmini 1RM"), değer = seçili serinin son noktasının `estimateKg`'si (aralıktan bağımsız), birim "kg". Değişim aralıktaki noktalardan; `highlight` = değişim > 0. Anahtarlar: `strength_current`, `strength_change`.
3. `ChartCard` + `ProgressLineChart` (`strength_chart`, ipucu aynen).
4. Altta gri not (`progress.strength.estimated_note`), `bodySmall`, `onSurfaceVariant`.

## 6. Ölçüler (`MeasurementsScreen`)

1. Bölge çipleri: `ChoiceChip` → `AccentChip`, anahtar `site_chip_*`; yalnız verisi olan bölgeler (bugünkü gibi).
2. `ProgressHero`: etiket = `progress.sites.<bölge>`, değer = seçili bölgenin son ölçümü `formatOneDecimal`, birim "cm". Değişim aralıktaki noktalardan, `highlight` her zaman `false`. Anahtarlar: `measurement_current`, `measurement_change`.
3. `ChartCard` + `ProgressLineChart` (`measurement_chart`).
4. `SectionHeader('progress.records'.tr())` + tek `Card`: satır başlığı `shortDateLabel` (`bodyLarge`, 600), altında gri özet (mevcut `_summary`), sağda gri çöp kutusu (`measurement_delete_*`). Satır `InkWell` (`measurement_row_*`) → `showMeasurementForm(existing:)`.
5. FAB, boş durum, yükleniyor, hata: değişmez.

## 7. Çeviriler (tr / en)

Eklenir: `progress.trend` ("Trend"/"Trend"), `progress.records` ("Kayıtlar"/"Records"), `progress.change_in_range` ("{delta} · {range}"), `progress.range_short.*`, `progress.weight.current` ("Güncel"/"Current"), `progress.strength.estimated_1rm` ("Tahmini 1RM"/"Estimated 1RM"). Kullanılmaz hale gelen `progress.strength.exercise` silinir (başka kullanımı yoksa).

## 8. Test

- Birim: `changeInRange` (0, 1, çok nokta); `shortDateLabel` (aynı yıl / farklı yıl).
- Widget: `ProgressHero` (`highlight` → `primary`, değil → `onSurfaceVariant`; `change == null` → satır yok).
- Ekran testleri (mevcut dosyalar genişler): kilo — güncel değer, değişim metni, kilo verme hedefinde düşüşün `primary` olması, satır farkı; güç — güncel tahmin ve artış rengi; ölçü — güncel değer, değişim gri. Eski tarih metnini arayan beklentiler yeni biçime güncellenir.
- Geçmiş testleri `shortDateLabel` taşınmasından sonra değişmeden geçmeli.
- Doğrulama: görev içinde yalnız ilgili testler; sonunda kullanıcının terminalinde `flutter test --no-pub -j 1`, `flutter analyze` temiz, web release derlemesi ve elle kontrol listesi.

## 9. Kapsam dışı

Diyalogların yeniden tasarımı, ölçü değişimi için bölge/hedef bazlı renk kuralı, güç ekranına kayıt listesi, ana sayfa kutularında değişiklik. Antrenör ve giriş/kayıt/onboarding R4b'de.
