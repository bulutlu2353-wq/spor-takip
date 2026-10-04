# F5+ R3 — Antrenman Ekranları: Tasarım Spec'i

> Durum: Bölümler kullanıcıyla tek tek onaylandı (2026-10-04/05). Sonraki adım: kullanıcı spec'i gözden geçirir → writing-plans ile R3 implementasyon planı.

## 1. Bağlam

F5+ görsel yenilemenin üçüncü aşaması. Çerçeve, tasarım sistemi ve kurallar R1 spec'inde: `docs/superpowers/specs/2026-10-03-f5plus-r1-tasarim-temeli-design.md` (§3–§4). R3 bu temeli (`AppColors`, `AppTheme.dark()`, `SectionHeader` (R2'de `trailing` eklendi), `upperCaseFor`) kullanır, yeni tema değeri eklemez.

Kapsam (8 ekran): `SessionScreen` (+ `SetRow`, `RestTimerBar`), `SessionSummaryScreen`, `ProgramsScreen` (+ `ProgramCard`), `ProgramDetailScreen`, `ProgramEditorScreen`, `ExercisePickerScreen`, `HistoryScreen`, `HistoryDetailScreen`. Haftalık "bu hafta / geçen hafta" tablosu (`WeeklySummaryCard`) geçmiş ekranının başına taşınır (R1 spec §3'teki istisna).

Maketler (git'e girmez): `.superpowers/brainstorm/r3/session-layout.html`, `programs-layout.html`, `summary-history.html`.

## 2. Kararlar (kullanıcıyla onaylı)

| Konu | Karar |
|------|-------|
| Antrenman oturumu | **B · Özet şeridi + katlanan kartlar**: süre/set/hacim kutuları + ilerleme çubuğu; sütun başlıklı set tablosu; tüm setleri biten hareket tek satıra katlanır |
| Programlar | **A · Liste, yeni stil**: bugünkü sıra korunur; aktif program neon çerçeve + "AKTİF" etiketi |
| Özet / geçmiş / geçmiş detayı | Tek öneri kabul edildi (maket `summary-history.html`) |
| Program detayı, düzenleyici, hareket seçici | Maket yok; aynı kart/çip/buton diliyle yeniden stil |
| Davranış | Değişmez. İstisnalar: haftalık tablonun geçmişe taşınması, geçmiş satırında program adının çıkması, oturum kartının katlanması (yalnız görünüm durumu) |

## 3. Ortak bileşen: `StatBox`

Yeni, `lib/shared/widgets/stat_box.dart`. Dokunulamayan küçük rakam kutusu (mevcut `StatTile` `onTap` zorunlu tuttuğu için ayrı).

- Girdi: `String label`, `String value`, isteğe bağlı `Key? valueKey` (mevcut test anahtarları rakam metnine bağlanabilsin diye).
- Görünüm: `surfaceContainer` zemin, radius 12, iç boşluk 8; ortalı; üstte değer (Montserrat 900, `titleLarge` boyutu), altta etiket (`labelSmall`, `onSurfaceVariant`, `upperCaseFor` ile büyük harf).
- Kullanım: oturum özet şeridi, oturum özeti ekranı, geçmiş detayı. Üçlü satır için `Row` + `Expanded` + 8 px boşluk.

## 4. Antrenman Oturumu (`SessionScreen`)

**AppBar:** başlık iki satır: üstte gün adı (`workoutName`, `labelMedium`, gri, büyük harf), altta program adı (`programName`, `titleMedium` Montserrat). Sağda "Bitir" `FilledButton` (`session_finish_button`) ve ⋮ menüsü (`session_menu`, iptal). Süre AppBar'dan çıkar.

**Özet şeridi** (liste başında):
- Üç `StatBox`: süre (`formatDuration(sessionDuration(...))`, değer anahtarı `session_elapsed` korunur), set (`{tamamlanan}/{toplam}`, anahtar `session_sets_progress`; toplam = `session.sets.length`), hacim (`trimNumber(totalVolumeKg(session))`, anahtar `session_volume`).
- Altında ilerleme çubuğu (`session_progress_bar`): yükseklik 5, radius 3, zemin `outlineVariant`, dolu kısım `primary`, oran tamamlanan/toplam (toplam 0 ise 0).
- Süre her saniye güncellenir (mevcut `clockProvider`).

**Hareket kartı** (`session_exercise_$position`, `surfaceContainer`, radius 16):
- Başlık satırı: hareket adı (Montserrat 800), sağda gri `{biten}/{toplam}` ve ⋮ (`session_exercise_menu_$position`, "hareketi çıkar").
- Sütun başlıkları: `SET · HEDEF · KG · TEK.` (`labelSmall`, gri). Çeviri anahtarları yeni (§9).
- `SetRow` mantığı aynı (alanlar, odak senkronu, kilitleme, deload notu). Görünüm: satırlar arasında `outlineVariant` çizgi; biten satırda hedef ve kutular `onSurfaceVariant`, ✓ ikonu `primary` dolu (`Icons.check_circle`); `primaryContainer` arka planı kalkar. Bitmemiş ✓ `outlineVariant` renkli boş daire.

**Katlanma:**
- Bir hareketin tüm setleri `isCompleted` ise kart katlı gösterilir: tek satır, ad + gri "{n} set" + `primary` zeminli "✓ Bitti" etiketi (`onPrimary` metin) + ⋮ menüsü. Anahtar `session_exercise_collapsed_$position`.
- Katlı satıra dokununca açılır; açık bitmiş kartın başlığına dokununca tekrar katlanır. Açık olanlar `SessionScreen` içinde `Set<int>` (exercisePosition) olarak tutulur — ekran `ConsumerStatefulWidget` olur. Kaydedilmez; ekrandan çıkınca sıfırlanır.
- Açık kartta bir set geri alınırsa hareket bitmiş sayılmaz → normal açık kart.

**"+ Hareket ekle"** (`session_add_exercise`): `primary` renkli `TextButton.icon`, değişmez.

**`RestTimerBar`:** zemin `primary`, metin/ikon `onPrimary`; kalan süre Montserrat 900 (`headlineSmall`); "Dinlenme" etiketi; "+30 sn" ve atla düğmeleri `onPrimary` renkli metin/ikon (neon zemin üzerinde koyu). Anahtarlar ve alarm davranışı aynı.

**Yükleniyor / hata:** aynı (ortalı gösterge; hata metni + yeniden dene).

## 5. Oturum Özeti (`SessionSummaryScreen`)

- Gövde başında: `workout.session.summary_done` ("ANTRENMAN TAMAMLANDI", gri, büyük harf), altında büyük `workoutName` + `primary` "✓" (Montserrat 900, `headlineMedium`), altında gri `programName`.
- Üç `StatBox`: süre (`summary_duration`), set (`summary_sets`), hacim (`summary_volume`; değer `trimNumber(...)`, etiket "kg hacim"). Anahtarlar `StatBox`'ın kendisine verilir (testler `find.descendant` ile değer metnini bulur).
- 1RM önerileri varsa `SectionHeader(workout.session.summary_one_rep_max)` ve her öneri bir kart (`summary_1rm_$exerciseId`): solda ad, altında gri "{eski} → {yeni} kg" (yeni değer `primary`), sağda `Checkbox`. Kartın tamamı dokunulabilir; reddetme mantığı aynı.
- Kaydet (`summary_save_button`) gövdenin altında sabit: `Scaffold.bottomNavigationBar` içinde `SafeArea` + 16 px boşluklu tam genişlik `FilledButton`. Kaydederken pasif; hata snackbar'ı aynı.

## 6. Programlar, Detay, Düzenleyici, Seçici

**`ProgramsScreen` (A):**
- Bölüm başlıkları (`workout.active_program`, `workout.my_programs`, `workout.built_in_programs`) `SectionHeader` olur.
- Filtre çipleri aynı iki satır (`programs_level_filter_*`, `programs_days_filter_*`); seçili çip temadan neon (gerekirse `ChoiceChip` `selectedColor: primary`, `labelStyle` `onPrimary`). Satırlar arası 6 px.
- FAB (`programs_create_fab`) temadan `primary` zemin.

**`ProgramCard`:** `surfaceContainer` kart, radius 16, gölgesiz; `ListTile` yerine özel düzen: ad (Montserrat 800, `titleSmall`), altında gri ayrıntı satırı (mevcut `details.join(' · ')`), sağda `chevron_right` gri. `isActive` ise 1.5 px `primary` çerçeve ve adın sağında "AKTİF" etiketi (`primary` zemin, `onPrimary` metin, `program_card_active_tag`). Yıldız/ikon kalkar. Anahtar `program_card_${id}` dokunulan öğede kalır.

**`ProgramDetailScreen`:**
- Gövde başında: açıklama (varsa), altında gri ayrıntı satırı (`ProgramCard` ile aynı içerik; ortak yardımcı `programDetails(Program)` `program_card.dart`'tan dışa açılır). Aktifse "AKTİF" etiketi (`program_active_badge` anahtarı bu etikete taşınır).
- Aksiyonlar: aktif değilse "Aktif yap" (`program_activate_button`) tam genişlik `FilledButton`. Altında `Wrap` içinde `OutlinedButton`'lar: Özelleştir, Düzenle, 1RM (anahtarlar aynı). Sil (`program_delete_button`) `TextButton`, `error` renkli.
- Her gün bir kart (`workout_section_$index`): başlıkta gün adı (Montserrat) + gri hafta günü, sağda "Başlat" (`workout_start_$index`, küçük `FilledButton`); altında bloklar mevcut `ExerciseGroupTile` satırları, aralarında `outlineVariant` çizgi.

**`ProgramEditorScreen`:** ad alanı ve mod `SegmentedButton`/çipleri temadan; her gün kartı `surfaceContainer` radius 16, başlık satırında ad + ikonlar (aynı anahtarlar), içinde gün seçici ve blok satırları; "+ Blok ekle" / "+ Gün ekle" `primary` metin butonlar. Kaydet AppBar'da kalır.

**`ExercisePickerScreen`:** arama kutusu temadan (`surfaceContainer` dolgu, radius 12); kas/ekipman filtre çipleri neon seçili; satırlar: ad + gri kas/ekipman alt satırı, satırlar arası `outlineVariant` çizgi. FAB `primary`.

**Sayfalar/diyaloglar** (`ExerciseDetailSheet`, `OneRepMaxSheet`, `BlockEditDialog`, özel hareket diyaloğu, onay diyalogları): yalnız temadan stil; kodda elle renk varsa tema karşılığıyla değişir.

## 7. Geçmiş ve Haftalık Tablo

**`HistoryScreen`:**
- Liste başında `WeeklySummaryCard` (yedi satırın hepsi; yükleniyor/hata/boş durumları aynı).
- Altında `SectionHeader(workout.history.sessions)` ("Antrenmanlar") ve oturum kartları (`history_${id}`): `surfaceContainer` radius 16, ad (Montserrat 800), altında gri `historyListSubtitle`, sağda `chevron_right`.
- Oturum yoksa: haftalık kart yine görünür, altında `history_empty` metni (bugün ekranda yalnız bu metin vardı; küçük fark).
- Yükleniyor/hata: aynı.

**Alt satır yardımcıları** (`history_screen.dart`):
- `historyDateLabel(DateTime startedAt, DateTime now)` → "4 Ekim"; yıl `now.year`'dan farklıysa "4 Ekim 2025". Ay adı `home.month_*` anahtarlarından.
- `historyListSubtitle(session, now)` → "{tarih} · {süre} · {hacim} kg" (program adı yok).
- Mevcut `historySubtitle` kaldırılır; detay ekranı kendi başlığını kurar. `now` `nowProvider`'dan.

**`WeeklySummaryCard`:** başlık `SectionHeader` stiline yakın (mevcut `ProgressCardHeader` kalır); tablo rakam sütunları sağa hizalı, değerler `titleSmall` Montserrat 800, sütun başlıkları ve satır etiketleri gri. Fark sütunu: `workouts`, `sets`, `volume` satırlarında pozitif fark `primary`; diğer satırlar ve sıfır/negatif farklar `onSurfaceVariant`. Anahtarlar (`weekly_*`) aynı.

**`HistoryDetailScreen`:**
- AppBar başlığı boş kalmaz: `workoutName`; sağda sil (`history_delete_button`).
- Gövde başında gri büyük harf satır "{tarih} · {programName}" (`history_detail_meta`), altında üç `StatBox` (süre, set, hacim).
- Her hareket bir kart: ad (Montserrat 800), set satırları "n · {kg} kg × {tekrar}" (mevcut `_doneLabel`), yapılmayan set gri `workout.history.not_done`. Anahtarlar (`history_set_${id}`) aynı.

## 8. Kurallar (R1/R2'den)

- Ekran/bileşen kodunda elle renk yok; renkler `colorScheme`'den (`primary`, `onPrimary`, `onSurface`, `onSurfaceVariant`, `outlineVariant`, `surfaceContainer`, `error`).
- Büyük harf yalnız `upperCaseFor`; buton metinleri büyük harfe çevrilmez.
- Mevcut `Key`'lerin hepsi korunur (yalnız §5/§6'da belirtilen anahtar taşımaları).
- `flutter analyze --no-pub` temiz; `await` sonrası `mounted` kontrolü.

## 9. Çeviriler

Yeni anahtarlar (tr/en): `workout.session.col_set`, `col_target`, `col_kg`, `col_reps`, `stat_duration`, `stat_sets`, `stat_volume`, `done_tag` ("Bitti"), `sets_count` ("{n} set"), `summary_done`; `workout.active_tag` ("AKTİF"); `workout.history.sessions`. Kullanılmayan hâle gelen anahtarlar silinir (plan aşamasında `grep` ile).

## 10. Test

- `StatBox`: değer ve etiket görünür, `valueKey` atanır.
- `SessionScreen`: özet şeridi değerleri (set x/y, hacim), ilerleme çubuğu oranı; tüm setleri biten hareket katlı (`session_exercise_collapsed_*`), dokununca setler görünür; biten olmayan hareket açık.
- `SessionSummaryScreen`: kutular ve 1RM kartı; mevcut kaydet/ret testleri geçer.
- `ProgramCard`: aktifken `program_card_active_tag` var, değilken yok.
- `HistoryScreen`: `WeeklySummaryCard` görünür (boş geçmişte de); `historyDateLabel` yıl kuralı (aynı yıl / farklı yıl); liste alt satırında program adı yok.
- `HistoryDetailScreen`: meta satırı ve üç kutu.
- Mevcut testler gerektiğinde güncellenir (ör. katlı karttaki sete dokunan test önce kartı açar; `historySubtitle` testi yeni yardımcılara taşınır).
- Son doğrulama: kullanıcı terminalinde `flutter test --no-pub -j 1` + `flutter build web --release --no-pub` + elle kontrol listesi, sonra PLAN.md satırı ve dal birleştirme.

## 11. Riskler

- Katlanan kartlar: set ✓'sine dokunan mevcut widget testleri bitmiş harekette seti bulamayabilir → plan her testi tek tek kontrol eder.
- `StatBox` üçlüsü dar ekranda (≈320 px) uzun hacim değerinde (ör. "12500") taşabilir → değer `FittedBox(fit: scaleDown)` içinde.
- R1'deki önbellek sorunu: yeni çeviriler için elle kontrolde tarayıcı önbelleği temizlenir.

## 12. Kapsam Dışı

- Odak modu (tek set ekranı), hareketler arası kaydırma.
- Programlar vitrini (ızgara/yatay kaydırma).
- Kilo/güç/ölçü ekranları, antrenör, giriş/kayıt/onboarding (R4).
- Kas haritası ve oyunlaştırma (ayrı projeler).
