# K1 — Kas Haritası: Tasarım Spec'i

> Durum: Bölümler kullanıcıyla tek tek onaylandı (2026-10-08). Sonraki adım: kullanıcı spec'i gözden geçirir → writing-plans ile K1 implementasyon planı. K2 (ek özellikler) K1 bitince ayrı dal/spec/plan ile.

## 1. Bağlam

F5+ alt projesi "kas haritası": vücut figüründe bir kasa dokununca o kası çalıştıran hareketler listelenir.

Mevcut durum:
- `exercises` tablosunda her hareketin `primary_muscles` / `secondary_muscles` alanları var (free-exercise-db, ~870 hareket); 17 kas grubu `lib/features/workout/domain/exercise_taxonomy.dart` içinde (`muscleGroups`), çevirileri `workout.muscle.*`.
- `filterExercises(all, muscle:)` birincil kasa göre süzer; `ExercisePickerScreen` kas çipleriyle (`_muscle`) filtreler.
- `showExerciseDetailSheet(context, exercise, selectable: false)` "seç" butonsuz detay gösterir.
- Bu makinede `pub get` takılıyor → yeni paket eklenmez (ikonlarda olduğu gibi Python üretici betik kullanılır).

## 2. Kararlar (kullanıcıyla onaylı)

1. **2D ön/arka harita**, `CustomPainter`; 3D yok.
2. **Gerçekçi figür:** siluet ve kas yolları MIT lisanslı `react-native-body-highlighter` (© 2022 ELABBASSI Hicham) erkek verisinden. Maket: `.superpowers/brainstorm/muscle-map/layout.html`.
3. **Yerleşim A:** ÖN/ARKA anahtarı + tek büyük figür + altta liste.
4. **Yerleşim yeri:** (a) Antrenman sekmesinde ayrı "Kas haritası" ekranı (yalnızca göz atma), (b) egzersiz seçicide "Haritadan seç" → kas filtresi.
5. **Yaklaşım 1:** Python betiği yolları mutlak `M/L/C/Q/Z` sayı listelerine çevirip Dart dosyası üretir; dokunma `Path.contains` ile.
6. **İki faz:** K1 bu spec; K2 = kadın figürü, ısı haritası, programdan haritaya bağlantı, Stitch ile yerleşim iyileştirmesi (§10).

## 3. Veri

### 3.1 Kaynak dosyalar

`tool/body_highlighter/` altına bir kez kopyalanır (değiştirilmez): `bodyFront.ts`, `bodyBack.ts`, `SvgMaleWrapper.tsx` (iki `<Path d=…>`: ön ve arka siluet), `LICENSE` (MIT). Kaynak: `https://github.com/HichamELBSI/react-native-body-highlighter` (`main`, `assets/` ve `components/`).

### 3.2 Üretici `tool/generate_muscle_paths.py`

- Yalnız Python standart kütüphanesi. `python tool/generate_muscle_paths.py` → `lib/features/workout/domain/muscle_map_data.dart` yazar.
- `.ts` dosyalarından her `{ slug, path: { left|right|common: [ "M…" ] } }` parçasını okur.
- SVG yol ayrıştırıcı: `M L H V C S Q T A Z` (büyük/küçük), sıkıştırılmış sayılar (`1.5.5`, `-2-3`), yay bayrakları tek karakter. Çıktı yalnız mutlak `M`, `L`, `C`, `Q`, `Z`: `H/V` → `L`; `S` → `C` (önceki kontrol noktası yansıtılır); `T` → `Q`; `A` → bir ya da daha fazla `C` (standart endpoint→center dönüşümü, ≤90° dilimler).
- Arka görünüm x kayması: kaynakta arka 724–1448 aralığında; üretimde 724 çıkarılır → iki görünüm de `0..724 × 0..1448`.
- Öz kontrol: her parçanın üretilen sınır kutusu, kaynak noktalarından hesaplanan kutudan en çok 2 birim sapabilir; aksi halde betik hata verir.
- Kas eşlemesi (slug → taksonomi adı):

