# S3 — Meydan Okumalar — Tasarım Spec'i

Tarih: 2026-10-10 · Dal: `s3-meydan-okumalar` · Migration: `0015_social_challenges.sql`

## 1. Bağlam

Oyunlaştırma fazları: O1 kişisel (`a4d8129`) → S1 arkadaşlık (`23a9e75`, migration `0013`) → S2 topluluklar (`bc42e65`, migration `0014`) → **S3 meydan okumalar**. S3, arkadaşlara davetle ya da topluluk içinde süreli meydan okuma açmayı, canlı sıralamayı/ilerlemeyi, kesin sonucu ve XP + unvan ödülünü getirir. S1/S2'deki yaklaşım A korunur: sayıları istemci geçmişten hesaplayıp yayınlar, diğerleri RLS ile okur.

## 2. Kararlar (kullanıcıyla onaylı)

1. **Kapsam:** arkadaş meydan okuması (1–9 arkadaş davet edilir, kabul edenler katılır) ve topluluk meydan okuması (her üye açabilir, üyeler "Katıl" der).
2. **Tür:** yarış (süre sonunda en yüksek değer kazanır) ya da hedef (hedefe ulaşan herkes başarır); oluştururken seçilir.
3. **Ölçü:** antrenman sayısı, set, XP, hacim (kg). Set ve hacimde isteğe bağlı tek kas filtresi (17 kas, S2 ile aynı; ağırlıklı).
4. **Süre:** 3 / 7 / 14 / 30 gün; başlangıç "Hemen" ya da "Yarın 00:00".
5. **Ödül:** yarış birincisi +100 XP, hedefi tutturan +50 XP; "Meydan okuyucu" unvanı (1 / 5 / 15 başarı).
6. **Yaklaşım A:** istemci her aktif katılımı için değerini hesaplar ve değişince `challenge_participants.progress`'e yazar; bitişten 24 saat sonra yazma kapanır, sonuç kesinleşir. Kazanan sunucuda saklanmaz; istemci kesin değerlerden hesaplar.
7. **Limitler:** kişi başı en çok 5 aktif ya da başlamamış katılım; toplulukta aynı anda en çok 3 aktif ya da başlamamış meydan okuma.

## 3. Kurallar

### 3.1 Pencere

- "Hemen": `starts_at = now`, `ends_at = now + N gün`.
- "Yarın 00:00": `starts_at` = yerel yarın 00:00, `ends_at` = `starts_at`'tan N takvim günü sonra yerel 00:00.
- Sunucu denetimi: `ends_at - starts_at` 3/7/14/30 günün ±2 saat içinde (yaz saati); `starts_at` `now() - 5 dk` ile `now() + 48 sa` arasında.
- Durumlar (`challengeState(now)`): `upcoming` (now < starts_at), `active` (starts_at ≤ now < ends_at), `finalizing` (ends_at ≤ now < ends_at + 24 sa), `finished`.

### 3.2 Değer (`challengeValue`)

Pencere `[starts_at, ends_at)`; yalnız `finishedAt` pencerede olan oturumlar, yalnız tamamlanmış setler.

