# F5+ R3 — Antrenman Ekranları Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Antrenman tarafındaki 8 ekranı (oturum, özet, programlar, program detayı, düzenleyici, hareket seçici, geçmiş, geçmiş detayı) R1 tasarım diliyle yenilemek; haftalık tabloyu geçmiş ekranına taşımak.

**Architecture:** Yalnız sunum katmanı değişir. İki yeni ortak bileşen (`StatBox`/`StatBoxRow`, `AccentChip`) `lib/shared/widgets/` altına eklenir; ekranlar bunları ve temayı kullanır. Oturum ekranı katlanma durumu için `ConsumerStatefulWidget` olur (yalnız ekran içi durum). Veri, provider, kayıt ve yönlendirme mantığı değişmez.

**Tech Stack:** Flutter, Riverpod 3, go_router, easy_localization, flutter_test.

**Spec:** `docs/superpowers/specs/2026-10-05-f5plus-r3-antrenman-design.md` (çerçeve: `docs/superpowers/specs/2026-10-03-f5plus-r1-tasarim-temeli-design.md` §3–§4)

## Global Constraints

- Düşük bellekli makine: görev içinde sadece ilgili test dosyaları çalıştırılır (`flutter test --no-pub <dosyalar>`). Tam paketi kullanıcı kendi terminalinde çalıştırır (`flutter test --no-pub -j 1`, Task 7).
- `flutter analyze --no-pub` "No issues found!" vermeli (info dahil). `dart format` çalıştırılmaz (projede satır genişliği ayarı yok; dosyaları 80 sütuna göre yeniden sarar), mevcut biçime elle uyulur. `await`'ten sonra `context` kullanmadan önce `mounted` / `context.mounted` kontrolü yapılır.
- Widget testlerinde `.tr()` çıktısına güvenilmez; test yerel ayarı `en`. Bulma işi `Key`, ikon ya da veri metniyle yapılır. Çevrilmiş metin karşılaştırması gerekiyorsa beklenen değer testte de `.tr()` ile üretilir.
- Ekran/bileşen kodunda elle renk (`Color(0x…)`, `Colors.x`) yazılmaz. Renkler `Theme.of(context).colorScheme`'den: vurgu = `primary`, vurgu üstü metin = `onPrimary`, ana metin = `onSurface`, ikincil metin = `onSurfaceVariant`, çizgi = `outlineVariant`, kutu zemini = `surfaceContainer`, hata = `error`.
- Başlık yazı tipi `AppFonts.heading` (`lib/core/theme/app_fonts.dart`). Büyük harfe çevirme yalnız `upperCaseFor(text, languageCode)` ile (`lib/shared/text_case.dart`). Buton metinleri büyük harfe çevrilmez.
- "Şimdi"ye bağlı kod `nowProvider` kullanır (`lib/features/workout/application/session_providers.dart`).
- Korunan anahtarlar (testler kullanıyor): `session_screen`, `session_elapsed`, `session_finish_button`, `session_menu`, `session_cancel_item`, `session_cancel_dialog`, `session_cancel_confirm`, `session_no_sets_dialog`, `session_no_sets_cancel`, `session_add_exercise`, `session_exercise_$position`, `session_exercise_menu_$position`, `session_remove_exercise_$position`, `set_weight_$id`, `set_reps_$id`, `set_check_$id`, `set_deloaded_$id`, `rest_timer_bar`, `rest_timer_remaining`, `rest_timer_add`, `rest_timer_skip`, `session_summary_screen`, `summary_duration`, `summary_sets`, `summary_volume`, `summary_1rm_$exerciseId`, `summary_save_button`, `programs_screen`, `programs_history_button`, `programs_create_fab`, `programs_active_section`, `programs_level_filter_*`, `programs_days_filter_*`, `program_card_$id`, `program_detail_screen`, `program_active_badge`, `program_activate_button`, `program_customize_button`, `program_edit_button`, `program_delete_button`, `program_delete_confirm`, `program_one_rep_max_button`, `workout_section_$index`, `workout_start_$index`, editör anahtarlarının hepsi (`editor_*`, `rename_*`, `discard_confirm`, `block_menu_*`, `weekday_option_*`), seçici anahtarlarının hepsi (`exercise_*`, `muscle_filter_*`, `equipment_filter_*`, `custom_delete_confirm`), `history_screen`, `history_empty`, `history_$id`, `history_detail_screen`, `history_delete_button`, `history_delete_confirm`, `history_set_$id`, `weekly_summary_card`, `weekly_*`.
- Commit mesajları İngilizce, `feat(workout): …` biçiminde. Sonuna boş satır + `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`.

## Spec'ten küçük netleştirmeler (kullanıcıya bildirilecek)