| Ön slug | Kas | Arka slug | Kas |
|---|---|---|---|
| chest | chest | deltoids | shoulders |
| deltoids | shoulders | trapezius | traps |
| biceps | biceps | upper-back (yükseklik > 120) | lats |
| triceps | triceps | upper-back (diğer) | middle back |
| forearm | forearms | triceps | triceps |
| abs, obliques | abdominals | lower-back | lower back |
| quadriceps | quadriceps | forearm | forearms |
| adductors | adductors | gluteal (yükseklik > 80) | glutes |
| calves, tibialis | calves | gluteal (diğer) | abductors |
| trapezius | traps | adductors | adductors |
| neck | neck | hamstring | hamstrings |
| | | calves | calves |
| | | neck | neck |

  `head, hands, knees, ankles, feet` → süs (`muscle: null`); `hair` atlanır. Bilinmeyen slug → betik hata verir.

### 3.3 Üretilen Dart (`muscle_map_data.dart`)

```dart
// OTOMATİK ÜRETİLDİ — tool/generate_muscle_paths.py. Elle düzenleme.
// Vücut yolları: react-native-body-highlighter, MIT License, Copyright (c) 2022 ELABBASSI Hicham.

enum BodyView { front, back }

/// Komut kodları: 0 = M (x y), 1 = L (x y), 2 = C (x1 y1 x2 y2 x y), 3 = Q (x1 y1 x y), 4 = Z.
class MuscleShape {
  const MuscleShape(this.muscle, this.commands);
  final String? muscle; // muscleGroups'tan biri; süs parçalarında null
  final List<double> commands;
}

const bodyCanvasWidth = 724.0;
const bodyCanvasHeight = 1448.0;
const Map<BodyView, List<double>> bodySilhouettes = {...};
const Map<BodyView, List<MuscleShape>> muscleShapes = {...}; // çizim sırası = kaynak sırası
```

Sayılar bir ondalığa yuvarlanır.

## 4. Alan katmanı — `lib/features/workout/domain/muscle_map.dart`

- `const bodyCrop = Rect.fromLTWH(40, 120, 644, 1250)` (iki görünümde görünür alan).
- `Path buildPath(List<double> commands)`.
- `Map<BodyView, List<(String?, Path)>>` önbelleği: `musclePaths(BodyView view)` ve `silhouettePath(BodyView view)` bir kez kurar.
- `String? muscleAt(BodyView view, Offset canvasPoint)`: şekiller **sondan başa** taranır, `muscle != null` ve `path.contains` olan ilk şeklin kası; yoksa `null`.
- `Set<String> musclesIn(BodyView view)`: o görünümde çizilen kaslar.

`exercise_filter.dart`'a:

```dart
/// [muscle]'ı birincil çalıştıranlar (ada göre); [includeSecondary] ise ardından
/// yalnız ikincil çalıştıranlar (ada göre).
List<Exercise> exercisesForMuscle(List<Exercise> all, String muscle, {bool includeSecondary = false});
```

Ad sıralaması küçük harfe çevrilmiş adla. `filterExercises` değişmez.

## 5. Bileşen — `lib/features/workout/presentation/widgets/muscle_map.dart`

- `MuscleMap({super.key, required BodyView view, String? selected, required ValueChanged<String> onSelected})`.
- `LayoutBuilder` + `GestureDetector(onTapUp)` + `CustomPaint`. `bodyCrop` oran korunarak sığdırılır ve ortalanır; dokunma noktası tuval koordinatına geri çevrilir → `muscleAt` → kas varsa `onSelected`.
- Çizim sırası: siluet → şekiller (kaynak sırası). Renkler temadan:

| Öğe | Renk |
|---|---|
| Siluet dolgu | `colorScheme.surfaceContainerLowest`, kenar `outlineVariant` |
| Süs | `colorScheme.surfaceContainer` |
| Kas | `colorScheme.surfaceContainerHighest` |
| Seçili kas | `colorScheme.primary` + aynı yolun `MaskFilter.blur(BlurStyle.normal, 8)` ile alttan parlaması |
| Kenar çizgileri | `scaffoldBackgroundColor`, 2.5 birim |

