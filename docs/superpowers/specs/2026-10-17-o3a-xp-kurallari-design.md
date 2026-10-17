# O3a — XP Makullük Kuralları — Tasarım Spec'i

Tarih: 2026-10-17 · Dal: `o3a-xp-kurallari` · Migration: yok

## 1. Bağlam

Oyunlaştırma v2 yol haritası: N2 → **O3a XP makullük kuralları** (bu spec) → O4 seri + haftalık görevler → O2 karakter/canavar savaşı → O5 rozetler → O3b sunucu tarafı XP. XP her açılışta tüm geçmişten istemcide yeniden hesaplanıyor (`xpEvents`, O1 spec §3) ve `player_stats` / `period_stats` ile yayınlanıyor. O3a yalnız uygulamanın kendi verisindeki makul olmayan kullanımı keser; doğrudan API ile sahte veri yazmak O3b'nin konusu.

Bugünkü açıklar:
1. Tek setlik antrenmanı açıp bitirmek her seferinde 55 XP; günlük sınır yok.
2. 30 seti bir dakikada "tamamlandı" yapmak 150 XP.
3. Rekor sağma: 0,5 kg'lık artışlarla her antrenmanda +25 XP; 500 kg bench gibi değerler de rekor.

Öğün tarafında açık yok: uygulama öğünü her zaman şimdiki zamanla kaydediyor (`meal_capture_notifier.dart`), geçmiş güne öğün girilemiyor.

## 2. Kararlar (kullanıcıyla onaylı)

1. Kurallar **tüm geçmişe** uygulanır; mevcut XP, seviye ve XP'ye bağlı unvanlar düşebilir. Sunucuda kesinleşmiş meydan okuma sonuçları ve ödülleri değişmez.
2. Antrenman: en az 3 tamamlanmış set **ve** en az 10 dakika; günde en çok 2 antrenman XP getirir.
3. Set hızı: süreye göre tavan, her 2 dakikaya 1 set (en çok 30).
4. Rekor: en az %2,5 artış; hareket başına 7 günde 1; oturum başına en çok 3; abartılı değerler yok sayılır.
5. Abartılı değer eşiği tahmini 1RM **500 kg** (leg press gibi hareketlerde 350 kg gerçek kullanıcıyı keserdi).
6. Önceki en iyinin %50'sinden fazla sıçrama XP getirmez ama **yeni taban olur** (taban olmasaydı ilk gün boş barla 20 kg giren biri o harekette bir daha rekor alamazdı).
7. Aynı süzgeç meydan okumaların antrenman/set/hacim metriklerine ve dönem kas sıralamasına da uygulanır.
8. XP getirmeyen antrenman Seviye ekranındaki geçmişte **0 XP + kısa neden** ile görünür; Seviye ekranına "XP kuralları" açıklaması eklenir.
9. Yaklaşım A: kurallar tek bir saf modülde (`fair_play.dart`); XP, meydan okuma ve dönem hesabı aynı kararı kullanır.

## 3. Kurallar

### 3.1 Sabitler (`lib/features/gamification/domain/fair_play.dart`)

| Sabit | Değer | Anlamı |
|---|---|---|
| `minCountedSets` | 3 | Oturumun sayılması için en az tamamlanmış set |
| `minCountedDuration` | 10 dk | Oturumun sayılması için en kısa süre |
| `maxCountedWorkoutsPerDay` | 2 | Bir yerel günde XP getiren en çok oturum |
| `minutesPerCountedSet` | 2 | Süre tavanı: her 2 dakikaya 1 set |
| `maxCountedSets` | 30 | Mevcut sabit; `xp_rules.dart`'tan buraya taşınır |
| `maxPlausibleOneRepMaxKg` | 500 | Bunun üstündeki tahmini 1RM'li set yok sayılır |
| `minRecordGain` | 0,025 | Rekor için önceki en iyiye göre en az artış |
| `maxRecordJump` | 0,5 | Bundan büyük artış XP getirmez, yalnız taban olur |
| `recordCooldown` | 7 gün | Aynı hareketten rekor XP'leri arasındaki en kısa süre |
| `maxRecordsPerSession` | 3 | Bir oturumda XP getiren en çok rekor |

### 3.2 Oturum kararı

`List<SessionVerdict> judgeSessions(List<WorkoutSession> sessions)` — bitmiş (`finishedAt != null`) ve en az bir tamamlanmış seti olan oturumlar, bitiş zamanına göre eskiden yeniye.

```dart
enum SkipReason { tooSmall, dailyLimit }

class SessionVerdict {
  final WorkoutSession session;
  final SkipReason? skip;            // null → sayılır
  final List<SessionSet> countedSets; // sayılmıyorsa boş
  bool get counted => skip == null;
}
```

1. **Süre:** `finishedAt − startedAt` (negatifse 0).
2. **Abartılı set:** `estimateOneRepMax` sonucu 500 kg'ı geçen set *makul değil*. Makul olmayan set hiçbir yerde sayılmaz (set sayısı, hacim, kas, rekor); `estimateOneRepMax` null dönen set (kilosuz ya da çok tekrarlı) makul sayılır.
3. **Uygunluk:** makul tamamlanmış set sayısı ≥ 3 ve süre ≥ 10 dk; değilse `skip = tooSmall`.
4. **Günlük sınır:** uygun oturumlar `finishedAt`'ın yerel gününe göre gruplanır; her günün bitiş sırasına göre ilk 2'si sayılır, sonrakiler `skip = dailyLimit`. `tooSmall` oturumlar sınırı tüketmez.
5. **Sayılan setler:** sayılan oturumda makul tamamlanmış setler tamamlanma sırasına göre (`completedAt`, eşitlikte mevcut sıra) dizilir; ilk `N = min(set sayısı, 30, süre dakikası ~/ 2)` set sayılır.