1. "AKTİF" etiketi için yeni çeviri anahtarı eklenmez; var olan `workout.active_badge` ("Aktif") `upperCaseFor` ile kullanılır.
2. Rakam kutularının etiketleri üç ekranda ortak: `workout.session.stat_duration` / `stat_sets` / `stat_volume` ("Süre", "Set", "Hacim"). Özet ekranının eski `summary_duration` / `summary_sets` / `summary_volume` çeviri anahtarları silinir (widget anahtarları kalır).
3. Hacim kutusunun değeri "880 kg" biçiminde (birim değerde), etiket yalnız "Hacim". Mevcut özet testi `880 kg` metnini arıyor.
4. Bitmemiş setin ✓ ikonu `outlineVariant` yerine `onSurfaceVariant` renginde: `outlineVariant` (#262830) kart zemininde neredeyse görünmüyor.
5. Set satırında "Set 1" yerine yalnız "1" (sütun başlığı SET); kilo kutusundaki "kg" eki kalkar (sütun başlığı KG). `workout.session.set_label` silinir.
6. Filtre çipleri için ortak `AccentChip` eklenir (programlar + hareket seçici); R2'deki öğün çipine dokunulmaz.

## Dosya Haritası

```
lib/shared/widgets/stat_box.dart                                # Task 1 (yeni: StatBox, StatBoxRow)
lib/shared/widgets/accent_chip.dart                             # Task 1 (yeni)
assets/translations/tr.json, en.json                            # Task 1 (ekleme), 2–3 (silme)
lib/features/workout/presentation/widgets/set_row.dart          # Task 2 (SetColumns, SetTableHeader, yeni görünüm)
lib/features/workout/presentation/widgets/rest_timer_bar.dart   # Task 2
lib/features/workout/presentation/session_screen.dart           # Task 2 (yeniden yazım)
lib/features/workout/presentation/session_summary_screen.dart   # Task 3 (yeniden yazım)
lib/features/workout/presentation/widgets/program_card.dart     # Task 4 (programDetails, ActiveTag, yeni kart)
lib/features/workout/presentation/programs_screen.dart          # Task 4
lib/features/workout/presentation/program_detail_screen.dart    # Task 4
lib/features/workout/presentation/program_editor_screen.dart    # Task 5
lib/features/workout/presentation/exercise_picker_screen.dart   # Task 5
lib/features/progress/presentation/widgets/weekly_summary_card.dart  # Task 6
lib/features/workout/presentation/history_screen.dart           # Task 6 (yeniden yazım)
lib/features/workout/presentation/history_detail_screen.dart    # Task 6 (yeniden yazım)
PLAN.md                                                         # Task 7

test/shared/widgets/stat_box_test.dart                          # Task 1 (yeni)
test/shared/widgets/accent_chip_test.dart                       # Task 1 (yeni)
test/features/workout/presentation/session_screen_test.dart     # Task 2
test/features/workout/presentation/session_summary_screen_test.dart  # Task 3
test/features/workout/presentation/programs_screen_test.dart    # Task 4
test/features/workout/presentation/program_detail_screen_test.dart   # Task 4
test/features/progress/presentation/home_cards_test.dart        # Task 6 (haftalık kart renkleri)
test/features/workout/presentation/history_screen_test.dart     # Task 6
```

---

### Task 1: Ortak bileşenler `StatBox` ve `AccentChip` + çeviriler

**Files:**
- Create: `lib/shared/widgets/stat_box.dart`, `lib/shared/widgets/accent_chip.dart`
- Modify: `assets/translations/tr.json`, `assets/translations/en.json`
- Test: `test/shared/widgets/stat_box_test.dart`, `test/shared/widgets/accent_chip_test.dart`

**Interfaces:**
- Consumes: `upperCaseFor(String text, String languageCode)` (`lib/shared/text_case.dart`), `AppFonts.heading`.
- Produces:
  - `StatBox({Key? key, required String label, required String value, Key? valueKey})` — değer `Text`'i `valueKey` alır.
  - `StatBoxRow({Key? key, required List<StatBox> children})` — kutuları eşit genişlikte, 8 px arayla dizer.
  - `AccentChip({Key? key, required String label, required bool selected, required ValueChanged<bool> onSelected})`.
  - Çeviri anahtarları: `workout.session.stat_duration`, `stat_sets`, `stat_volume`, `col_set`, `col_target`, `col_kg`, `col_reps`, `done_tag`, `sets_count` (`{n}`), `summary_done`; `workout.history.sessions`.

- [ ] **Step 1: Add translations**

`assets/translations/tr.json` içinde şu satırı:

```json
      "summary_one_rep_max": "1RM önerileri",
```

şununla değiştir:

```json
      "summary_one_rep_max": "1RM önerileri",
      "stat_duration": "Süre",
      "stat_sets": "Set",
      "stat_volume": "Hacim",
      "col_set": "Set",
      "col_target": "Hedef",
      "col_kg": "Kg",
      "col_reps": "Tek.",
      "done_tag": "Bitti",
      "sets_count": "{n} set",
      "summary_done": "Antrenman tamamlandı",
```

Aynı dosyada şu satırı:

```json
      "delete_title": "Antrenman kaydı silinsin mi?"
```

şununla değiştir:

```json
      "delete_title": "Antrenman kaydı silinsin mi?",
      "sessions": "Antrenmanlar"
```

`assets/translations/en.json` içinde şu satırı:

```json
      "summary_one_rep_max": "1RM suggestions",
```

şununla değiştir:

```json
      "summary_one_rep_max": "1RM suggestions",
      "stat_duration": "Duration",
      "stat_sets": "Sets",
      "stat_volume": "Volume",
      "col_set": "Set",
      "col_target": "Target",
      "col_kg": "Kg",
      "col_reps": "Reps",
      "done_tag": "Done",
      "sets_count": "{n} sets",
      "summary_done": "Workout complete",
```

ve şu satırı:

```json
      "delete_title": "Delete this workout log?"
```

şununla değiştir:

```json
      "delete_title": "Delete this workout log?",
      "sessions": "Workouts"
```

Run: `powershell -Command "Get-Content assets/translations/tr.json -Raw -Encoding UTF8 | ConvertFrom-Json | Out-Null; Get-Content assets/translations/en.json -Raw -Encoding UTF8 | ConvertFrom-Json | Out-Null; 'ok'"`
Expected: `ok`

- [ ] **Step 2: Write the failing tests**

`test/shared/widgets/stat_box_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spor_takip/core/theme/app_colors.dart';
import 'package:spor_takip/shared/widgets/stat_box.dart';

import 'themed.dart';

void main() {
  testWidgets('shows the value and the upper-cased label', (tester) async {
    await tester.pumpWidget(themed(const StatBox(label: 'Sets', value: '7/15', valueKey: Key('v'))));

    expect(tester.widget<Text>(find.byKey(const Key('v'))).data, '7/15');
    final label = tester.widget<Text>(find.text('SETS'));
    expect(label.style!.color, AppColors.muted);
  });

  testWidgets('a row gives every box the same width', (tester) async {
    await tester.pumpWidget(themed(const StatBoxRow(children: [
      StatBox(key: Key('a'), label: 'Duration', value: '48:20'),
      StatBox(key: Key('b'), label: 'Sets', value: '15'),
      StatBox(key: Key('c'), label: 'Volume', value: '12500 kg'),
    ])));

    final a = tester.getSize(find.byKey(const Key('a'))).width;
    expect(tester.getSize(find.byKey(const Key('b'))).width, a);
    expect(tester.getSize(find.byKey(const Key('c'))).width, a);
    expect(tester.takeException(), isNull);
  });
}
```

`test/shared/widgets/accent_chip_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spor_takip/core/theme/app_colors.dart';
import 'package:spor_takip/shared/widgets/accent_chip.dart';

import 'themed.dart';

void main() {
  testWidgets('a selected chip is filled with the accent and uses dark text', (tester) async {
    await tester.pumpWidget(themed(AccentChip(label: 'Chest', selected: true, onSelected: (_) {})));

    final chip = tester.widget<ChoiceChip>(find.byType(ChoiceChip));
    expect(chip.selectedColor, AppColors.accent);
    expect(chip.showCheckmark, isFalse);
    expect(tester.widget<Text>(find.text('Chest')).style!.color, AppColors.onAccent);
  });

  testWidgets('tapping an unselected chip reports true', (tester) async {
    bool? reported;
    await tester.pumpWidget(themed(AccentChip(label: 'Back', selected: false, onSelected: (v) => reported = v)));

    expect(tester.widget<Text>(find.text('Back')).style!.color, AppColors.text);
    await tester.tap(find.byType(AccentChip));
    expect(reported, isTrue);
  });
}
```

- [ ] **Step 3: Run tests to verify they fail**

Run: `flutter test --no-pub test/shared/widgets/stat_box_test.dart test/shared/widgets/accent_chip_test.dart`
Expected: FAIL (`stat_box.dart` / `accent_chip.dart` bulunamıyor).

- [ ] **Step 4: Implement**

`lib/shared/widgets/stat_box.dart`:

```dart
import 'package:flutter/material.dart';

import '../../core/theme/app_fonts.dart';
import '../text_case.dart';

/// Dokunulamayan küçük rakam kutusu (R3 spec §3): üstte büyük değer, altta
/// gri büyük harfli etiket. Dokunulan kutu için [StatTile] kullanılır.
class StatBox extends StatelessWidget {
  const StatBox({super.key, required this.label, required this.value, this.valueKey});

  final String label;
  final String value;
  final Key? valueKey;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(color: scheme.surfaceContainer, borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
        child: Column(
          children: [
            // Dar ekranda uzun değer (ör. "12500 kg") taşmasın diye küçülür.
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                value,
                key: valueKey,
                maxLines: 1,
                style: theme.textTheme.titleLarge?.copyWith(fontFamily: AppFonts.heading, fontWeight: FontWeight.w900),
              ),
            ),
            const SizedBox(height: 2),
            Text(
              upperCaseFor(label, Localizations.localeOf(context).languageCode),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.labelSmall?.copyWith(color: scheme.onSurfaceVariant, letterSpacing: 1),
            ),
          ],
        ),
      ),
    );
  }
}

/// [StatBox]'ları eşit genişlikte, aralarında 8 px boşlukla yan yana dizer.
class StatBoxRow extends StatelessWidget {
  const StatBoxRow({super.key, required this.children});

  final List<StatBox> children;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (final (index, box) in children.indexed) ...[
          if (index > 0) const SizedBox(width: 8),
          Expanded(child: box),
        ],
      ],
    );
  }
}
```

`lib/shared/widgets/accent_chip.dart`:

```dart
import 'package:flutter/material.dart';

/// Filtre çipi: seçiliyken neon dolu, koyu yazılı; değilken temadaki koyu çip.
class AccentChip extends StatelessWidget {
  const AccentChip({super.key, required this.label, required this.selected, required this.onSelected});

  final String label;
  final bool selected;
  final ValueChanged<bool> onSelected;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return ChoiceChip(
      label: Text(
        label,
        style: TextStyle(
          color: selected ? scheme.onPrimary : scheme.onSurface,
          fontWeight: selected ? FontWeight.w600 : null,
        ),
      ),
      selected: selected,
      showCheckmark: false,
      selectedColor: scheme.primary,
      onSelected: onSelected,
    );
  }
}
```

- [ ] **Step 5: Run tests to verify they pass**

Run: `flutter test --no-pub test/shared/widgets/stat_box_test.dart test/shared/widgets/accent_chip_test.dart`
Expected: PASS (4 tests).

Run: `flutter analyze --no-pub`
Expected: No issues found!

- [ ] **Step 6: Commit**

```bash
git add assets/translations/tr.json assets/translations/en.json lib/shared/widgets/stat_box.dart lib/shared/widgets/accent_chip.dart test/shared/widgets/stat_box_test.dart test/shared/widgets/accent_chip_test.dart
git commit -m "feat(workout): add stat box and accent chip shared widgets

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 2: Antrenman oturumu ekranı (özet şeridi, tablo satırları, katlanma, neon sayaç)

**Files:**
- Modify: `lib/features/workout/presentation/widgets/set_row.dart`, `lib/features/workout/presentation/widgets/rest_timer_bar.dart`, `assets/translations/tr.json`, `assets/translations/en.json`
- Rewrite: `lib/features/workout/presentation/session_screen.dart`
- Test: `test/features/workout/presentation/session_screen_test.dart`

**Interfaces:**
- Consumes: `StatBox`, `StatBoxRow` (Task 1); `completedSetCount`, `totalVolumeKg`, `sessionDuration`, `formatDuration` (`domain/session_stats.dart`); `trimNumber`, `sessionSetTargetLabel` (`domain/block_format.dart`); `WorkoutSession.exerciseGroups`, `SessionSet.isCompleted`.
- Produces: `SetColumns` (sütun genişlikleri), `SetTableHeader` (`set_row.dart`). Yeni anahtarlar: `session_workout_name`, `session_sets_progress`, `session_volume`, `session_progress_bar`, `session_exercise_header_$position`, `session_exercise_progress_$position`, `session_exercise_collapsed_$position`, `set_number_$id`.

- [ ] **Step 1: Write the failing tests**

`test/features/workout/presentation/session_screen_test.dart` içinde `_s` fonksiyonunun hemen altına ekle:

```dart
SessionSet _done(String id, {int idx = 0}) => SessionSet(
      id: id,
      exercisePosition: 0,
      setIndex: idx,
      exerciseId: 'Barbell_Squat',
      exerciseName: 'Barbell Squat',
      targetRepsMin: 5,
      targetRepsMax: 5,
      restSeconds: 90,
      suggestedWeightKg: 60,
      weightKg: 60,
      reps: 5,
      completedAt: DateTime(2026, 9, 26, 10, 10),
    );
```

`String fieldText(...)` yardımcısının altına ekle:

```dart
  String keyText(WidgetTester tester, String key) => tester.widget<Text>(find.byKey(Key(key))).data!;

  double progress(WidgetTester tester) =>
      tester.widget<LinearProgressIndicator>(find.byKey(const Key('session_progress_bar'))).value!;
```

Dosyanın sonundaki `}`'den önce şu testleri ekle:

```dart
  testWidgets('the stats strip shows duration, set progress and volume', (tester) async {
    await open(tester);

    expect(keyText(tester, 'session_elapsed'), '30:00');
    expect(keyText(tester, 'session_sets_progress'), '0/2');
    expect(keyText(tester, 'session_volume'), '0 kg');
    expect(progress(tester), 0);
    expect(keyText(tester, 'session_exercise_progress_0'), '0/2');

    await tester.tap(find.byKey(const Key('set_check_a')));
    await tester.pumpAndSettle();

    expect(keyText(tester, 'session_sets_progress'), '1/2');
    expect(keyText(tester, 'session_volume'), '300 kg');
    expect(progress(tester), 0.5);
    expect(keyText(tester, 'session_exercise_progress_0'), '1/2');
  });

  testWidgets('an exercise with every set done collapses and opens on tap', (tester) async {
    repo = FakeSessionRepository(sessions: [
      WorkoutSession(
        id: 'sess',
        programId: 'p1',
        programName: 'StrongLifts 5x5',
        workoutName: 'Antrenman A',
        workoutPosition: 0,
        startedAt: DateTime(2026, 9, 26, 10),
        sets: [_done('a'), _done('b', idx: 1)],
      ),
    ]);
    await open(tester);

    expect(find.byKey(const Key('session_exercise_collapsed_0')), findsOneWidget);
    expect(find.byKey(const Key('session_exercise_0')), findsNothing);
    expect(find.byKey(const Key('set_check_a')), findsNothing);
    expect(keyText(tester, 'session_sets_progress'), '2/2');

    await tester.tap(find.byKey(const Key('session_exercise_collapsed_0')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('set_check_a')), findsOneWidget);
    expect(find.byKey(const Key('session_exercise_collapsed_0')), findsNothing);

    await tester.tap(find.byKey(const Key('session_exercise_header_0')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('session_exercise_collapsed_0')), findsOneWidget);
  });

  testWidgets('the app bar shows the workout and program names', (tester) async {
    await open(tester);

    expect(find.byKey(const Key('session_workout_name')), findsOneWidget);
    expect(find.text('StrongLifts 5x5'), findsOneWidget);
    expect(keyText(tester, 'set_number_a'), '1');
    expect(keyText(tester, 'set_number_b'), '2');
  });
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `flutter test --no-pub test/features/workout/presentation/session_screen_test.dart`
Expected: 3 yeni test FAIL (`session_sets_progress`, `session_exercise_collapsed_0`, `session_workout_name` bulunamıyor); eski 9 test PASS.