- `shouldRepaint`: görünüm, seçim ya da renkler değişince.
- Erişilebilirlik: `Semantics(label: 'workout.muscle_map.title'.tr())`; kas başına semantik düğüm K1'de yok.
- Anahtar: `muscle_map_${view.name}`.

## 6. Ekranlar

### 6.1 `MuscleMapScreen` (`/workout/muscles`)

- Giriş: `ProgramsScreen` AppBar `actions`'a geçmiş ikonundan önce `IconButton` (`programs_muscle_map_button`, `Icons.accessibility_new`, tooltip `workout.muscle_map.title`) → `context.push('/workout/muscles')`. Rota `router.dart`'ta `/workout` altına `GoRoute(path: 'muscles')`.
- Gövde: tek `CustomScrollView`:
  1. `SegmentedButton<BodyView>` (`muscle_map_view_toggle`), etiketler `workout.muscle_map.front` / `back` ("ÖN"/"ARKA"), başlangıç ön.
  2. `MuscleMap`, yükseklik `MediaQuery.sizeOf(context).height * 0.45`.
  3. Seçim yoksa ortalı soluk ipucu `workout.muscle_map.hint` ("Bir kasa dokun", `muscle_map_hint`).
  4. Seçim varsa başlık satırı: kas adı `muscleLabelKey(m).tr()` büyük harf (Montserrat 900, `muscle_map_selected`), `workout.muscle_map.count` ("{n} hareket"), sağda `AccentChip` `workout.muscle_map.include_secondary` (`muscle_map_secondary_chip`).
  5. Liste (`SliverList`): `Card` içinde satırlar `muscle_map_exercise_${id}` — başlık ad, alt yazı `equipmentLabelKey(e).tr()` (ekipman null ise atlanır) · seviye (`workout.level_beginner` / `level_intermediate`; veritabanındaki `expert` → `level_advanced`; null ya da bilinmeyen seviye atlanır) ve kendi hareketinse `workout.custom_exercise_badge`; sağda `›`. Dokununca `showExerciseDetailSheet(context, e, selectable: false)`.
  6. Liste boşsa `workout.muscle_map.empty` ("Bu kas için hareket yok").
- Görünüm değişince seçim korunur (o görünümde yoksa yalnız vurgu görünmez; liste aynı kalır).
- Veri: `exercisesProvider`; yüklenirken `CircularProgressIndicator`, hatada `TextButton` `workout.picker_load_error` → `ref.invalidate(exercisesProvider)` (seçicideki desen).
- Durum (`_view`, `_muscle`, `_includeSecondary`) ekranın `State`'inde; ekran kapanınca sıfırlanır.

### 6.2 Seçicide "Haritadan seç"

