# O2a — Canavar Savaşı Çekirdeği — Tasarım Spec'i

Tarih: 2026-10-18 · Dal: `o2-savas` · Migration: yok

## 1. Bağlam

Oyunlaştırma v2 yol haritası: N2 → O3a → O4 → **O2 karakter/canavar savaşı** → O5 rozetler → O3b sunucu tarafı XP. O2 ikiye bölündü: **O2a** (bu spec) savaş çekirdeği — canavarlar, statlar, hasar, rütbe kapısı, ana sayfa kartı ve savaş ekranı, vektör yer tutucularla; **O2b** hazır karakterler (profil avatarı), vuruş animasyonu, yenme kutlaması ve AI görselleri. XP her açılışta tüm geçmişten istemcide yeniden hesaplanıyor (`xpEvents`); O3a'nın kararları (`judgeSessions`) neyin sayıldığını, O4'ün haftalık hedefi (`GameSettings.weeklyGoal`) seriyi belirliyor. Rütbe bugün yalnız seviyeden geliyor (`rankFor(level)`, `player_summary.dart`) ve arkadaşlar, topluluk ve dönem sıralaması bu `summary.rank`'ı kullanıyor.

## 2. Kararlar (kullanıcıyla onaylı)

1. **Rütbe canavarı**: her rütbe geçişini bir bekçi canavar korur; rütbe için hem seviye eşiği hem bekçiyi yenmek gerekir. Bir sonraki bekçi her zaman aktiftir.
2. **Hasar kaynağı**: tüm XP (antrenman, rekor, öğün, meydan okuma, görev); stat bonusu hepsine, kritik yalnız antrenmana.
3. **Eski rütbeler korunmaz**: tüm geçmiş savaşla yeniden oynanır; rütbe düşebilir.
4. **Kapsam**: O2a savaş çekirdeği; karakter/avatar/animasyon/görseller O2b.
5. **Yaklaşım A**: saf modüller, istemcide belirlenimli yeniden oynatma; sunucu ve tablo yok.
6. **Mola**: 7 gün boşta kalınca canavar yavaşça iyileşir; XP ve seviye asla düşmez.
7. **Statlar**: Güç, Dayanıklılık, İstikrar, 1–100; toplam en çok +%50 hasar.

## 3. Canavarlar (`lib/features/gamification/domain/monsters.dart`)

### 3.1 Liste

16 sabit canavar. Index `i` (0…14) `Rank.values[i + 1]` rütbesinin bekçisidir; index 15 Ölümsüz rütbesindeki **sonsuz boss**tur. Aşama (`tier`) bekçisi olduğu rütbenin `tier`'ı; sonsuz boss 4. Her canavarın 2 zayıf kası var; 16 kas grubunun (boyun hariç) her biri tam iki kez geçer.

| # | id | Ad (tr) | Ad (en) | Bekçisi | Zayıf kaslar |
|---|---|---|---|---|---|
| 0 | `mud_goblin` | Çamur Goblini | Mud Goblin | Acemi | chest, quadriceps |
| 1 | `rat_king` | Mahzen Sıçanı Kralı | Cellar Rat King | Amatör | lats, hamstrings |
| 2 | `skeleton_guard` | İskelet Muhafız | Skeleton Guard | Hevesli | shoulders, glutes |
| 3 | `shadow_wolf` | Gölge Kurt | Shadow Wolf | Sporcu | biceps, calves |
| 4 | `orc_warrior` | Ork Savaşçı | Orc Warrior | Azimli | triceps, abdominals |
| 5 | `stone_golem` | Taş Golem | Stone Golem | Kararlı | middle back, adductors |
| 6 | `bridge_troll` | Köprü Trolü | Bridge Troll | Savaşçı | traps, abductors |
| 7 | `minotaur` | Minotor | Minotaur | Gladyatör | lower back, forearms |
| 8 | `ash_wraith` | Kül Hayaleti | Ash Wraith | Demir | chest, hamstrings |
| 9 | `basilisk` | Bazilisk | Basilisk | Usta | quadriceps, lats |
| 10 | `cyclops` | Tepegöz | Cyclops | Elit | shoulders, calves |
| 11 | `hydra` | Hidra | Hydra | Şampiyon | glutes, biceps |
| 12 | `lich` | Kara Büyücü | Lich | Titan | abdominals, middle back |
| 13 | `behemoth` | Behemot | Behemoth | Efsane | triceps, adductors |
| 14 | `crimson_dragon` | Kızıl Ejder | Crimson Dragon | Ölümsüz | traps, lower back |
| 15 | `ancient_titan` | Kadim Titan | Ancient Titan | (sonsuz) | forearms, abductors |

Rütbe adları uygulamadaki `gamification.rank.*` çevirileridir; tablo yalnız eşlemeyi gösterir. Canavar adları `gamification.battle.monster.<id>` anahtarlarında.

### 3.2 Can

