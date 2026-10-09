# K3 — Kas Haritası: Isı Haritası ve Programdan Haritaya — Tasarım Spec'i

> Durum: Bölümler kullanıcıyla tek tek onaylandı (2026-10-09). Sonraki adım: kullanıcı spec'i gözden geçirir → writing-plans ile K3 implementasyon planı. Dal: `f5p-kas-haritasi-k3`.

## 1. Bağlam

K1 (master `9cfb6a1`) kas haritasını, K2 (master `6636df3`) kadın figürünü ve Stitch yerleşimini getirdi. K2 spec §9'da K3'e bırakılan iki madde bu spec'in konusu:

1. **Isı haritası:** Son dönemde yapılan setlerin kaslara dağılımı, haritada renk tonlarıyla.
2. **Programdan haritaya:** Program detayında programın çalıştırdığı kasları gösteren küçük harita; dokununca kas haritası ekranı program modunda açılır.

Mevcut kod:
- Domain: `lib/features/workout/domain/muscle_map.dart` (`BodyFigure`, `BodyView`, `BodyFit`, `musclePaths`, `muscleAt`), `exercise_filter.dart` (`exercisesForMuscle`).
- Widget'lar: `presentation/widgets/muscle_map.dart` (`MuscleMap`, `FigureToggle`, `MuscleMapControls`, `MuscleMapCard`), `widgets/exercise_icon_badge.dart`.
- Ekranlar: `presentation/muscle_map_screen.dart`, `presentation/program_detail_screen.dart`.
- Sağlayıcılar: `sessionHistoryProvider` (son 100 bitmiş oturum, setleriyle; `SessionRepository._historyLimit = 100`), `exercisesProvider`, `programDetailProvider(id)`, `mapFigureProvider`, `nowProvider`.
- Modeller: `WorkoutSession.finishedAt`, `.sets`; `SessionSet.exerciseId`, `.isCompleted`; `Exercise.primaryMuscles`, `.secondaryMuscles`; `Program.workouts[].exercises[]` (`WorkoutExercise.exerciseId`, `.sets`).
- Rota: `lib/core/router.dart`, `/workout` altında `GoRoute(path: 'muscles')`.
- Harita renkleri (K2 sonu): kas `onSurfaceVariant` %50, süs %25, kontur %60, seçili kas `primary` + parlama.

## 2. Kararlar (kullanıcıyla onaylı)