- [ ] **Step 3: Rewrite `set_row.dart`**

`lib/features/workout/presentation/widgets/set_row.dart` dosyasının tamamını şununla değiştir:

```dart
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../shared/text_case.dart';
import '../../domain/block_format.dart';
import '../../domain/workout_session.dart';

String _weightText(SessionSet set) {
  final kg = set.displayWeightKg;
  return kg == null ? '' : trimNumber(kg);
}

String _repsText(SessionSet set) => set.displayReps?.toString() ?? '';

/// SET · HEDEF · KG · TEK. · ✓ sütun genişlikleri; başlık ve satırlar paylaşır.
abstract final class SetColumns {
  static const number = 32.0;
  static const weight = 72.0;
  static const gap = 8.0;
  static const reps = 56.0;
  static const check = 48.0;
}

/// Hareket kartındaki gri sütun başlıkları.
class SetTableHeader extends StatelessWidget {
  const SetTableHeader({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final style = theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.onSurfaceVariant, letterSpacing: 1);
    final languageCode = Localizations.localeOf(context).languageCode;
    String h(String key) => upperCaseFor(key.tr(), languageCode);
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 2),
      child: Row(
        children: [
          SizedBox(width: SetColumns.number, child: Text(h('workout.session.col_set'), style: style)),
          Expanded(child: Text(h('workout.session.col_target'), style: style)),
          SizedBox(
            width: SetColumns.weight,
            child: Text(h('workout.session.col_kg'), textAlign: TextAlign.center, style: style),
          ),
          const SizedBox(width: SetColumns.gap),
          SizedBox(
            width: SetColumns.reps,
            child: Text(h('workout.session.col_reps'), textAlign: TextAlign.center, style: style),
          ),
          const SizedBox(width: SetColumns.check),
        ],
      ),
    );
  }
}

/// `n · hedef · [kilo] · [tekrar] · ✓`. Tamamlanmış satırın kutuları
/// kilitlidir; ✓'ye tekrar basınca işaret kalkar ve düzenlenebilir.
class SetRow extends StatefulWidget {
  const SetRow({
    super.key,
    required this.set,
    required this.number,
    required this.onWeightChanged,
    required this.onRepsChanged,
    required this.onToggle,
  });

  final SessionSet set;
  final int number;
  final ValueChanged<double?> onWeightChanged;
  final ValueChanged<int?> onRepsChanged;
  final VoidCallback onToggle;

  @override
  State<SetRow> createState() => _SetRowState();
}

class _SetRowState extends State<SetRow> {
  late final _weight = TextEditingController(text: _weightText(widget.set));
  late final _reps = TextEditingController(text: _repsText(widget.set));
  final _weightFocus = FocusNode();
  final _repsFocus = FocusNode();

  @override
  void didUpdateWidget(SetRow oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Başka satırdan yayılan kilo ya da geri alınan değer; yazılan kutuya dokunma.
    _sync(_weight, _weightFocus, _weightText(widget.set));
    _sync(_reps, _repsFocus, _repsText(widget.set));
  }

  void _sync(TextEditingController controller, FocusNode focus, String text) {
    if (!focus.hasFocus && controller.text != text) controller.text = text;
  }

  @override
  void dispose() {
    _weight.dispose();
    _reps.dispose();
    _weightFocus.dispose();
    _repsFocus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final set = widget.set;
    final done = set.isCompleted;
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final valueStyle = TextStyle(color: done ? colors.onSurfaceVariant : colors.onSurface, fontWeight: FontWeight.w600);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              SizedBox(
                width: SetColumns.number,
                child: Text('${widget.number}', key: Key('set_number_${set.id}'), style: valueStyle),
              ),
              Expanded(
                child: Text(
                  sessionSetTargetLabel(set),
                  style: TextStyle(color: done ? colors.onSurfaceVariant : colors.onSurface),
                ),
              ),
              SizedBox(
                width: SetColumns.weight,
                child: TextField(
                  key: Key('set_weight_${set.id}'),
                  controller: _weight,
                  focusNode: _weightFocus,
                  enabled: !done,
                  textAlign: TextAlign.center,
                  style: valueStyle,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]'))],
                  decoration: const InputDecoration(isDense: true),
                  onChanged: (text) => widget.onWeightChanged(double.tryParse(text.replaceAll(',', '.'))),
                ),
              ),
              const SizedBox(width: SetColumns.gap),
              SizedBox(
                width: SetColumns.reps,
                child: TextField(
                  key: Key('set_reps_${set.id}'),
                  controller: _reps,
                  focusNode: _repsFocus,
                  enabled: !done,
                  textAlign: TextAlign.center,
                  style: valueStyle,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  decoration: InputDecoration(isDense: true, hintText: set.isAmrap ? '+' : null),
                  onChanged: (text) => widget.onRepsChanged(int.tryParse(text)),
                ),
              ),
              SizedBox(
                width: SetColumns.check,
                child: IconButton(
                  key: Key('set_check_${set.id}'),
                  onPressed: widget.onToggle,
                  color: done ? colors.primary : colors.onSurfaceVariant,
                  icon: Icon(done ? Icons.check_circle : Icons.check_circle_outline),
                ),
              ),
            ],
          ),
          if (set.deloaded && !done)
            Text(
              'workout.session.deloaded'.tr(),
              key: Key('set_deloaded_${set.id}'),
              style: theme.textTheme.bodySmall?.copyWith(color: colors.onSurfaceVariant),
            ),
        ],
      ),
    );
  }
}
```

- [ ] **Step 4: Restyle `RestTimerBar`**

`lib/features/workout/presentation/widgets/rest_timer_bar.dart` içinde `final timer = ref.read(restTimerProvider.notifier);` satırından dosyanın sonuna kadar olan kısmı şununla değiştir:

```dart
    final timer = ref.read(restTimerProvider.notifier);
    final theme = Theme.of(context);
    final onBar = theme.colorScheme.onPrimary;
    return Material(
      key: const Key('rest_timer_bar'),
      color: theme.colorScheme.primary,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 8, 10),
          child: IconTheme.merge(
            data: IconThemeData(color: onBar),
            child: Row(
              children: [
                const Icon(Icons.timer_outlined),
                const SizedBox(width: 8),
                Text(
                  formatDuration(remaining),
                  key: const Key('rest_timer_remaining'),
                  style: theme.textTheme.headlineSmall?.copyWith(color: onBar, fontWeight: FontWeight.w900),
                ),
                const SizedBox(width: 8),
                // Dar ekranda düğmelere yer kalsın diye etiket kısalır.
                Expanded(
                  child: Text(
                    'workout.session.rest'.tr(),
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodyMedium?.copyWith(color: onBar, fontWeight: FontWeight.w600),
                  ),
                ),
                TextButton(
                  key: const Key('rest_timer_add'),
                  style: TextButton.styleFrom(foregroundColor: onBar),
                  onPressed: () => timer.addSeconds(30),
                  child: Text('workout.session.rest_add'.tr()),
                ),
                IconButton(
                  key: const Key('rest_timer_skip'),
                  onPressed: timer.stop,
                  tooltip: 'workout.session.rest_skip'.tr(),
                  color: onBar,
                  icon: const Icon(Icons.skip_next),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
```

- [ ] **Step 5: Rewrite `session_screen.dart`**

`lib/features/workout/presentation/session_screen.dart` dosyasının tamamını şununla değiştir:

```dart
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_fonts.dart';
import '../../../shared/text_case.dart';
import '../../../shared/widgets/stat_box.dart';
import '../application/rest_timer.dart';
import '../application/session_notifier.dart';
import '../application/session_providers.dart';
import '../domain/block_format.dart';
import '../domain/exercise.dart';
import '../domain/session_stats.dart';
import '../domain/workout_session.dart';
import 'widgets/rest_timer_bar.dart';
import 'widgets/set_row.dart';

class SessionScreen extends ConsumerStatefulWidget {
  const SessionScreen({super.key, required this.sessionId});

  final String sessionId;

  @override
  ConsumerState<SessionScreen> createState() => _SessionScreenState();
}

class _SessionScreenState extends ConsumerState<SessionScreen> {
  /// Tüm setleri bittiği hâlde kullanıcının açtığı hareketler (exercisePosition).
  /// Yalnız görünüm durumu; kaydedilmez.
  final Set<int> _expanded = {};

  String get _sessionId => widget.sessionId;

  SessionNotifier get _notifier => ref.read(sessionNotifierProvider(_sessionId).notifier);

  void _snack(String key) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(key.tr())));
  }

  Future<void> _complete(SessionSet set) async {
    if (set.displayReps == null) {
      _snack('workout.session.reps_required');
      return;
    }
    final ok = await _notifier.complete(set.id!);
    if (!mounted) return;
    if (ok) {
      ref.read(restTimerProvider.notifier).start(set.restSeconds);
    } else {
      _snack('workout.session.save_error');
    }
  }

  Future<void> _uncomplete(SessionSet set) async {
    final ok = await _notifier.uncomplete(set.id!);
    if (!ok && mounted) _snack('workout.session.save_error');
  }

  Future<void> _addExercise() async {
    final exercise = await context.push<Exercise>('/session/$_sessionId/exercises');
    if (exercise == null || !mounted) return;
    final ok = await _notifier.addExercise(exercise);
    if (!ok && mounted) _snack('workout.session.save_error');
  }

  Future<void> _removeExercise(int exercisePosition) async {
    final ok = await _notifier.removeExercise(exercisePosition);
    if (!ok && mounted) _snack('workout.session.save_error');
  }

  Future<bool> _confirm({
    required Key dialogKey,
    required Key confirmKey,
    required String title,
    required String body,
  }) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        key: dialogKey,
        title: Text(title.tr()),
        content: Text(body.tr()),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text('workout.cancel'.tr()),
          ),
          TextButton(
            key: confirmKey,
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text('workout.session.cancel_confirm'.tr()),
          ),
        ],
      ),
    );
    return confirmed == true;
  }

  Future<void> _cancelSession() async {
    try {
      await _notifier.cancel();
      if (mounted) context.go('/home');
    } catch (e, st) {
      debugPrint('SessionScreen.cancel failed: $e\n$st');
      if (mounted) _snack('workout.action_error');
    }
  }

  Future<void> _askCancel() async {
    final confirmed = await _confirm(
      dialogKey: const Key('session_cancel_dialog'),
      confirmKey: const Key('session_cancel_confirm'),
      title: 'workout.session.cancel_confirm_title',
      body: 'workout.session.cancel_confirm_body',
    );
    if (confirmed && mounted) await _cancelSession();
  }

  Future<void> _finish(WorkoutSession session) async {
    if (completedSetCount(session) > 0) {
      context.push('/session/$_sessionId/summary');
      return;
    }
    final cancel = await _confirm(
      dialogKey: const Key('session_no_sets_dialog'),
      confirmKey: const Key('session_no_sets_cancel'),
      title: 'workout.session.no_sets_title',
      body: 'workout.session.no_sets_body',
    );
    if (cancel && mounted) await _cancelSession();
  }

  @override
  Widget build(BuildContext context) {
    final sessionAsync = ref.watch(sessionNotifierProvider(_sessionId));
    final now = ref.watch(clockProvider).value ?? ref.watch(nowProvider)();
    final loaded = sessionAsync.value;
    final theme = Theme.of(context);

    return Scaffold(
      key: const Key('session_screen'),
      appBar: AppBar(
        title: loaded == null
            ? null
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    upperCaseFor(loaded.workoutName, Localizations.localeOf(context).languageCode),
                    key: const Key('session_workout_name'),
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                      letterSpacing: 1,
                    ),
                  ),
                  Text(
                    loaded.programName,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontFamily: AppFonts.heading,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
        actions: [
          if (loaded != null) ...[
            FilledButton(
              key: const Key('session_finish_button'),
              style: FilledButton.styleFrom(minimumSize: const Size(0, 40)),
              onPressed: () => _finish(loaded),
              child: Text('workout.session.finish'.tr()),
            ),
            PopupMenuButton<String>(
              key: const Key('session_menu'),
              onSelected: (_) => _askCancel(),
              itemBuilder: (_) => [
                PopupMenuItem(
                  key: const Key('session_cancel_item'),
                  value: 'cancel',
                  child: Text('workout.session.cancel'.tr()),
                ),
              ],
            ),
          ],
        ],
      ),
      bottomNavigationBar: const RestTimerBar(),
      body: sessionAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stackTrace) => Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('workout.session.load_error'.tr()),
              TextButton(
                onPressed: () => ref.invalidate(sessionNotifierProvider(_sessionId)),
                child: Text('workout.retry'.tr()),
              ),
            ],
          ),
        ),
        data: (session) => ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
          children: [
            _SessionStats(session: session, now: now),
            const SizedBox(height: 16),
            for (final sets in session.exerciseGroups) ...[
              _exercise(sets),
              const SizedBox(height: 8),
            ],
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                key: const Key('session_add_exercise'),
                onPressed: _addExercise,
                icon: const Icon(Icons.add),
                label: Text('workout.session.add_exercise'.tr()),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _exerciseMenu(int position) => PopupMenuButton<String>(
        key: Key('session_exercise_menu_$position'),
        onSelected: (_) => _removeExercise(position),
        itemBuilder: (_) => [
          PopupMenuItem(
            key: Key('session_remove_exercise_$position'),
            value: 'remove',
            child: Text('workout.session.remove_exercise'.tr()),
          ),
        ],
      );

  Widget _exercise(List<SessionSet> sets) {
    final position = sets.first.exercisePosition;
    final done = sets.where((s) => s.isCompleted).length;
    final allDone = done == sets.length;
    if (allDone && !_expanded.contains(position)) {
      return _CollapsedExercise(
        key: Key('session_exercise_collapsed_$position'),
        name: sets.first.exerciseName,
        setCount: sets.length,
        menu: _exerciseMenu(position),
        onTap: () => setState(() => _expanded.add(position)),
      );
    }
    final theme = Theme.of(context);
    return Card(
      key: Key('session_exercise_$position'),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          InkWell(
            key: Key('session_exercise_header_$position'),
            onTap: allDone ? () => setState(() => _expanded.remove(position)) : null,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 4, 0),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      sets.first.exerciseName,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontFamily: AppFonts.heading,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  Text(
                    '$done/${sets.length}',
                    key: Key('session_exercise_progress_$position'),
                    style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                  ),
                  _exerciseMenu(position),
                ],
              ),
            ),
          ),
          const SetTableHeader(),
          for (final (index, set) in sets.indexed) ...[
            if (index > 0) const Divider(height: 1, indent: 12, endIndent: 12),
            SetRow(
              key: ValueKey(set.id),
              set: set,
              number: index + 1,
              onWeightChanged: (kg) => _notifier.setWeight(set.id!, kg),
              onRepsChanged: (reps) => _notifier.setReps(set.id!, reps),
              onToggle: () => set.isCompleted ? _uncomplete(set) : _complete(set),
            ),
          ],
          const SizedBox(height: 4),
        ],
      ),
    );
  }
}

/// Süre · set (biten/toplam) · hacim kutuları ve altında ilerleme çubuğu.
class _SessionStats extends StatelessWidget {
  const _SessionStats({required this.session, required this.now});

  final WorkoutSession session;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final done = completedSetCount(session);
    final total = session.sets.length;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        StatBoxRow(
          children: [
            StatBox(
              label: 'workout.session.stat_duration'.tr(),
              value: formatDuration(sessionDuration(session, now)),
              valueKey: const Key('session_elapsed'),
            ),
            StatBox(
              label: 'workout.session.stat_sets'.tr(),
              value: '$done/$total',
              valueKey: const Key('session_sets_progress'),
            ),
            StatBox(
              label: 'workout.session.stat_volume'.tr(),
              value: '${trimNumber(totalVolumeKg(session))} kg',
              valueKey: const Key('session_volume'),
            ),
          ],
        ),
        const SizedBox(height: 10),
        ClipRRect(
          borderRadius: BorderRadius.circular(3),
          child: LinearProgressIndicator(
            key: const Key('session_progress_bar'),
            value: total == 0 ? 0 : done / total,
            minHeight: 5,
          ),
        ),
      ],
    );
  }
}

/// Tüm setleri biten hareketin tek satırlık hâli; dokununca açılır.
class _CollapsedExercise extends StatelessWidget {
  const _CollapsedExercise({
    super.key,
    required this.name,
    required this.setCount,
    required this.menu,
    required this.onTap,
  });

  final String name;
  final int setCount;
  final Widget menu;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 4, 4),
          child: Row(
            children: [
              Expanded(
                child: Text.rich(
                  TextSpan(
                    children: [
                      TextSpan(
                        text: name,
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontFamily: AppFonts.heading,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      TextSpan(
                        text: '  ·  ${'workout.session.sets_count'.tr(namedArgs: {'n': '$setCount'})}',
                        style: theme.textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
                      ),
                    ],
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              DecoratedBox(
                decoration: BoxDecoration(color: scheme.primary, borderRadius: BorderRadius.circular(6)),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  child: Text(
                    '✓ ${'workout.session.done_tag'.tr()}',
                    style: theme.textTheme.labelSmall?.copyWith(color: scheme.onPrimary, fontWeight: FontWeight.w700),
                  ),
                ),
              ),
              menu,
            ],
          ),
        ),
      ),
    );
  }
}
```

- [ ] **Step 6: Remove the unused `set_label` translation**

Run: `grep -rn "set_label" lib test`
Expected: çıktı yok.

`assets/translations/tr.json` ve `assets/translations/en.json` içinden şu satırı sil (iki dosyada da aynı):

```json
      "set_label": "Set {n}",
```

JSON doğrulaması: Task 1 Step 1'deki `powershell` komutu → `ok`.

- [ ] **Step 7: Run tests to verify they pass**

Run: `flutter test --no-pub test/features/workout/presentation/session_screen_test.dart test/features/workout/presentation/today_workout_card_test.dart`
Expected: PASS (session 12 test + today kartı testleri).

Run: `flutter analyze --no-pub`
Expected: No issues found!

- [ ] **Step 8: Commit**

```bash
git add assets/translations/tr.json assets/translations/en.json lib/features/workout/presentation/session_screen.dart lib/features/workout/presentation/widgets/set_row.dart lib/features/workout/presentation/widgets/rest_timer_bar.dart test/features/workout/presentation/session_screen_test.dart
git commit -m "feat(workout): redesign session screen with stats strip and collapsing exercises

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 3: Oturum özeti ekranı

**Files:**
- Rewrite: `lib/features/workout/presentation/session_summary_screen.dart`
- Modify: `assets/translations/tr.json`, `assets/translations/en.json`
- Test: `test/features/workout/presentation/session_summary_screen_test.dart`

**Interfaces:**
- Consumes: `StatBox`, `StatBoxRow` (Task 1); `SectionHeader(String title, {String? trailing})` (`lib/shared/widgets/section_header.dart`); `oneRepMaxSuggestions`, `OneRepMaxSuggestion` (`domain/progression.dart`, alanlar `exerciseId`, `currentKg`, `suggestedKg`).
- Produces: anahtar `summary_title`. `summary_duration`/`summary_sets`/`summary_volume` artık `StatBox` anahtarı.

- [ ] **Step 1: Write the failing test**

`test/features/workout/presentation/session_summary_screen_test.dart` içinde son testin (`'a failed finish keeps the summary open'`) altına ekle:

```dart
  testWidgets('shows the completed header and stat boxes', (tester) async {
    await tester.pumpWidget(wrap());
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('summary_title')), findsOneWidget);
    expect(find.descendant(of: find.byKey(const Key('summary_duration')), matching: find.text('45:00')), findsOneWidget);
    expect(find.descendant(of: find.byKey(const Key('summary_sets')), matching: find.text('2')), findsOneWidget);
    expect(find.descendant(of: find.byKey(const Key('summary_volume')), matching: find.text('880 kg')), findsOneWidget);
    expect(
      find.descendant(of: find.byKey(const Key('summary_1rm_Barbell_Squat')), matching: find.byType(Checkbox)),
      findsOneWidget,
    );
  });
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test --no-pub test/features/workout/presentation/session_summary_screen_test.dart`
Expected: yeni test FAIL (`summary_title` yok); diğer 3 test PASS.

- [ ] **Step 3: Rewrite the screen**

`lib/features/workout/presentation/session_summary_screen.dart` dosyasının tamamını şununla değiştir:

```dart
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_fonts.dart';
import '../../../shared/text_case.dart';
import '../../../shared/widgets/section_header.dart';
import '../../../shared/widgets/stat_box.dart';
import '../application/session_notifier.dart';
import '../application/session_providers.dart';
import '../application/workout_providers.dart';
import '../domain/block_format.dart';
import '../domain/exercise.dart';
import '../domain/progression.dart';
import '../domain/session_stats.dart';