- `ExercisePickerScreen` kas çip satırının **başına** `AccentChip` (`muscle_filter_map`, `Icons`'suz, etiket `workout.muscle_map.pick_from_map`, `selected: false`).
- Basınca `showMuscleMapSheet(context, selected: _muscle)` → `Future<String?>`: `showModalBottomSheet(isScrollControlled: true)`, içinde `SegmentedButton` + `MuscleMap` (yükseklik ekranın %60'ı) + soluk ipucu. Kasa dokununca `Navigator.pop(muscle)`.
- Dönen kas null değilse `setState(() => _muscle = muscle)`. Çip satırı kaydırılmaz.
- `showMuscleMapSheet` `lib/features/workout/presentation/widgets/muscle_map_sheet.dart` içinde.

## 7. Çeviriler (tr + en, `workout.muscle_map`)

| Anahtar | tr | en |
|---|---|---|
| title | Kas haritası | Muscle map |
| front | ÖN | FRONT |
| back | ARKA | BACK |
| hint | Bir kasa dokun | Tap a muscle |
| count | {n} hareket | {n} exercises |
| include_secondary | İkincil dahil | Include secondary |
| empty | Bu kas için hareket yok | No exercises for this muscle |
| pick_from_map | Haritadan seç | Pick on map |

## 8. Lisans

- `LICENSES/body-highlighter.txt` (MIT metni, telif satırıyla) — pubspec `assets`'a eklenir.
- `main.dart`'ta `LicenseRegistry.addLicense` ile `LicenseEntryWithLineBreaks(['react-native-body-highlighter'], metin)` kaydedilir (`rootBundle.loadString`). Flutter'ın lisans sayfasında görünür. Lisans sayfasına giriş ayarlar ekranında yoksa K1 bir giriş eklemez; doğrulama `showLicensePage` ile değil, `LicenseRegistry.licenses` testinde yapılır.

## 9. Test, dal ve doğrulama

Dal `f5p-kas-haritasi`. Göç/deploy/yeni paket yok.

Testler (TDD):
- `muscle_map_data_test.dart`: 17 kasın hepsi (iki görünüm birleşik) en az bir şekille var; her `commands` 0 ile başlar ve geçerli kodlarla uzunluk tutarlı; siluetler boş değil.
- `muscle_map_test.dart` (alan): `buildPath` sınırları tuval içinde; `muscleAt` — her kasın ilk şeklinin sınır kutusu merkezine yakın, o şeklin `contains` ettiği bir nokta (test içinde `path.contains` ile ızgarada aranır) o kası döndürür; (0,0) → null; süs parçasındaki nokta → null.
- `exercise_filter_test.dart`: `exercisesForMuscle` birincil, ikincil ve sıralama.
- `muscle_map_widget_test.dart`: göğüs şeklinin içindeki bir noktaya dokununca `onSelected('chest')`; boşluğa dokununca çağrı yok.
- `muscle_map_screen_test.dart`: ipucu; kas seçimi → başlık + sayı + liste; ikincil çipi listeyi genişletir; satır → detay sayfası "seç" butonsuz; ARKA'ya geçince seçim ve liste korunur; hata → yeniden dene.
- `exercise_picker_screen_test.dart`: "Haritadan seç" → alt sayfa; kas seçimi → liste o kasa süzülür.
- `programs_screen_test.dart`: harita ikonu `/workout/muscles`'a gider.
- Lisans: `LicenseRegistry.licenses` içinde paket adı.

Kullanıcı terminalinde: `flutter test --no-pub -j 1`, web release build, manuel liste (~8): figür görünümü (ön/arka), ÖN/ARKA geçişi, göğüs/kanat/kalça dışı listeleri doğru, ikincil anahtarı, detay sayfası seçsiz, seçicide haritadan seçim, lisans kaydı, dar ekranda taşma yok. Sonra PLAN.md satırı + finishing-branch.

## 10. K2 çerçevesi (K1 sonrası, ayrıntılar K2 başında konuşulur)

1. **Kadın figürü:** aynı kaynaktaki `bodyFemaleFront.ts` / `bodyFemaleBack.ts` / `SvgFemaleWrapper.tsx`; profil cinsiyeti kadınsa kadın figürü (belirtilmemişte varsayılan konuşulacak). Üretici betik iki figür üretecek şekilde genişler.
2. **Isı haritası:** son N günün bitmiş oturumlarındaki setlerden kas başına yoğunluk (birincil tam, ikincil kısmi ağırlık); harita ekranında mod olarak renk tonlaması.
3. **Programdan haritaya bağlantı:** program detayında programın çalıştırdığı kasları gösteren küçük harita; dokununca kas haritası ekranı o kasla açılır.
4. **Stitch ile yerleşim iyileştirmesi:** Google Stitch MCP ile kas haritası ve ilgili ekranların yerleşim taslakları; tema (neon lime, koyu, Montserrat/Inter) uyarlanır. Figür verisi değişmez.

## 11. Kapsam dışı (K1)

§10'daki dört madde; kas başına semantik düğümler; harita üzerinde çoklu kas seçimi.