- `workouts`: en az bir tamamlanmış seti olan oturum sayısı.
- `sets`: tamamlanmış set sayısı (O1'deki 30 set sınırı yok). Kas filtresinde `muscleWeight(exercise, muscle)` toplamı (ana 1, yardımcı 0,5 — `period_stats` ile aynı).
- `volume`: `weightKg × reps` toplamı (kilosuz set 0). Kas filtresinde aynı ağırlıkla çarpılır. Tamsayıya yuvarlanır.
- `xp`: `xpEvents` içinde tarihi pencerede olan olayların XP toplamı; **meydan okuma ödülleri hariç** (döngü yok). Öğün günü olayı gün başı tarihlidir; gün başı pencerede değilse sayılmaz.
- Değer `double`, gösterimde set için bir ondalık (18,5), diğerleri tamsayı.

### 3.3 Sonuç ve ödül

- Sıralama: `joined` katılımcılar değere göre azalan; eşitlikte aynı sıra numarası, sonra ada göre.
- **Yarış:** kesinleşince en yüksek değer(ler) kazanır; değer 0 ise kazanan yok; `joined` katılımcı 2'den azsa ödül yok. Birinci(ler)e +100 XP.
- **Hedef:** `value >= target` olan her `joined` katılımcı başarır; +50 XP. Tek kişilik hedef de ödül alır.
- Ödül `XpEvent(source: XpSource.challenge, date: ends_at + 24 sa (yerel), xp, label: ad)`.
- Değerlendirme yalnız `finished` durumunda; `finalizing` sırasında "Kesinleşiyor" gösterilir.
- "Meydan okuyucu" unvanı: kazanılan meydan okuma sayısı (yarış birinciliği + hedef başarısı); kademeler 1 / 5 / 15.

### 3.4 Otomatik ad

Ad boşsa: `{N} günde en çok {ölçü}` (yarış) ya da `{N} günde {hedef} {ölçü}` (hedef); kas varsa ölçüye eklenir ("sırt seti", "göğüs hacmi"). Ad oluşturma anında dile göre üretilip `name`'e yazılır (en çok 60 karakter).

## 4. Veritabanı (`supabase/migrations/0015_social_challenges.sql`)

### 4.1 `challenges`

| Sütun | Tür |
|---|---|
| `id` | uuid pk default `gen_random_uuid()` |
| `creator` | uuid → `auth.users` on delete cascade |
| `community_id` | uuid null → `communities` on delete cascade (null = arkadaş meydan okuması) |
| `name` | text, 1–60 karakter |
| `kind` | text check in (`race`, `goal`) |
| `metric` | text check in (`workouts`, `sets`, `xp`, `volume`) |
| `muscle` | text null; yalnız `sets`/`volume` ile |
| `target` | numeric null; `goal`'da zorunlu (> 0), `race`'te null |
| `starts_at`, `ends_at` | timestamptz |
| `created_at` | timestamptz default now() |

### 4.2 `challenge_participants`

| Sütun | Tür |
|---|---|
| `challenge_id` | uuid → `challenges` on delete cascade |
| `user_id` | uuid → `auth.users` on delete cascade |
| `status` | text check in (`invited`, `joined`, `declined`) |
| `progress` | numeric not null default 0 |
| `updated_at` | timestamptz default now() |
| pk | (`challenge_id`, `user_id`) |

### 4.3 Yardımcılar

- `can_see_challenge(p_id)` (security definer, stable): katılımcı satırım varsa (her durum) ya da topluluk meydan okumasıysa ve `is_member(community_id)`.
- `shares_challenge(p_user)`: ikimizin de `declined` olmayan satırı olan ortak bir meydan okuma var mı.
- `public_profiles` select politikasına `or shares_challenge(user_id)` eklenir (`drop policy if exists` + yeniden oluştur; mevcut koşullar korunur).

### 4.4 RLS

- `challenges` select: `can_see_challenge(id)`. Insert/update/delete politikası yok.
- `challenge_participants` select: `can_see_challenge(challenge_id)`. Yazma politikası yok.

### 4.5 Fonksiyonlar (security definer, `search_path = public`, `authenticated`'a izin, `anon`/`public`'ten alınır)

| Fonksiyon | İş |
|---|---|
| `create_challenge(p_name, p_kind, p_metric, p_muscle, p_target, p_starts_at, p_ends_at, p_community_id, p_invitees uuid[]) returns uuid` | Alanları ve pencereyi denetler; arkadaşta `p_invitees` 1–9 kişi ve hepsi kabul edilmiş arkadaş; toplulukta üyelik + 3 sınırı, `p_invitees` boş olmalı; kişisel 5 sınırı. Açan `joined`, davetliler `invited`. |
| `respond_challenge(p_id, p_accept bool)` | Yalnız `invited` satırım; kabulde `ends_at > now()` ve 5 sınırı → `joined`; retde `declined`. |
| `join_challenge(p_id)` | Topluluk meydan okuması, üyeyim, `ends_at > now()`, 5 sınırı; satır yoksa `joined` ekler, `declined` ise `joined` yapar. |
| `leave_challenge(p_id)` | `ends_at > now()`; satırımı siler. Açan ayrılırsa meydan okuma kalır. Kimse `joined` kalmazsa meydan okuma silinir. |
| `delete_challenge(p_id)` | Açan, kendisinden başka `joined` yokken; ya da topluluk sahibi her zaman. |
| `publish_challenge_progress(p_id, p_value numeric)` | Yalnız `joined` satırım, `now() < ends_at + interval '24 hours'`, `p_value >= 0`; `progress`, `updated_at` günceller. |

"5 sınırı": kullanıcının `joined` satırı olan ve `ends_at > now()` meydan okuma sayısı < 5. "Topluluk 3 sınırı": topluluktaki `ends_at > now()` meydan okuma sayısı < 3.

Hata kodları (`raise exception '<kod>'`): `challenge_limit`, `community_challenge_limit`, `not_friend`, `not_member`, `challenge_closed`, `invalid_challenge`, `not_allowed`.

### 4.6 RLS kontrolleri (`supabase/migrations/checks/s3_rls_checks.sql`)

S2'deki gibi A/B/C hesaplarıyla tek DO bloğu, sonunda `SONUC:` satırı. Denetlenecekler: A arkadaşı B'yi davet eder, C (arkadaş değil) davet edilemez (`not_friend`); B meydan okumayı görür, C görmez; B kabul eder; B'nin yayını yazılır, A'nınkini yazamaz; B, A'nın profilini `shares_challenge` ile görür; topluluk meydan okumasını üye görür, üye olmayan görmez ve katılamaz (`not_member`); topluluk 3 sınırı; kişisel 5 sınırı; `ends_at + 24 sa` sonrası yayın `challenge_closed`; açan, katılımcı varken silemez, topluluk sahibi siler; son katılımcı ayrılınca meydan okuma silinir. Plan beklenen `SONUC` satırını verir.

## 5. Domain (`lib/features/social/domain/`)

- `challenge.dart`: `ChallengeKind { race, goal }`, `ChallengeMetric { workouts, sets, xp, volume }`, `ChallengeStatus { invited, joined, declined }`, `ChallengeState { upcoming, active, finalizing, finished }`; `Challenge` (alanlar §4.1, `fromJson`, `state(now)`), `ChallengeParticipant` (userId, status, progress, updatedAt), `ChallengeException` + `challengeErrorCodes`; sabitler `challengeDurations = [3, 7, 14, 30]`, `maxChallengeInvitees = 9`, `maxActiveChallenges = 5`, `maxCommunityChallenges = 3`, `challengeGrace = Duration(hours: 24)`, `xpPerRaceWin = 100`, `xpPerGoal = 50`.
- `challenge_progress.dart`: `challengeWindow(start: now|tomorrow, days, now)` → (startsAt, endsAt); `challengeValue(Challenge, List<WorkoutSession>, List<XpEvent>, Map<String, Exercise>)` (§3.2).
- `challenge_results.dart`: `ChallengeStanding` (userId, position, value, reachedGoal); `challengeStandings(challenge, participants)`; `challengeWinners(challenge, participants)` (§3.3; kesinleşmemişse boş); `challengeRewards(myId, List<(Challenge, List<ChallengeParticipant>)>)` → `List<XpEvent>`; `challengeAutoName(...)` (çeviri anahtarlarıyla).
- `xp_rules.dart`: `XpSource.challenge`; `XpBreakdown.challenges`.
- `titles.dart`: `TitleKind.challenge` (subjectId `wins`), eşikler 1 / 5 / 15; `titleProgress` kazanım sayısını parametre olarak alır.
- `player_summary.dart`: `buildPlayerSummary` ödül olaylarını alır ve XP'ye/son kazanımlara ekler.

## 6. Veri ve sağlayıcılar

- `SocialRepository`: `fetchMyChallengeIds()` (davetler dahil, `declined` hariç), `fetchCommunityChallengeIds(communityId)`, `fetchChallenges(ids)`, `fetchParticipants(ids)` (meydan okuma → katılımcılar), `createChallenge(...)`, `respondChallenge(id, accept)`, `joinChallenge(id)`, `leaveChallenge(id)`, `deleteChallenge(id)`, `publishChallengeProgress(id, value)`; hata eşleyici `_challenge` → `ChallengeException`.
- `challenge_providers.dart`:
  - `myChallengesProvider` → `MyChallenges { invites, active, upcoming, finished (son 10) }`; her öğe `ChallengeEntry` (challenge, katılımcılar, benim değerim — kendi değerim yerelden canlı).
  - `communityChallengesProvider(communityId)` → aktif + başlamamış.
  - `challengeDetailProvider(id)` → `ChallengeDetail` (challenge, katılımcılar, profiller, myId; görünmüyorsa null).
  - `challengeRewardsProvider` → bitmiş ve `joined` olduğum meydan okumalardan ödül olayları; `playerSummaryProvider` bunu izler.
  - `challengeSyncProvider`: AppShell izler; oturumlar/öğün zamanları değişince `active`/`finalizing` ve `joined` katılımlarımın değerini hesaplar, `lastPublishedChallengeValuesProvider` ile karşılaştırıp yalnız değişeni yayınlar; hata sessizce loglanır.
  - `pendingChallengeInvitesProvider` → davet sayısı (Sosyal rozetine eklenir).
  - `ChallengeActions`: create, respond, join, leave, delete; her biri ilgili sağlayıcıları yeniler.

## 7. Arayüz

### 7.1 Sosyal sekmeleri

Arkadaşlar / Topluluklar / **Meydan okumalar** / Genel; `TabBar(isScrollable: true)` (360 px'e sığmayınca kayar). Meydan okumalar sekmesinde davet sayısı rozeti; alt menü Sosyal rozeti = gelen istekler + davetler.

### 7.2 Meydan okumalar sekmesi (`ChallengesTab`) — Stitch taslağı `.superpowers/brainstorm/s3-stitch/challenges_tab.png`

- **DAVETLER** (varsa): kart — açanın avatarı + adı, "{ad} seni meydan okumaya davet etti", çipler (tür · ölçü · kas · süre), "Kabul" (dolu) / "Reddet" (çerçeveli).
- **AKTİF (n)**: kart — tür hapı, topluluk etiketi (varsa), kalan süre; ad; yarışta "MEVCUT SIRA 2. / 4" + değerim, altında "Lider: {ad} ({değer})" ve fark, ilerleme çubuğu (değerim / lider); hedefte "3/4" + yüzde + çubuk. Kesinleşiyorsa kalan süre yerine "Kesinleşiyor".
- **BAŞLAMADI**: kompakt satır — ad, başlangıç ("yarın 00:00" / tarih).
- **BİTEN**: son 10 — kazandıysam kupa + "Kazandın · +100 XP" (hedefte "Başardın · +50 XP"), değilse "{n}. oldun" / "Hedefe ulaşamadın".
- Boşsa açıklama metni.
- FAB "Yeni meydan okuma" → oluşturma alt sayfası (arkadaş kipi). Arkadaşım yoksa FAB yerine "Önce arkadaş ekle" metni.

### 7.3 Oluşturma alt sayfası (`CreateChallengeSheet`) — Stitch taslağı `create_sheet.png`

Segment Yarış / Hedef + açıklama satırı; ÖLÇÜ çipleri (`Wrap`; taslakta "Antrenman" taşıyor); set/hacimde "Kas" açılır listesi (Tümü + 17 kas); hedefte sayı alanı (birimle); SÜRE çipleri; BAŞLANGIÇ (Hemen / Yarın 00:00); AD (isteğe bağlı, ipucu otomatik ad); arkadaş kipinde "ARKADAŞLARI DAVET ET · n/9" onay kutulu liste (önceden seçili arkadaş parametresi); "Meydan okumayı başlat". Hatalar sayfanın içinde metin (S2 sapması 6 ile aynı). Başarıda sayfa kapanır ve meydan okuma sayfasına gidilir.

### 7.4 Meydan okuma sayfası (`ChallengeScreen`, `/social/challenge/:id`)

- Başlık kartı: ad; haplar (tür, ölçü, kas, topluluk adı); tarih aralığı; kalan süre / "Başlamasına …" / "Kesinleşiyor" / "Bitti"; "{n} katılımcı · açan {ad}"; hedefte hedef değeri.
- SIRALAMA: satır — sıra, avatar (`SocialAvatar`), ad (ben vurgulu, "Sen"), değer; hedefte satırda ilerleme çubuğu ve ulaşınca tik. Bitince kazanan(lar)ın satırında kupa; başlıkta sonuç metni.
- Bekleyen davetliler soluk metinle.
- Ödül kartı: "Birinci +100 XP" / "Hedefe ulaşan herkese +50 XP · Meydan okuyucu unvanına sayılır".
- Davetliysem altta Kabul / Reddet; topluluk meydan okumasında katılımcı değilsem "Katıl".
- Menü: "Ayrıl" (bitmeden, onaylı), "Sil" (yetkiye göre, onaylı).
- Görünmüyorsa (silinmiş/yetki yok) "Bu meydan okuma artık yok" metni.

### 7.5 Diğer yerler

- Topluluk sayfası: kas liderlerinin altında "MEYDAN OKUMALAR" kartı — aktif/başlamamış satırlar (katıldıysam değerim, değilsem "Katıl"), "+ Aç" (3 sınırı dolunca gizli) → oluşturma sayfası topluluk kipinde.
- Arkadaş profili: "Meydan oku" düğmesi → oluşturma sayfası o arkadaş seçili.
- Seviye ekranı: XP dökümünde "Meydan okumalar" satırı; unvanlarda "Meydan okuyucu" (kademe adları O1 kalıbıyla: "Meydan Okuma Çırağı/Ustası/Şampiyonu"); son kazanımlarda ödül olayı.

### 7.6 Çeviriler

`social.challenge_*` anahtarları TR + EN; plan tam listeyi verir (sekme, bölüm başlıkları, tür/ölçü/süre/başlangıç etiketleri, otomatik ad kalıpları, durum metinleri, sonuç metinleri, hata kodları, onaylar, boş durumlar). Unvan adı ve XP döküm satırı `gamification.` altında.

## 8. Hata ve kenar durumları

- Davet bitişten sonra kabul edilemez (`challenge_closed`); davet kartı bitmişse gösterilmez.
- Başlamamış meydan okumada değer 0; yayın `active`'ten itibaren.
- Uygulama kesinleşme payında açılmazsa son yayın geçerlidir (kabul edilen sınır).
- Arkadaşlıktan çıkma mevcut meydan okumayı etkilemez (`shares_challenge` profili görünür tutar).
- Topluluktan çıkarılan/ayrılan katılımcı meydan okumada kalır ve sayfayı görür.
- Hesap silinirse satırlar cascade ile silinir.
- Saat dilimi: pencere `timestamptz`; değer hesabı `finishedAt` UTC karşılaştırmasıyla.
- Ağ hataları SnackBar; yayınlama sessizce loglanır.

## 9. Testler (TDD)

- **Domain:** `challengeWindow` (hemen / yarın, yaz saati günü); `challengeValue` her ölçü, kas filtresi ağırlığı, pencere sınırları (başta dahil, sonda hariç), tamamlanmamış set, ödül XP'si hariç; `state` sınırları; `challengeStandings` eşitlik; `challengeWinners` (0 değer, tek katılımcı yarış, hedef); `challengeRewards`; otomatik ad; `TitleKind.challenge` kademeleri; `buildPlayerSummary` ödül olaylarıyla.
- **Sağlayıcı:** `myChallengesProvider` gruplama; `challengeSyncProvider` yalnız değişeni ve yalnız active/finalizing + joined yayınlar; `ChallengeActions` yenileme; davet sayısı rozeti.
- **Ekran:** dört sekme; Meydan okumalar sekmesi (davet kabul/ret, aktif kart yarış/hedef, biten sonuç metni, boş durum); oluşturma sayfası (kas listesi yalnız set/hacimde, hedef alanı yalnız hedefte, 9 sınırı, hata kodu metni, gönderilen parametreler); meydan okuma sayfası (sıralama ve vurgu, kesinleşiyor, kazanan kupası, katıl/kabul, ayrıl/sil onayı); topluluk kartı; arkadaş profili düğmesi; seviye ekranı satırı ve unvan.
- **SQL:** `checks/s3_rls_checks.sql` (§4.6).

## 10. Dal, sıra, manuel kontrol

- Dal: `s3-meydan-okumalar`. Sıra: migration + RLS kontrolü → domain (model, değer, sonuç) → XP/unvan entegrasyonu → depo + sağlayıcılar + yayın → Meydan okumalar sekmesi + oluşturma → meydan okuma sayfası → topluluk kartı + arkadaş profili + seviye ekranı → doğrulama.
- Kullanıcı `0015`'i SQL Editor'da uygular ve `s3_rls_checks.sql`'i çalıştırır.

Manuel kontrol (iki hesap, web release):
1. A, B'ye 3 günlük set yarışı açar; B'de davet ve rozet görünür; B kabul eder.
2. A antrenman yapar; iki tarafta da sıralama ve değerler güncellenir.
3. Hedef meydan okumasında ilerleme çubuğu ve hedefe ulaşınca tik.
4. Toplulukta A meydan okuma açar; B topluluk sayfasından katılır; 4. meydan okuma açılamaz.
5. B reddettiği davetin listeden kalktığını görür; ayrılma ve silme onaylı çalışır.
6. (Kısa test için SQL Editor'da `ends_at`/`starts_at` geriye çekilir) Kesinleşiyor → bitti; kazanan kupası, "+100 XP", seviye ekranında XP dökümü ve "Meydan okuyucu" unvanı.
7. Arkadaş profilinden "Meydan oku" o arkadaş seçili açılır.
8. ~360 px'te taşma yok (dört sekme kayar, ölçü çipleri sarılır); EN metinler doğru.

## 11. Kapsam dışı

- Anlık bildirimler (push), sohbet, rövanş düğmesi.
- Belirli hareket filtresi (ör. squat hacmi).
- Meydan okumayı düzenleme; özel tarih aralığı.
- Genel (herkese açık) meydan okumalar.
- Sunucu tarafında değer doğrulama / hile önleme.
- Meydan okuma geçmişinin arkadaş profilinde gösterimi.