/// Bitir → süre, set, hacim ve onaylanacak 1RM önerileri → Kaydet.
class SessionSummaryScreen extends ConsumerStatefulWidget {
  const SessionSummaryScreen({super.key, required this.sessionId});

  final String sessionId;

  @override
  ConsumerState<SessionSummaryScreen> createState() => _SessionSummaryScreenState();
}

class _SessionSummaryScreenState extends ConsumerState<SessionSummaryScreen> {
  final Set<String> _rejected = {};
  bool _saving = false;

  Future<void> _save(List<OneRepMaxSuggestion> suggestions) async {
    setState(() => _saving = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref.read(sessionNotifierProvider(widget.sessionId).notifier).finish({
        for (final s in suggestions)
          if (!_rejected.contains(s.exerciseId)) s.exerciseId: s.suggestedKg,
      });
      if (mounted) context.go('/home');
    } catch (e, st) {
      debugPrint('SessionSummaryScreen.save failed: $e\n$st');
      messenger.showSnackBar(SnackBar(content: Text('workout.session.save_error'.tr())));
      if (mounted) setState(() => _saving = false);
    }
  }

  void _toggle(String exerciseId, bool accepted) {
    setState(() {
      if (accepted) {
        _rejected.remove(exerciseId);
      } else {
        _rejected.add(exerciseId);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(sessionNotifierProvider(widget.sessionId)).value;
    final oneRepMaxes = ref.watch(oneRepMaxesProvider).value ?? const <String, double>{};
    final exercises = ref.watch(exercisesProvider).value ?? const <Exercise>[];
    if (session == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final names = {
      for (final e in exercises) e.id: e.name,
      for (final s in session.sets) s.exerciseId: s.exerciseName,
    };
    final suggestions = oneRepMaxSuggestions(sets: session.sets, oneRepMaxes: oneRepMaxes);
    final now = ref.watch(nowProvider)();
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Scaffold(
      key: const Key('session_summary_screen'),
      appBar: AppBar(title: Text('workout.session.summary_title'.tr())),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          child: FilledButton(
            key: const Key('summary_save_button'),
            onPressed: _saving ? null : () => _save(suggestions),
            child: Text('workout.session.save'.tr()),
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            upperCaseFor('workout.session.summary_done'.tr(), Localizations.localeOf(context).languageCode),
            style: theme.textTheme.labelMedium?.copyWith(color: scheme.onSurfaceVariant, letterSpacing: 1),
          ),
          const SizedBox(height: 4),
          Text.rich(
            TextSpan(
              children: [
                TextSpan(text: session.workoutName),
                TextSpan(text: ' ✓', style: TextStyle(color: scheme.primary)),
              ],
            ),
            key: const Key('summary_title'),
            style: theme.textTheme.headlineMedium,
          ),
          Text(session.programName, style: theme.textTheme.bodyMedium?.copyWith(color: scheme.onSurfaceVariant)),
          const SizedBox(height: 16),
          StatBoxRow(
            children: [
              StatBox(
                key: const Key('summary_duration'),
                label: 'workout.session.stat_duration'.tr(),
                value: formatDuration(sessionDuration(session, now)),
              ),
              StatBox(
                key: const Key('summary_sets'),
                label: 'workout.session.stat_sets'.tr(),
                value: '${completedSetCount(session)}',
              ),
              StatBox(
                key: const Key('summary_volume'),
                label: 'workout.session.stat_volume'.tr(),
                value: '${trimNumber(totalVolumeKg(session))} kg',
              ),
            ],
          ),
          if (suggestions.isNotEmpty) ...[
            SectionHeader('workout.session.summary_one_rep_max'.tr()),
            for (final s in suggestions)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: _SuggestionCard(
                  key: Key('summary_1rm_${s.exerciseId}'),
                  name: names[s.exerciseId] ?? s.exerciseId,
                  currentKg: s.currentKg,
                  suggestedKg: s.suggestedKg,
                  accepted: !_rejected.contains(s.exerciseId),
                  onChanged: (accepted) => _toggle(s.exerciseId, accepted),
                ),
              ),
          ],
        ],
      ),
    );
  }
}

/// "Squat · 100 → 105 kg" ve onay kutusu; kartın tamamı dokunulabilir.
class _SuggestionCard extends StatelessWidget {
  const _SuggestionCard({
    super.key,
    required this.name,
    required this.currentKg,
    required this.suggestedKg,
    required this.accepted,
    required this.onChanged,
  });

  final String name;
  final double currentKg;
  final double suggestedKg;
  final bool accepted;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => onChanged(!accepted),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 8, 10),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontFamily: AppFonts.heading,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    Text.rich(
                      TextSpan(
                        children: [
                          TextSpan(text: '${trimNumber(currentKg)} → '),
                          TextSpan(
                            text: '${trimNumber(suggestedKg)} kg',
                            style: TextStyle(color: scheme.primary, fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                      style: theme.textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
              Checkbox(value: accepted, onChanged: (value) => onChanged(value ?? false)),
            ],
          ),
        ),
      ),
    );
  }
}
```

- [ ] **Step 4: Remove the unused summary translations**

Run: `grep -rn "summary_duration'\|summary_sets'\|summary_volume'" lib --include=*.dart`
Expected: yalnız `Key('summary_…')` satırları (çeviri anahtarı `workout.session.summary_…'.tr()` kullanımı yok).

`assets/translations/tr.json` içinden şu üç satırı sil:

```json
      "summary_duration": "Süre",
      "summary_sets": "Tamamlanan set",
      "summary_volume": "Toplam hacim",
```

`assets/translations/en.json` içinden şu üç satırı sil:

```json
      "summary_duration": "Duration",
      "summary_sets": "Completed sets",
      "summary_volume": "Total volume",
```

JSON doğrulaması: Task 1 Step 1'deki `powershell` komutu → `ok`.

- [ ] **Step 5: Run tests to verify they pass**

Run: `flutter test --no-pub test/features/workout/presentation/session_summary_screen_test.dart`
Expected: PASS (4 test).

Run: `flutter analyze --no-pub`
Expected: No issues found!

- [ ] **Step 6: Commit**

```bash
git add assets/translations/tr.json assets/translations/en.json lib/features/workout/presentation/session_summary_screen.dart test/features/workout/presentation/session_summary_screen_test.dart
git commit -m "feat(workout): redesign session summary with stat boxes and 1RM cards

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 4: Programlar listesi, program kartı ve program detayı

**Files:**
- Rewrite: `lib/features/workout/presentation/widgets/program_card.dart`
- Modify: `lib/features/workout/presentation/programs_screen.dart`, `lib/features/workout/presentation/program_detail_screen.dart`
- Test: `test/features/workout/presentation/programs_screen_test.dart`, `test/features/workout/presentation/program_detail_screen_test.dart`

**Interfaces:**
- Consumes: `AccentChip` (Task 1), `SectionHeader`, `upperCaseFor`, `AppFonts.heading`; `Program` alanları `name`, `level`, `effectiveDaysPerWeek`, `scheduleMode`, `isBuiltIn`, `usesPercentages`, `workouts`, `description`.
- Produces: `String programDetails(Program program)`, `ActiveTag({Key? key})` (`program_card.dart`). Yeni anahtarlar: `program_card_active_tag`, `program_detail_meta`.

- [ ] **Step 1: Write the failing tests**

`test/features/workout/presentation/programs_screen_test.dart` içinde `'shows my programs and built-in programs'` testinin son satırından sonra (`programs_active_section` beklentisinin altına) ekle:

```dart
    expect(find.byKey(const Key('program_card_active_tag')), findsNothing);
```

`'shows the active program at the top'` testinin sonuna ekle:

```dart
    expect(find.descendant(of: activeSection, matching: find.byKey(const Key('program_card_active_tag'))), findsOneWidget);
```

`test/features/workout/presentation/program_detail_screen_test.dart` içinde `'groups consecutive blocks and shows percentages without a 1RM'` testinin sonuna ekle:

```dart
    expect(find.byKey(const Key('program_detail_meta')), findsOneWidget);
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `flutter test --no-pub test/features/workout/presentation/programs_screen_test.dart test/features/workout/presentation/program_detail_screen_test.dart`
Expected: 2 test FAIL (`program_card_active_tag`, `program_detail_meta` bulunamıyor).

- [ ] **Step 3: Rewrite `program_card.dart`**

`lib/features/workout/presentation/widgets/program_card.dart` dosyasının tamamını şununla değiştir:

```dart
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../../../../core/theme/app_fonts.dart';
import '../../../../shared/text_case.dart';
import '../../domain/program.dart';

/// "Orta · 4 gün · Rotasyon" — program kartında ve detayında aynı satır.
String programDetails(Program program) {
  final days = program.effectiveDaysPerWeek;
  return [
    if (program.level != null) 'workout.level_${program.level!.name}'.tr(),
    if (days != null) 'workout.days_per_week'.tr(namedArgs: {'count': '$days'}),
    'workout.mode_${program.scheduleMode.name}'.tr(),
  ].join(' · ');
}

/// Neon "AKTİF" etiketi.
class ActiveTag extends StatelessWidget {
  const ActiveTag({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(color: scheme.primary, borderRadius: BorderRadius.circular(6)),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        child: Text(
          upperCaseFor('workout.active_badge'.tr(), Localizations.localeOf(context).languageCode),
          style: theme.textTheme.labelSmall?.copyWith(
            color: scheme.onPrimary,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.8,
          ),
        ),
      ),
    );
  }
}

class ProgramCard extends StatelessWidget {
  const ProgramCard({super.key, required this.program, this.isActive = false, this.onTap});

  final Program program;
  final bool isActive;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Card(
        clipBehavior: Clip.antiAlias,
        shape: isActive
            ? RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(color: scheme.primary, width: 1.5),
              )
            : null,
        child: InkWell(
          key: Key('program_card_${program.id}'),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              program.name,
                              style: theme.textTheme.titleSmall?.copyWith(
                                fontFamily: AppFonts.heading,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                          if (isActive) ...[
                            const SizedBox(width: 8),
                            const ActiveTag(key: Key('program_card_active_tag')),
                          ],
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        programDetails(program),
                        style: theme.textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
                      ),
                    ],
                  ),
                ),
                Icon(Icons.chevron_right, color: scheme.onSurfaceVariant),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
```