`int monsterHp(int index)`: bekçi `i` için `span = Σ xpForNext(l)`, `l` = `Rank.values[i].minLevel` … `Rank.values[i + 1].minLevel − 1`; sonsuz boss (index ≥ 15) için `l` = 100…109. `hp = round(span × 1,2 / 10) × 10`.

| index | 0 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 10 | 11 | 12 | 13 | 14 | 15+ |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| can | 660 | 1500 | 2250 | 3000 | 3750 | 4500 | 5250 | 6000 | 6750 | 7500 | 17250 | 20250 | 23250 | 26250 | 29250 | 32250 |

`Monster monsterAt(int index)`: index ≥ 15 her zaman sonsuz boss.

## 4. Statlar (`lib/features/gamification/domain/battle_stats.dart`)

Girdi `StatInputs`: `verdicts` (`judgeSessions`), `bodyWeightKg` (nullable), `weeklyGoal`. Yalnız `counted` kararlar ve onların `countedSets`'i kullanılır. `BattleStats statsOn(DateTime day, StatInputs)` — `day` yerel gün; o günün sonuna kadar biten oturumlar dahil.

- **Güç**: `[day − 89, day]` gün aralığında her hareketin (`exerciseId`) en yüksek tahmini 1RM'si (`estimateOneRepMax`); en yüksek 3 hareketin toplamı / `bodyWeightKg`. `puan = clamp(round(oran / 4,5 × 100), 1, 100)`. Kilo null ya da ≤ 0, ya da 1RM'li set yoksa 1.
- **Dayanıklılık**: `[day − 27, day]` aralığındaki sayılan set sayısı `n`; `puan = clamp(round(n / 3), 1, 100)`.
- **İstikrar**: `day`'in ISO haftasından önceki 8 tamamlanmış ISO hafta; sayılan antrenman yapılan farklı gün sayısı ≥ `weeklyGoal` olan her hafta 12,5 puan; `puan = clamp(round(h × 12,5), 1, 100)`.
- **Bonus**: `(güç + dayanıklılık + istikrar) / 600` (0,005…0,5).

Sonuç gün başına önbelleğe alınır (aynı gün birden çok olay).

## 5. Savaş (`lib/features/gamification/domain/battle.dart`)

`BattleState battle(List<XpEvent> events, StatInputs inputs, {required DateTime today})`; `events` eskiden yeniye sıralı (`compareXpEvents`), meydan okuma ödülleri dahil.

### 5.1 Durum