### 3.3 XP olayları (`xpEvents`)

- **Antrenman:** her kararda bir olay. Sayılan → `xp = 50 + countedSets.length × 5`, `sets = countedSets.length`. Sayılmayan → `xp = 0`, `sets = 0`, `skip = verdict.skip`. `XpEvent`'e `final SkipReason? skip` alanı eklenir.
- **Rekor:** oturumlar eskiden yeniye işlenir; her harekette taban (`bestSoFar`) tutulur.
  1. Oturumdaki her hareketin en iyi makul seti (en yüksek tahmini 1RM) bulunur; tüm kararlardaki oturumlar (sayılmayanlar dahil) tabanı günceller.
  2. Taban yoksa: değer taban olur, XP yok (mevcut davranış).
  3. Artış oranı `r = tahmin / taban − 1`. `r < 0,025` → XP yok; `r > 0` ise taban yine güncellenir (küçük artışlar birikip sonradan rekor sayılmaz).
  4. `r > 0,5` → taban olur, XP yok.
  5. `0,025 ≤ r ≤ 0,5` → **aday**; taban olur. Aday XP alır, eğer oturum sayılıyorsa ve aynı hareketin son rekor XP'sinden bu yana 7 gün (`date − son ≥ 7 gün`) geçtiyse.
  6. Bir oturumda XP alabilen adaylar `r`'ye göre büyükten küçüğe sıralanır; ilk 3'ü 25 XP'lik rekor olayı olur. Seçilmeyen adayın soğuma süresi başlamaz.
- **Öğün:** değişmez.
- **Döküm (`xpBreakdown`):** antrenman tabanı yalnız `xp > 0` olaylarda eklenir.

### 3.4 Meydan okuma ve dönem

- `challengeValue` (XP dışı metrikler): yalnız `counted` kararların `countedSets`'i. `workouts` → pencerede sayılan oturum sayısı; `sets` ve `volume` → `countedSets` üzerinden (kas ağırlığıyla, mevcut gibi).
- `buildPeriodStats` kas toplamları: aynı şekilde `countedSets`.
- XP metrikleri zaten `xpEvents`'i kullandığı için kendiliğinden uyar.
- Değişmeyenler: arkadaşlara açık haftalık özet (`WeeklyStats`) ve son antrenmanlar listesindeki set sayıları ham kalır (yarışmalı değil). Son antrenmanlardaki rekorlar `xpEvents`'ten geldiği için artık yalnız XP getiren rekorları gösterir; kabul edildi.

## 4. Arayüz

- Seviye ekranı XP geçmişi: `xp == 0` olan antrenman satırının alt yazısı nedeni söyler:
  - `tooSmall` → "En az 3 set ve 10 dakika gerekir" / "Needs at least 3 sets and 10 minutes"
  - `dailyLimit` → "Günlük 2 antrenman sınırı" / "Daily limit of 2 workouts"
  - Kazanç rozeti "+0 XP" yerine sönük "0 XP" gösterir.
- Seviye ekranının döküm kartı başlığının yanına bilgi düğmesi (`level_rules_button`) → bottom sheet (`level_rules_sheet`): XP kaynakları ve kurallar maddeler hâlinde (antrenman 50 + set başına 5; en az 3 set/10 dk; günde 2; her 2 dakikaya 1 set, en çok 30; rekor 25, en az %2,5 artış, hareket başına haftada 1, antrenman başına 3; öğün günü 10; meydan okuma ödülleri).
- Çeviriler `gamification` bölümüne, tr ve en.

## 5. Hata durumları

- `startedAt` `finishedAt`'tan sonraysa süre 0 → `tooSmall`.
- `completedAt` null olan tamamlanmış set yoksa da sıralama kararlı kalır (eşitlikte `exercisePosition`, `setIndex`).
- Saat dilimi: günlük sınır ve soğuma yerel zamanla (mevcut olay tarihleriyle aynı).

## 6. Test

- `test/features/gamification/domain/fair_play_test.dart`: 2 set / 9 dk → `tooSmall`; 3 set 10 dk → sayılır; aynı gün 3 uygun oturum → üçüncüsü `dailyLimit`; `tooSmall` sınırı tüketmez; 20 set 24 dk → 12 sayılan set; 40 set 120 dk → 30; 600 kg set sayılmaz ve uygunluğa girmez; ters süre → `tooSmall`.
- `xp_rules_test.dart` güncellenir: sayılmayan oturum 0 XP + `skip`; %2 artış rekor değil ama taban yükselir; %60 sıçrama XP yok, sonraki %3 artış yeni tabana göre; aynı hareket 5 gün sonra tekrar rekor → XP yok, 7 gün sonra var; bir oturumda 4 aday → en büyük 3'ü; sayılmayan oturumdaki rekor XP getirmez ama tabanı yükseltir; döküm sayılmayanı eklemez. Mevcut testlerdeki oturumlar yeni şartlara (≥3 set, ≥10 dk) göre düzenlenir.
- `challenge_progress_test.dart` ve `period_stats_test.dart`: sayılmayan oturum ve süre tavanını aşan setler sayılmaz.
- `level_screen_test.dart`: 0 XP satırı neden metnini gösterir; bilgi düğmesi kurallar sayfasını açar.
- Elle kontrol (web release): kısa bir antrenman 0 XP + neden; kurallar sayfası; toplam XP'nin yeniden hesaplandığı.