- [ ] **Step 4: Update `programs_screen.dart`**

Importlara ekle:

```dart
import '../../../shared/widgets/accent_chip.dart';
import '../../../shared/widgets/section_header.dart';
```

`_buildList` içinde `final titleStyle = Theme.of(context).textTheme.titleMedium;` satırını sil. `return ListView(` bloğunu (fonksiyonun sonuna kadar) şununla değiştir:

```dart
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 96),
      children: [
        if (active != null)
          Column(
            key: const Key('programs_active_section'),
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SectionHeader('workout.active_program'.tr()),
              ProgramCard(program: active, isActive: true, onTap: () => open(active)),
            ],
          ),
        SectionHeader('workout.my_programs'.tr()),
        if (mine.isEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(
              'workout.no_my_programs'.tr(),
              style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
            ),
          ),
        for (final p in mine) ProgramCard(key: ValueKey('mine_${p.id}'), program: p, onTap: () => open(p)),
        SectionHeader('workout.built_in_programs'.tr()),
        Wrap(
          spacing: 8,
          runSpacing: 6,
          children: [
            AccentChip(
              key: const Key('programs_level_filter_all'),
              label: 'workout.filter_all'.tr(),
              selected: _level == null,
              onSelected: (_) => setState(() => _level = null),
            ),
            for (final level in ProgramLevel.values)
              AccentChip(
                key: Key('programs_level_filter_${level.name}'),
                label: 'workout.level_${level.name}'.tr(),
                selected: _level == level,
                onSelected: (_) => setState(() => _level = level),
              ),
          ],
        ),
        const SizedBox(height: 6),
        Wrap(
          spacing: 8,
          runSpacing: 6,
          children: [
            AccentChip(
              key: const Key('programs_days_filter_all'),
              label: 'workout.filter_all'.tr(),
              selected: _days == null,
              onSelected: (_) => setState(() => _days = null),
            ),
            for (final d in _dayOptions)
              AccentChip(
                key: Key('programs_days_filter_$d'),
                label: 'workout.days_per_week'.tr(namedArgs: {'count': '$d'}),
                selected: _days == d,
                onSelected: (_) => setState(() => _days = d),
              ),
          ],
        ),
        const SizedBox(height: 12),
        if (builtIn.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Text('workout.no_filter_results'.tr()),
          ),
        for (final p in builtIn) ProgramCard(key: ValueKey('builtin_${p.id}'), program: p, onTap: () => open(p)),
      ],
    );
  }
}
```

- [ ] **Step 5: Update `program_detail_screen.dart`**

Importlara ekle:

```dart
import '../../../core/theme/app_fonts.dart';
import 'widgets/program_card.dart';
```

`data: (program) {` bloğunu (`},` ile kapanan `data` gövdesinin tamamı) şununla değiştir:

```dart
        data: (program) {
          final isActive = program.id == activeId;
          final theme = Theme.of(context);
          final scheme = theme.colorScheme;
          final muted = theme.textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant);
          final heading = theme.textTheme.titleSmall?.copyWith(
            fontFamily: AppFonts.heading,
            fontWeight: FontWeight.w800,
          );
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Row(
                children: [
                  Flexible(child: Text(programDetails(program), key: const Key('program_detail_meta'), style: muted)),
                  if (isActive) ...[
                    const SizedBox(width: 8),
                    const ActiveTag(key: Key('program_active_badge')),
                  ],
                ],
              ),
              if (program.description != null) ...[
                const SizedBox(height: 8),
                Text(program.description!),
              ],
              const SizedBox(height: 16),
              if (!isActive) ...[
                FilledButton(
                  key: const Key('program_activate_button'),
                  onPressed: () => _run(context, () => activateProgram(context, ref, program)),
                  child: Text('workout.activate'.tr()),
                ),
                const SizedBox(height: 8),
              ],
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  if (program.isBuiltIn)
                    OutlinedButton(
                      key: const Key('program_customize_button'),
                      onPressed: () => _run(context, () => _customize(context, ref, program)),
                      child: Text('workout.customize'.tr()),
                    )
                  else
                    OutlinedButton(
                      key: const Key('program_edit_button'),
                      onPressed: () => context.push('/workout/program/${program.id}/edit'),
                      child: Text('workout.edit'.tr()),
                    ),
                  if (program.usesPercentages)
                    OutlinedButton(
                      key: const Key('program_one_rep_max_button'),
                      onPressed: () => showOneRepMaxSheet(context, program),
                      child: Text('workout.one_rep_max_button'.tr()),
                    ),
                  if (!program.isBuiltIn)
                    TextButton(
                      key: const Key('program_delete_button'),
                      style: TextButton.styleFrom(foregroundColor: scheme.error),
                      onPressed: () => _run(context, () => _delete(context, ref, program)),
                      child: Text('workout.delete'.tr()),
                    ),
                ],
              ),
              if (program.workouts.isEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 16),
                  child: Text('workout.no_workouts'.tr(), style: muted),
                ),
              for (final (index, workout) in program.workouts.indexed)
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Card(
                    key: Key('workout_section_$index'),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 12, 12, 4),
                          child: Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(workout.name, style: heading),
                                    if (program.scheduleMode == ScheduleMode.weekdays && workout.weekday != null)
                                      Text('workout.weekday_${workout.weekday}'.tr(), style: muted),
                                  ],
                                ),
                              ),
                              if (workout.exercises.isNotEmpty)
                                FilledButton(
                                  key: Key('workout_start_$index'),
                                  style: FilledButton.styleFrom(
                                    minimumSize: const Size(0, 36),
                                    padding: const EdgeInsets.symmetric(horizontal: 16),
                                  ),
                                  onPressed: () => _run(context, () => startWorkout(context, ref, program, index)),
                                  child: Text('workout.session.start'.tr()),
                                ),
                            ],
                          ),
                        ),
                        for (final (g, group) in groupBlocks(workout.exercises).indexed) ...[
                          if (g > 0) const Divider(indent: 16, endIndent: 16),
                          ExerciseGroupTile(group: group, oneRepMaxes: oneRepMaxes),
                        ],
                      ],
                    ),
                  ),
                ),
            ],
          );
        },
```

- [ ] **Step 6: Run tests to verify they pass**

Run: `flutter test --no-pub test/features/workout/presentation/programs_screen_test.dart test/features/workout/presentation/program_detail_screen_test.dart`
Expected: PASS (programlar 6, detay 8 test).

Run: `flutter analyze --no-pub`
Expected: No issues found! (Kullanılmayan import uyarısı çıkarsa — ör. `program_detail_screen.dart`'ta `Icons.star` için başka bir şey import edilmişse — o importu sil.)

- [ ] **Step 7: Commit**

```bash
git add lib/features/workout/presentation/widgets/program_card.dart lib/features/workout/presentation/programs_screen.dart lib/features/workout/presentation/program_detail_screen.dart test/features/workout/presentation/programs_screen_test.dart test/features/workout/presentation/program_detail_screen_test.dart
git commit -m "feat(workout): restyle programs list and program detail

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 5: Program düzenleyici ve hareket seçici

**Files:**
- Modify: `lib/features/workout/presentation/program_editor_screen.dart`, `lib/features/workout/presentation/exercise_picker_screen.dart`
- Test (mevcut, değişmez): `test/features/workout/presentation/program_editor_screen_test.dart`, `test/features/workout/presentation/exercise_picker_screen_test.dart`, `test/features/workout/presentation/one_rep_max_sheet_test.dart`

**Interfaces:**
- Consumes: `AccentChip` (Task 1), `AppFonts.heading`.
- Produces: yok (yalnız görünüm).

Bu görev yalnız stil değiştirir, yeni davranış yoktur; mevcut testler korunan anahtarlarla regresyonu yakalar.

- [ ] **Step 1: Update `program_editor_screen.dart`**

Importlara ekle:

```dart
import '../../../core/theme/app_fonts.dart';
```

`build` içindeki gün ekleme butonunda `OutlinedButton.icon(` ifadesini `TextButton.icon(` yap (anahtar `editor_add_workout` ve içerik aynı kalır).

`_workoutCard` içinde:

```dart
    return Card(
      key: Key('editor_workout_$i'),
      child: Column(
```

şununla değiştir:

```dart
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Card(
      key: Key('editor_workout_$i'),
      child: Column(
```

ve `_workoutCard`'ın sonundaki:

```dart
        ],
      ),
    );
  }
}
```

kısmını şununla değiştir:

```dart
        ],
      ),
      ),
    );
  }
}
```

Aynı fonksiyonda gün adı stilini:

```dart
            title: Text(workout.name, style: Theme.of(context).textTheme.titleMedium),
```

şununla değiştir:

```dart
            title: Text(
              workout.name,
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontFamily: AppFonts.heading,
                    fontWeight: FontWeight.w800,
                  ),
            ),
```

`Card(...)` bloğunun içini elle 2 boşluk içeri kaydır. `dart format` **çalıştırma**: projede satır genişliği ayarı yok, dosyanın tamamını 80 sütuna göre yeniden sarar.

- [ ] **Step 2: Update `exercise_picker_screen.dart`**

Importlara ekle:

```dart
import '../../../shared/widgets/accent_chip.dart';
```

`_chipRow` içinde:

```dart
              child: FilterChip(
                key: Key('$keyPrefix${taxonomySlug(v)}'),
                label: Text(label(v)),
                selected: selected == v,
                onSelected: (on) => onSelected(on ? v : null),
              ),
```

şununla değiştir:

```dart
              child: AccentChip(
                key: Key('$keyPrefix${taxonomySlug(v)}'),
                label: label(v),
                selected: selected == v,
                onSelected: (on) => onSelected(on ? v : null),
              ),