`index` (aktif canavar; 0'dan başlar), `damage` (aktif canavara verilen, tam sayı), `lastWorkoutDay` (son sayılan antrenmanın yerel günü, başta null).

### 5.2 İyileşme

Her olaydan önce ve sonda `today` için: `lastWorkoutDay` null değilse, `lastWorkoutDay + 8`'den başlayarak hedef güne kadar (hedef gün dahil) henüz işlenmemiş her gün `damage = max(0, damage − round(monsterHp(index) × 0,03))`. Bir sayılan antrenman `lastWorkoutDay`'i günceller (iyileşme o olaydan önce uygulanır). Yenilmiş canavarlar geri gelmez; toplam iyileşen can `healed`'e eklenir.

### 5.3 Hasar

`xp ≤ 0` olan olay atlanır. Diğerleri için `bonus = statsOn(localDay(e.date)).bonus`:

- Antrenman: `muscleSets` (sayılan setlerin ana kasa göre sayısı; set birden çok ana kas taşıyorsa ilki) içinden aktif canavarın zayıf kaslarına düşen set sayısı `w`, toplam `n = e.sets`; `pay = n == 0 ? 0 : w / n`.
- Diğer kaynaklar: `pay = 0`.
- `hasar = round(e.xp × (1 + bonus) × (1 + 0,5 × pay))`.

### 5.4 Taşma

`damage += hasar`; `damage ≥ monsterHp(index)` olduğu sürece `damage −= monsterHp(index)`, `index++` (aynı olay birden çok canavarı yenebilir; kritik payı ilk canavarın zayıf kaslarına göre hesaplanmıştır).

### 5.5 Sonuç

`BattleState`: `guardiansBeaten = min(index, 15)`, `bossKills = max(0, index − 15)`, `monster = monsterAt(index)`, `hp = monsterHp(index)`, `damage`, `stats = statsOn(today)`, `recent` (son 10 `BattleHit`: tarih, kaynak, XP, hasar, kritik payı, yenilen canavar index'leri), `healed`, `healing` (bugün iyileşme sürüyor mu: `lastWorkoutDay != null && today − lastWorkoutDay ≥ 8 gün`).

### 5.6 Rütbe

`rank = Rank.values[min(rankFor(level).index, battle.guardiansBeaten)]`. `PlayerSummary.rank` bu değeri alır; `settings` null ise savaş yok ve rütbe `rankFor(level)`.

## 6. Mimari ve veri akışı

- `XpEvent.muscleSets` (`Map<String, int>`, varsayılan boş): `xpEvents` sayılan antrenmanlarda `exercisesById`'deki `primaryMuscles.first` ile doldurur; kas bilgisi olmayan setler haritaya girmez ama `sets`'e girer.
- `GameSettings.bodyWeightKg` (nullable): `gameSettingsProvider` profilden doldurur.
- `PlayerSummary.battle` (`BattleState?`) ve yeni rütbe kuralı; `playerSummary` sıralı tüm olaylardan (`all`) ve `judgeSessions(sessions)`'dan hesaplar.
- `buildPlayerStats`, dönem istatistiği ve topluluk `summary.rank`'ı kullandığından yeni rütbe paylaşılır; savaş ayrıntısı paylaşılmaz.
- Performans: statlar yalnız olay olan günlerde ve gün başına bir kez hesaplanır; pencereler sıralı karar listesinde taranır.

## 7. Arayüz

- **Ana sayfa savaş kartı** (`home_battle_card`, `HomeScreen`'de `_HomeHeader`'ın altında, beslenme kartının üstünde): solda vektör canavar (aşama rengi + canavar simgesi + baş harf), sağda ad, "Bekçi: {rütbe}" (sonsuz boss: "Sonsuz boss · ×{n}"), can çubuğu "{kalan} / {tam}", iki zayıf kas çipi; altta son vuruş "{gün} −{hasar}" ve kritik payı > 0 ise "· %{pay} kritik"; vuruş yoksa "Antrenmanla saldır"; `healing` ise "İyileşiyor +%3/gün". Yüklenirken/hatada görünmez; dokununca `/home/battle`.
- **Savaş ekranı** (`/home/battle`, `battle_screen`):
  1. Canavar başlığı: büyük vektör, ad, can çubuğu, zayıf kaslar.
  2. Rütbe kapısı: bekçi yenilmediyse "Yenersen → {rütbe}" ve seviye eşiği yetmiyorsa "(seviye {n}'de açılır)"; bekçi önden yenildiyse (`guardiansBeaten > rankFor(level).index`) "Seviye {n}'e ulaşınca {rütbe} olursun".
  3. Statlar kartı: üç çubuk (1–100) + kısa açıklama, "Hasar bonusu +%{b}".
  4. Son vuruşlar: kaynak simgesi, "{xp} XP → {hasar}", kritik payı, yenilenler için "Yenildi" satırı.
  5. Canavar yolu: 16 satır; yenilen (soluk + tik), aktif (vurgulu), kilitli; sonsuz boss "×{n} yenildi".
  6. AppBar bilgi düğmesi → mevcut XP kuralları sayfası; oraya savaş bölümü eklenir (can, hasar, kritik, mola, rütbe kapısı).
- **Seviye ekranı**: rütbe merdiveninde seviye eşiği tutup bekçisi yenilmemiş rütbede "Bekçiyi yen" etiketi.
- Ekran düzeni kodlamadan önce Stitch'te taslaklanıp kullanıcıya gösterilir.
- Çeviriler `gamification.battle` altında, tr ve en.

## 8. Hata durumları

- Kilo yok / profil yüklenemedi → Güç 1.
- Kas bilgisi olmayan hareket → kritik payına girmez, normal hasar.
- Hiç olay yok → canavar 0 tam canla, "Antrenmanla saldır".
- Ölümsüz → sonsuz boss döngüsü; rütbe Ölümsüz'de kalır.
- Tüm hasar ve iyileşme tam sayı; aynı girdi aynı sonucu verir.
- `settings` null → savaş yok, eski rütbe kuralı.
- Kart yüklenemezse gizli; ekranda mevcut hata metni.

## 9. Test

- `monsters_test.dart`: 16 canavar, benzersiz id; zayıf kaslar `muscleGroups`'ta ve her biri iki kez; can tablosu (§3.2) ve index > 15.
- `battle_stats_test.dart`: Güç oranı, 90 gün sınırı, kilo yokken 1, en iyi 3 farklı hareket; Dayanıklılık 28 gün sınırı ve tavan; İstikrar 8 hafta, içinde bulunulan hafta sayılmaz; bonus ve %50 tavan; sayılmayan oturum katkı vermez.
- `battle_test.dart`: hasar ve kritik payı; taşma ve tek olayda çoklu yenme; iyileşme 8. günde başlar, 0'da durur, yenilen canavara dokunmaz, `today`'e kadar sürer; sonsuz boss sayacı; `xp = 0` olay atlanır; son 10 vuruş; belirlenimlilik.
- `xp_rules_test.dart`: `muscleSets` doldurulur; kas bilgisi yoksa boş.
- `player_summary_test.dart`: rütbe = min(seviye rütbesi, yenilen bekçi); `settings` null iken `rankFor(level)`.
- Widget: ana sayfa kartı (normal, vuruş yok, iyileşiyor, yükleniyor gizli); savaş ekranı (iki kapı metni, statlar, son vuruşlar, canavar yolu); seviye ekranında "Bekçiyi yen".
- Rütbe beklentisi değişen mevcut testler güncellenir.
- Elle (web release): kart, savaş ekranı, antrenman sonrası can düşüşü, İngilizce, 360 px.