1. **Ölçü: set sayısı.** Tamamlanmış her set, hareketin birincil kaslarına 1, ikincil kaslarına 0,5 ekler. Hacim (kg × tekrar) kullanılmaz; kilosuz hareketler de sayılsın diye.
2. **Dönem: seçilebilir 7 / 30 gün.** Varsayılan 7 gün.
3. **Yerleşim: ekranda mod geçişi.** Kas haritası ekranında KEŞFET / ISI. KEŞFET bugünkü davranıştır.
4. **Program mini haritası: planlı set ısısı + ekranı aç.** Programdaki tüm günlerin planlı setleri aynı ağırlıklarla toplanır. Kartın tamamına dokununca kas haritası ekranı program modunda açılır.
5. **Veri kaynağı: yaklaşım A.** Isı, mevcut `sessionHistoryProvider` listesinden süzülür. Yeni sorgu, migration ya da deploy yok. Sınır: 30 günde 100'den fazla bitmiş oturum olursa en eskileri sayılmaz; kabul edildi.
6. **Mutlak eşikler.** Renk kademesi haftalık set yüküne göre belirlenir, göreli ölçek kullanılmaz (tek hareket yapıldığında her şey "en yüksek" görünmesin diye).
7. **Stitch taslakları:** Stitch projeleri 11672867956091631031 (ısı modu) ve 15210191598326549152 (mini harita) üretildi. API yalnızca figür küçük resimlerini veriyor (`.superpowers/brainstorm/k3-stitch/`, git'e girmez). Yerleşimin bağlayıcı tarifi bu spec'in §5 bölümüdür. Figür her zaman body-highlighter verisinden çizilir.

## 3. Domain (`lib/features/workout/domain/muscle_heat.dart`, yeni)

```dart
enum HeatTier { none, low, medium, optimal, high }

/// Haftalık set yükü → kademe. Sınırlar: 0 → none, (0, 4) → low, [4, 10) → medium, [10, 20) → optimal, ≥ 20 → high.
HeatTier heatTierFor(double weeklySets);

/// Bir hareketin bir kasa katkısı: birincilse 1, ikincilse 0,5, değilse 0.
double muscleWeight(Exercise exercise, String muscle);

/// Kas başına set yükü.
typedef MuscleLoad = Map<String, double>;

/// Bitmiş oturumlardan, finishedAt >= since olanların tamamlanmış setleri.
/// Hareketi exercisesById'de bulunmayan setler atlanır.
MuscleLoad historyMuscleLoad(List<WorkoutSession> sessions, Map<String, Exercise> exercisesById, DateTime since);

/// Programdaki tüm günlerin WorkoutExercise.sets toplamı, aynı ağırlıklarla.
MuscleLoad programMuscleLoad(Program program, Map<String, Exercise> exercisesById);

/// Yükü haftalığa çevirip kademeye eşler. days == null → yük olduğu gibi (program bir döngü).
Map<String, HeatTier> heatTiers(MuscleLoad load, {int? days});
```

- Haftalık çevirme: `load × 7 / days`. 7 günde çarpan 1, 30 günde 7/30.
- `heatTiers` yalnızca `none` olmayan kasları döndürür.
- Seçili kas listesi için hareket başına döküm:

```dart
/// Bir kas için hareket başına set yükü, çoktan aza; eşitlikte ada göre.
typedef ExerciseLoad = ({Exercise exercise, double sets, bool primary});

List<ExerciseLoad> historyLoadsForMuscle(List<WorkoutSession> sessions, Map<String, Exercise> exercisesById, DateTime since, String muscle);
List<ExerciseLoad> programLoadsForMuscle(Program program, Map<String, Exercise> exercisesById, String muscle);
```

  `sets` ham set sayısıdır (ağırlıksız); `primary` kasın birincil olup olmadığını söyler. Kas başlığındaki toplam ise ağırlıklı yüktür (`MuscleLoad[muscle]`).

## 4. Sağlayıcılar (`lib/features/workout/application/muscle_heat_providers.dart`, yeni)

- `exercisesByIdProvider`: `exercisesProvider`'dan `Map<String, Exercise>`.
- `historyHeatProvider = FutureProvider.autoDispose.family<HistoryHeat, int>(days)`: `sessionHistoryProvider` + `exercisesByIdProvider` + `nowProvider`. `since = now − days gün`. Döner: `({List<WorkoutSession> sessions, Map<String, Exercise> exercisesById, MuscleLoad load, DateTime since})`.
- `programHeatProvider = FutureProvider.autoDispose.family<ProgramHeat, String>(programId)`: `programDetailProvider` + `exercisesByIdProvider`. Döner: `({Program program, Map<String, Exercise> exercisesById, MuscleLoad load})`.
- Mod ve dönem seçimi ekranın `State`'inde tutulur, sağlayıcıya girmez.

## 5. Arayüz

### 5.1 `MuscleMap` widget'ı

- Yeni isteğe bağlı parametre `heat: Map<String, HeatTier>`. Verilirse kas dolgusu kademeye göre: `none` → bugünkü gri kas rengi; `low / medium / optimal / high` → `primary` sırasıyla %25 / %45 / %70 / %100 opaklık. Süs parçaları ve kontur değişmez. Seçili kas yine tam `primary` + parlama; ısı modunda parlama seçimi ayırt etmeye yeter.
- `onSelected` isteğe bağlı olur. `null` ise `GestureDetector` eklenmez, dokunuş üst widget'a geçer.
- `HeatLegend` (yeni): dört küçük kare (low → high tonları) ve iki uçta "Az" / "Çok" etiketi. Anahtar `muscle_heat_legend`.

### 5.2 Kas haritası ekranı (`MuscleMapScreen({String? programId})`)

Rota: `/workout/muscles` aynı kalır; `?program=<id>` sorgu parametresi `programId`'ye geçer.

**Normal açılış (`programId == null`):**
- Kontrol satırının üstünde tam genişlikte **KEŞFET / ISI** geçişi (`SegmentedButton`): `muscle_map_mode_explore`, `muscle_map_mode_heat`. Varsayılan KEŞFET.
- **KEŞFET:** bugünkü ekran, değişiklik yok.
- **ISI:**
  - Harita kartının altında satır: solda **7 GÜN / 30 GÜN** geçişi (`muscle_heat_period_7`, `muscle_heat_period_30`), sağda `HeatLegend`.
  - Harita `heat: heatTiers(load, days: days)` ile çizilir.
  - Kas seçili değilse ipucu: yük varsa "Bir kasa dokun", hiç yük yoksa "Son {n} günde biten antrenman yok" (`muscle_heat_empty`).
  - Kas seçiliyse başlık: kas adı + "{sets} set · son {n} gün" (`muscle_heat_summary`; `sets` bir ondalıkla, tam sayıysa ondalıksız). "İkincil dahil" çipi gösterilmez.
  - Liste: `historyLoadsForMuscle`; satır başına `ExerciseIconBadge`, hareket adı, alt satırda "Birincil" / "İkincil", sağda lime hap içinde "{n} set" (`muscle_heat_row_<exerciseId>`). Dokununca detay sayfası (`selectable: false`), KEŞFET'teki gibi.
  - Seçili kasın dönemde hiç seti yoksa liste yerine "Bu kası son {n} günde çalıştırmadın" (`muscle_heat_muscle_empty`).
- Mod değişince seçili kas korunur.

**Program modu (`programId != null`):**
- AppBar başlığı aynı; altında soluk renkle program adı (`muscle_map_program_name`).
- KEŞFET / ISI geçişi, dönem geçişi ve "İkincil dahil" çipi gösterilmez; lejant gösterilir.
- Harita `heat: heatTiers(programLoad)` ile çizilir.
- Kas seçiliyse başlık: kas adı + "{sets} set · program" ; liste `programLoadsForMuscle`, satır biçimi ısı moduyla aynı (`muscle_heat_row_<exerciseId>`).
- Seçili kası çalıştıran program hareketi yoksa "Bu program bu kası çalıştırmıyor" (`muscle_heat_program_muscle_empty`).

**Yükleme ve hata:** Isı ya da program verisi yüklenirken harita ısısız çizilir ve dokunulabilir kalır; liste alanında `CircularProgressIndicator`. Hata olursa liste alanında "tekrar dene" düğmesi (`muscle_heat_retry`), ilgili sağlayıcıyı yeniler.

### 5.3 Program detayı mini kartı

- Konum: butonların (`Wrap`) altında, gün kartlarından önce, 16 px boşlukla.
- `MiniMuscleMapCard` (yeni, `widgets/muscle_map.dart`), anahtar `program_muscle_map_card`:
  - Başlık satırı: "ÇALIŞAN KASLAR" (`heading` stili) ve sağda `Icons.chevron_right`.
  - Gövde: yaklaşık 180 px yükseklikte ön ve arka `MuscleMap` yan yana (`onSelected: null`), figür `mapFigureProvider`'dan, `heat: heatTiers(programLoad)`.
  - Altta `HeatLegend`.
  - Kartın tamamı `InkWell`; dokununca `context.push('/workout/muscles?program=${program.id}')`.
- Programda kas eşlemesi olan hiç hareket yoksa (yük boşsa) ya da `exercisesProvider` henüz yüklenmediyse kart gösterilmez.

### 5.4 Çeviriler (`tr.json`, `en.json`)

`workout.muscle_map.` altında: `mode_explore` (KEŞFET / EXPLORE), `mode_heat` (ISI / HEAT), `period_days` ({n} GÜN / {n} DAYS), `legend_low` (Az / Low), `legend_high` (Çok / High), `heat_summary` ({sets} set · son {n} gün / {sets} sets · last {n} days), `heat_summary_program` ({sets} set · program / {sets} sets · program), `heat_empty`, `heat_muscle_empty`, `heat_program_muscle_empty`, `heat_row_sets` ({n} set / {n} sets), `primary` (Birincil / Primary), `secondary` (İkincil / Secondary), `program_card_title` (ÇALIŞAN KASLAR / MUSCLES WORKED). Plan, mevcut anahtarlarla çakışanları yeniden kullanır.

## 6. Hata ve kenar durumları

- Hareketi silinmiş ya da listede olmayan setler sayılmaz.
- Kas eşlemesi olmayan hareketler (boş `primaryMuscles`) ısıya katkı vermez.
- Kas adları `muscleGroups`'taki 17 değerden biri; haritada şekli olmayan kas (ör. `neck` yoksa) yalnızca listede etkilidir.
- Geçmiş henüz yüklenmemişse ya da kullanıcı giriş yapmamışsa yük boştur.
- Programda `sets == 0` olan satır katkı vermez.

## 7. Testler (TDD)

- **Domain** (`test/features/workout/domain/muscle_heat_test.dart`, yeni):
  - Birincil 1, ikincil 0,5.
  - Tamamlanmamış setler, `finishedAt < since` oturumlar ve bilinmeyen hareketler sayılmaz.
  - `heatTiers(days: 30)` yükü 7/30 ile çarpar.
  - `heatTierFor` sınırları: 0, 3.9, 4, 9.9, 10, 19.9, 20.
  - `programMuscleLoad` günleri toplar.
  - `historyLoadsForMuscle` / `programLoadsForMuscle` sıralaması ve `primary` bayrağı.
- **Sağlayıcı** (`test/features/workout/application/muscle_heat_providers_test.dart`, yeni): `historyHeatProvider(7)` `nowProvider`'a göre süzüyor; `programHeatProvider` yükü hesaplıyor.
- **Widget** (`muscle_map_widget_test.dart`): `onSelected: null` iken üstteki `InkWell` dokunuşu alıyor; `HeatLegend` çiziliyor; `heat` verilince harita çiziliyor (hata yok).
- **Ekran** (`muscle_map_screen_test.dart`):
  - Varsayılan KEŞFET; ISI'ya geçince dönem geçişi ve lejant görünüyor, "İkincil dahil" çipi gizleniyor.
  - ISI'da kasa dokununca özet satırı ve set haplı satırlar; 30 GÜN'e geçince özet güncelleniyor.
  - Boş geçmişte `muscle_heat_empty`.
  - Program modunda program adı görünüyor, mod geçişi yok, liste program hareketlerinden.
- **Program detayı** (`program_detail_screen_test.dart`): kart görünüyor ve dokununca `/workout/muscles?program=<id>`'ye gidiyor; kas eşlemesi yoksa kart yok.
- **Rota:** `?program=` parametresi ekrana geçiyor (ekran ya da router testi).

## 8. Dal, sıra, manuel kontrol

- Dal: `f5p-kas-haritasi-k3`. Sıra: domain → sağlayıcılar → widget → ekran → program detayı + rota → doğrulama.
- Migration / deploy yok.
- Tam test paketi ve web release derlemesi kullanıcının terminalinde (`flutter test --no-pub -j 1`, `flutter build web --release --no-pub`).

Manuel kontrol listesi:
1. KEŞFET modu K2'deki gibi çalışıyor.
2. ISI modunda son 7 günde çalışılan kaslar tonlanıyor; 30 GÜN'e geçince tonlar mantıklı biçimde değişiyor.
3. Isı modunda kasa dokununca set özeti ve yapılan hareketler set sayılarıyla listeleniyor.
4. Hiç antrenman olmayan dönemde boş mesajı çıkıyor.
5. Program detayında "ÇALIŞAN KASLAR" kartı görünüyor; ön/arka figür programın kaslarını tonluyor.
6. Karta dokununca harita program modunda açılıyor; kasa dokununca program hareketleri planlı set sayılarıyla listeleniyor.
7. ♂/♀ seçimi mini kartta ve program modunda da geçerli.
8. Yaklaşık 360 px genişlikte taşma yok.

## 9. Kapsam dışı

- Toparlanma görünümü (kasın en son ne zaman çalıştığı).
- Hacim (kg × tekrar) ölçüsü.
- Antrenman günü başına mini harita.
- Dönem ve mod seçiminin kalıcı saklanması.
- Haftalık set hedefi önerileri ya da uyarılar.