```

Sonuç listesinde:

```dart
                return ListView.builder(
                  padding: const EdgeInsets.only(bottom: 88),
                  itemCount: results.length,
```

şununla değiştir:

```dart
                return ListView.separated(
                  padding: const EdgeInsets.only(bottom: 88),
                  itemCount: results.length,
                  separatorBuilder: (context, index) => const Divider(height: 1, indent: 16, endIndent: 16),
```

- [ ] **Step 3: Run tests**

Run: `flutter test --no-pub test/features/workout/presentation/program_editor_screen_test.dart test/features/workout/presentation/exercise_picker_screen_test.dart test/features/workout/presentation/one_rep_max_sheet_test.dart`
Expected: PASS (hepsi).

Run: `flutter analyze --no-pub`
Expected: No issues found!

- [ ] **Step 4: Commit**

```bash
git add lib/features/workout/presentation/program_editor_screen.dart lib/features/workout/presentation/exercise_picker_screen.dart
git commit -m "feat(workout): restyle program editor and exercise picker

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 6: Geçmiş, haftalık tablo ve geçmiş detayı

**Files:**
- Modify: `lib/features/progress/presentation/widgets/weekly_summary_card.dart`
- Rewrite: `lib/features/workout/presentation/history_screen.dart`, `lib/features/workout/presentation/history_detail_screen.dart`
- Test: `test/features/progress/presentation/home_cards_test.dart`, `test/features/workout/presentation/history_screen_test.dart`

**Interfaces:**
- Consumes: `StatBox`, `StatBoxRow` (Task 1); `SectionHeader`; `WeeklySummaryCard`; `weeklySummaryProvider`, `recentSessionsProvider`, `allSessionsProvider` (`progress/application/progress_providers.dart`); `profileProvider` (`onboarding/application/profile_providers.dart`); `weeklySummary(...)` (`progress/domain/weekly_summary.dart`); `testProfile` (`test/features/progress/fixtures.dart`).
- Produces: `String historyDateLabel(DateTime startedAt, DateTime now)`, `String historyListSubtitle(WorkoutSession session, DateTime now)` (`history_screen.dart`); `historySubtitle` kaldırılır. Yeni anahtarlar: `history_detail_meta`, `history_detail_duration`, `history_detail_sets`, `history_detail_volume`.

- [ ] **Step 1: Write the failing tests (weekly card colors)**

`test/features/progress/presentation/home_cards_test.dart` importlarına ekle:

```dart
import 'package:spor_takip/core/theme/app_colors.dart';
```

`'weekly summary shows this week, last week and the change'` testinin altına ekle:

```dart
  testWidgets('weekly change is accent for more training and muted otherwise', (tester) async {
    await tester.pumpWidget(testApp(const WeeklySummaryCard(), overrides: [
      weeklySummaryProvider.overrideWith((ref) async => _summary),
      profileProvider.overrideWith((ref) async => testProfile),
    ]));
    await tester.pumpAndSettle();

    Color? color(String key) => tester.widget<Text>(find.byKey(Key(key))).style!.color;
    expect(color('weekly_workouts_change'), AppColors.accent);
    expect(color('weekly_volume_change'), AppColors.accent);
    expect(color('weekly_calories_change'), AppColors.muted);
    expect(color('weekly_weight_change'), AppColors.muted);
  });
```

- [ ] **Step 2: Write the failing tests (history)**

`test/features/workout/presentation/history_screen_test.dart` dosyasında:

Importlara ekle:

```dart
import 'package:spor_takip/features/onboarding/application/profile_providers.dart';
import 'package:spor_takip/features/progress/application/progress_providers.dart';
import 'package:spor_takip/features/progress/domain/weekly_summary.dart';

import '../../progress/fixtures.dart';
```

`_inProgress` tanımının altına ekle:

```dart
final _lastYear = WorkoutSession(
  id: 'old',
  programName: 'StrongLifts 5x5',
  workoutName: 'Antrenman A',
  workoutPosition: 0,
  startedAt: DateTime(2025, 12, 30, 10),
  finishedAt: DateTime(2025, 12, 30, 10, 40),
  sets: [_set('y1')],
);
```

`wrap` içindeki `overrides` listesini şununla değiştir:

```dart
        overrides: [
          isLoggedInProvider.overrideWithValue(true),
          sessionRepositoryProvider.overrideWithValue(repo),
          nowProvider.overrideWithValue(() => DateTime(2026, 9, 26, 12)),
          weeklySummaryProvider.overrideWith((ref) async => weeklySummary(
                now: DateTime(2026, 9, 26, 12),
                sessions: const [],
                meals: const [],
                weights: const [],
              )),
          profileProvider.overrideWith((ref) async => testProfile),
        ],
```

`'lists only finished sessions'` testinin sonuna ekle:

```dart
    expect(find.byKey(const Key('weekly_summary_card')), findsOneWidget);
    expect(find.text('20 ${'home.month_9'.tr()} · 50:00 · 300 kg'), findsOneWidget);
    expect(find.textContaining('StrongLifts'), findsNothing);
```

`'empty history'` testinin sonuna ekle:

```dart
    expect(find.byKey(const Key('weekly_summary_card')), findsOneWidget);
```

`'detail shows sets and deleting returns to an empty list'` testinde `expect(find.byKey(const Key('history_set_x2')), findsOneWidget);` satırının altına ekle:

```dart
    expect(tester.widget<Text>(find.byKey(const Key('history_detail_meta'))).data, contains('STRONGLIFTS 5X5'));
    expect(
      find.descendant(of: find.byKey(const Key('history_detail_volume')), matching: find.text('300 kg')),
      findsOneWidget,
    );
```

Dosyanın sonundaki `}`'den önce ekle:

```dart
  testWidgets('a session from another year shows the year', (tester) async {
    await tester.pumpWidget(wrap(FakeSessionRepository(sessions: [_lastYear])));
    await tester.pumpAndSettle();

    expect(find.text('30 ${'home.month_12'.tr()} 2025 · 40:00 · 300 kg'), findsOneWidget);
  });
```

- [ ] **Step 3: Run tests to verify they fail**

Run: `flutter test --no-pub test/features/progress/presentation/home_cards_test.dart test/features/workout/presentation/history_screen_test.dart`
Expected: FAIL — renk testi (`weekly_workouts_change` rengi accent değil), geçmiş testleri (`weekly_summary_card` yok, yeni alt satır yok, `history_detail_meta` yok).

- [ ] **Step 4: Restyle `WeeklySummaryCard`**

`lib/features/progress/presentation/widgets/weekly_summary_card.dart` dosyasında:

Importlara ekle:

```dart
import '../../../../core/theme/app_fonts.dart';
```

Typedef'i şununla değiştir:

```dart
/// `up`: daha fazla antrenman/set/hacim (olumlu artış) → fark vurgu renginde.
typedef _Row = (String key, String label, String current, String previous, String change, bool up);
```

`_rows` içinde `String weight(...)` satırının altına ekle:

```dart
    bool up(num current, num previous) => current > previous;
```

ve dönen listede ilk üç satıra `up` alanını, diğerlerine `false` ekle. Listenin tamamı:

```dart
    return [
      ('workouts', 'progress.weekly.workouts', '${t.workouts}', '${l.workouts}', formatDelta(_diff(t.workouts, l.workouts)), up(t.workouts, l.workouts)),
      ('sets', 'progress.weekly.sets', '${t.sets}', '${l.sets}', formatDelta(_diff(t.sets, l.sets)), up(t.sets, l.sets)),
      (
        'volume',
        'progress.weekly.volume',
        '${t.volumeKg.round()}',
        '${l.volumeKg.round()}',
        formatDelta(_diff(t.volumeKg.round(), l.volumeKg.round())),
        up(t.volumeKg.round(), l.volumeKg.round()),
      ),
      (
        'calories',
        'progress.weekly.calories',
        _withPercent(t.avgCalories, calorieTarget),
        _withPercent(l.avgCalories, calorieTarget),
        formatDelta(_diff(t.avgCalories?.round(), l.avgCalories?.round())),
        false,
      ),
      (
        'protein',
        'progress.weekly.protein',
        _withPercent(t.avgProteinG, proteinTarget),
        _withPercent(l.avgProteinG, proteinTarget),
        formatDelta(_diff(t.avgProteinG?.round(), l.avgProteinG?.round())),
        false,
      ),
      (
        'nutrition_days',
        'progress.weekly.nutrition_days',
        '${t.nutritionDays}',
        '${l.nutritionDays}',
        formatDelta(_diff(t.nutritionDays, l.nutritionDays)),
        false,
      ),
      ('weight', 'progress.weekly.weight', weight(t.lastWeightKg), weight(l.lastWeightKg), formatDelta(summary.weightChangeKg), false),
    ];
```

`_content` içinde `final small = Theme.of(context).textTheme.bodySmall;` satırını şununla değiştir:

```dart
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final small = theme.textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant);
    final value = theme.textTheme.titleSmall?.copyWith(fontFamily: AppFonts.heading, fontWeight: FontWeight.w800);
```

ve `Table`'ın `children` listesini şununla değiştir:

```dart
          children: [
            TableRow(children: [
              const SizedBox.shrink(),
              for (final column in const ['this_week', 'last_week', 'change'])
                Text('progress.weekly.$column'.tr(), textAlign: TextAlign.end, style: small),
            ]),
            for (final (key, label, current, previous, change, up) in _rows(summary, profile))
              TableRow(children: [
                Padding(padding: const EdgeInsets.symmetric(vertical: 4), child: Text(label.tr(), style: small)),
                Text(current, key: Key('weekly_${key}_this'), textAlign: TextAlign.end, style: value),
                Text(previous, key: Key('weekly_${key}_last'), textAlign: TextAlign.end, style: value),
                Text(
                  change,
                  key: Key('weekly_${key}_change'),
                  textAlign: TextAlign.end,
                  style: small?.copyWith(color: up ? scheme.primary : scheme.onSurfaceVariant),
                ),
              ]),
          ],
```

- [ ] **Step 5: Rewrite `history_screen.dart`**

`lib/features/workout/presentation/history_screen.dart` dosyasının tamamını şununla değiştir:

```dart
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_fonts.dart';
import '../../../shared/widgets/section_header.dart';
import '../../progress/presentation/widgets/weekly_summary_card.dart';
import '../application/session_providers.dart';
import '../domain/block_format.dart';
import '../domain/session_stats.dart';
import '../domain/workout_session.dart';

/// "4 Ekim"; yıl [now]'ınkinden farklıysa "30 Aralık 2025".
String historyDateLabel(DateTime startedAt, DateTime now) {
  final d = startedAt.toLocal();
  final label = '${d.day} ${'home.month_${d.month}'.tr()}';
  return d.year == now.year ? label : '$label ${d.year}';
}

/// "4 Ekim · 48:20 · 5850 kg" — geçmiş listesindeki alt satır (program adı detayda).
String historyListSubtitle(WorkoutSession session, DateTime now) {
  final duration = formatDuration(sessionDuration(session, now));
  return '${historyDateLabel(session.startedAt, now)} · $duration · ${trimNumber(totalVolumeKg(session))} kg';
}

class HistoryScreen extends ConsumerWidget {
  const HistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final historyAsync = ref.watch(sessionHistoryProvider);
    final now = ref.watch(nowProvider)();
    return Scaffold(
      key: const Key('history_screen'),
      appBar: AppBar(title: Text('workout.history.title'.tr())),
      body: historyAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stackTrace) => Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('workout.history.load_error'.tr()),
              TextButton(
                onPressed: () => ref.invalidate(sessionHistoryProvider),
                child: Text('workout.retry'.tr()),
              ),
            ],
          ),
        ),
        data: (sessions) => ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          children: [
            const WeeklySummaryCard(),
            SectionHeader('workout.history.sessions'.tr()),
            if (sessions.isEmpty)
              Text(
                'workout.history.empty'.tr(),
                key: const Key('history_empty'),
                style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
              )
            else
              for (final session in sessions) _HistoryTile(session: session, now: now),
          ],
        ),
      ),
    );
  }
}

class _HistoryTile extends StatelessWidget {
  const _HistoryTile({required this.session, required this.now});

  final WorkoutSession session;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Card(
        key: Key('history_${session.id}'),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => context.push('/workout/history/${session.id}'),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        session.workoutName,
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontFamily: AppFonts.heading,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        historyListSubtitle(session, now),
                        style: theme.textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
                      ),
                    ],
                  ),
                ),
                Icon(Icons.chevron_right, color: scheme.onSurfaceVariant),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
```

- [ ] **Step 6: Rewrite `history_detail_screen.dart`**

`lib/features/workout/presentation/history_detail_screen.dart` dosyasının tamamını şununla değiştir:

```dart
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_fonts.dart';
import '../../../shared/text_case.dart';
import '../../../shared/widgets/stat_box.dart';
import '../../progress/application/progress_providers.dart';
import '../application/session_providers.dart';
import '../domain/block_format.dart';
import '../domain/session_stats.dart';
import '../domain/workout_session.dart';
import 'history_screen.dart';

String _doneLabel(SessionSet set) =>
    set.weightKg == null ? '× ${set.reps}' : '${trimNumber(set.weightKg!)} kg × ${set.reps}';

class HistoryDetailScreen extends ConsumerWidget {
  const HistoryDetailScreen({super.key, required this.sessionId});

  final String sessionId;

  Future<void> _delete(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('workout.history.delete_title'.tr()),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text('workout.cancel'.tr()),
          ),
          TextButton(
            key: const Key('history_delete_confirm'),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text('workout.delete'.tr()),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await ref.read(sessionRepositoryProvider).deleteSession(sessionId);
      ref
        ..invalidate(sessionHistoryProvider)
        ..invalidate(recentSessionsProvider)
        ..invalidate(allSessionsProvider);
      if (context.mounted) context.pop();
    } catch (e, st) {
      debugPrint('HistoryDetailScreen.delete failed: $e\n$st');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('workout.action_error'.tr())));
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sessionAsync = ref.watch(sessionDetailProvider(sessionId));
    final now = ref.watch(nowProvider)();
    return Scaffold(
      key: const Key('history_detail_screen'),
      appBar: AppBar(
        title: Text(sessionAsync.value?.workoutName ?? ''),
        actions: [
          IconButton(
            key: const Key('history_delete_button'),
            icon: const Icon(Icons.delete_outline),
            onPressed: () => _delete(context, ref),
          ),
        ],
      ),
      body: sessionAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stackTrace) => Center(child: Text('workout.history.load_error'.tr())),
        data: (session) => _content(context, session, now),
      ),
    );
  }

  Widget _content(BuildContext context, WorkoutSession session, DateTime now) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final muted = theme.textTheme.bodyMedium?.copyWith(color: scheme.onSurfaceVariant);
    final meta = '${historyDateLabel(session.startedAt, now)} · ${session.programName}';
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(
          upperCaseFor(meta, Localizations.localeOf(context).languageCode),
          key: const Key('history_detail_meta'),
          style: theme.textTheme.labelMedium?.copyWith(color: scheme.onSurfaceVariant, letterSpacing: 1),
        ),
        const SizedBox(height: 12),
        StatBoxRow(
          children: [
            StatBox(
              key: const Key('history_detail_duration'),
              label: 'workout.session.stat_duration'.tr(),
              value: formatDuration(sessionDuration(session, now)),
            ),
            StatBox(
              key: const Key('history_detail_sets'),
              label: 'workout.session.stat_sets'.tr(),
              value: '${completedSetCount(session)}',
            ),
            StatBox(
              key: const Key('history_detail_volume'),
              label: 'workout.session.stat_volume'.tr(),
              value: '${trimNumber(totalVolumeKg(session))} kg',
            ),
          ],
        ),
        for (final sets in session.exerciseGroups)
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      sets.first.exerciseName,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontFamily: AppFonts.heading,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    for (final (index, set) in sets.indexed) ...[
                      if (index > 0) const Divider(height: 1),
                      Padding(
                        key: Key('history_set_${set.id}'),
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: Row(
                          children: [
                            SizedBox(width: 32, child: Text('${index + 1}', style: muted)),
                            Expanded(
                              child: Text(
                                set.isCompleted ? _doneLabel(set) : 'workout.history.not_done'.tr(),
                                style: set.isCompleted ? null : muted,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }
}
```

- [ ] **Step 7: Check for leftover `historySubtitle` usages**

Run: `grep -rn "historySubtitle" lib test`
Expected: çıktı yok.

- [ ] **Step 8: Run tests to verify they pass**

Run: `flutter test --no-pub test/features/progress/presentation/home_cards_test.dart test/features/workout/presentation/history_screen_test.dart test/features/progress/presentation/home_stat_grid_test.dart`
Expected: PASS (haftalık kart 4 test, geçmiş 4 test, ana sayfa kutuları).

Run: `flutter analyze --no-pub`
Expected: No issues found!

- [ ] **Step 9: Commit**

```bash
git add lib/features/progress/presentation/widgets/weekly_summary_card.dart lib/features/workout/presentation/history_screen.dart lib/features/workout/presentation/history_detail_screen.dart test/features/progress/presentation/home_cards_test.dart test/features/workout/presentation/history_screen_test.dart
git commit -m "feat(workout): move weekly summary into history and restyle history screens

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 7: Doğrulama, elle kontrol ve PLAN.md

**Files:**
- Modify: `PLAN.md` (sona tarihli satır)

- [ ] **Step 1: Static analysis**

Run: `flutter analyze --no-pub`
Expected: "No issues found!"

- [ ] **Step 2: Full test suite (user's terminal)**

Kullanıcıdan kendi terminalinde çalıştırmasını iste (bu makinede arka plan koşusu bellek yüzünden kesiliyor):

```
flutter test --no-pub -j 1
```

Expected: `All tests passed!`. Toplam test sayısını not et (R2 sonunda +379 idi; R3 net artışı yaklaşık +10).

- [ ] **Step 3: Release web build + manual check (user's terminal)**

Kullanıcıdan şunu iste: `flutter build web --release --no-pub`, ardından `build\web` klasöründen `python -m http.server 5555 --bind 127.0.0.1` ile sunması ve tarayıcıda önbelleği temizleyerek açması (yeni çeviriler). Elle kontrol listesi:

1. Antrenman oturumu: üstte gün adı + program adı, "Bitir" neon; süre / set x/y / hacim kutuları ve ilerleme çubuğu.
2. Set tablosu: SET / HEDEF / KG / TEK. başlıkları; ✓'ye basınca satır soluklaşır, sayaçlar ve çubuk ilerler.
3. Dinlenme şeridi neon, büyük geri sayım; +30 sn ve atla çalışıyor.
4. Bir hareketin bütün setleri bitince tek satıra katlanıyor ("✓ Bitti"); dokununca açılıyor, başlığa dokununca kapanıyor.
5. Bitir → özet: "Antrenman tamamlandı", üç kutu, 1RM kartları (dokununca onay kalkıyor), altta sabit Kaydet → ana sayfa.
6. Programlar: aktif program neon çerçeve + AKTİF; filtre çipleri seçilince neon; liste daralıyor.
7. Program detayı: ayrıntı satırı, "Aktif yap" tam genişlik, gün kartlarında Başlat; düzenleyici ve hareket seçici sorunsuz (çipler neon).
8. Geçmiş: üstte haftalık tablo (artışlar neon), altında "4 Ekim · süre · hacim" kartları; ana sayfadaki "Bu hafta" kutusu buraya geliyor.
9. Geçmiş detayı: "TARİH · PROGRAM" satırı, üç kutu, set satırları; silme çalışıyor.

- [ ] **Step 4: PLAN.md row and commit**

`PLAN.md` dosyasındaki tarihçe tablosunun son satırının altına, R2 satırının biçimiyle ekle (test sayısı ve elle kontrol sonucu Step 2–3'ten):

```
| <tarih> | **F5+ R3 (antrenman ekranları) tamamlandı** (`r3-antrenman` dalı, 7 görev). Antrenman oturumu: süre/set/hacim kutuları + ilerleme çubuğu, sütun başlıklı set tablosu, setleri biten hareket tek satıra katlanır (dokununca açılır), neon dinlenme şeridi. Özet: "Antrenman tamamlandı" başlığı, rakam kutuları, 1RM önerileri kart olarak, sabit Kaydet. Programlar: aktif program neon çerçeve + AKTİF etiketi, neon filtre çipleri; program detayında "Aktif yap" ana buton. Geçmiş: haftalık "bu hafta / geçen hafta" tablosu ana sayfadan buraya taşındı (antrenman/set/hacim artışı neon), oturum kartlarında tarih · süre · hacim (yıl yalnız farklıysa); geçmiş detayında tarih · program satırı ve rakam kutuları. Yeni ortak bileşenler: `StatBox`/`StatBoxRow`, `AccentChip`. Otomatik: <N> Flutter testi geçiyor (kullanıcının terminalinde `-j 1`), `flutter analyze` temiz. Manuel: <sonuç>. Sıradaki: R4 (ilerleme ekranları, antrenör, giriş/kayıt/onboarding). |
```

`<tarih>`, `<N>` ve `<sonuç>` yerine gerçek değerleri yaz.

```bash
git add PLAN.md
git commit -m "docs: record F5+ R3 verification

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

- [ ] **Step 5: Finish the branch**

superpowers:finishing-a-development-branch becerisiyle devam et (R1/R2'de: yerelde master'a fast-forward, dal silindi, kullanıcı onayıyla push).
