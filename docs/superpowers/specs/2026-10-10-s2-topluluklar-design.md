# S2 — Topluluklar ve Dönem Unvanları — Tasarım Spec'i

> Durum: Bölümler kullanıcıyla tek tek onaylandı (2026-10-10). Sonraki adım: kullanıcı spec'i gözden geçirir → writing-plans ile S2 implementasyon planı. Dal: `s2-topluluklar`.

## 1. Bağlam

Oyunlaştırma fazları: O1 kişisel (`a4d8129`) → S1 arkadaşlık (`23a9e75`, migration `0013`) → **S2 topluluklar** → S3 meydan okumalar. S2, kullanıcıların topluluk kurup katılmasını, topluluk içinde ve tüm kullanıcılar arasında haftalık/aylık sıralamayı ve **sahibi her dönem değişen unvanları** getirir.

Mevcut kod:
- S1: `public_profiles`, `friendships`, `player_stats` (arkadaşlara özel), `are_friends`, `has_friendship`; `lib/features/social/` (`SocialRepository`, `socialOverviewProvider`, `statsSyncProvider` → `AppShell`, `SocialScreen`, `FriendProfileScreen`, `SocialSettingsScreen`, `SocialAvatar`, `TitlePill`, `UsernameField`, `runSocialAction`).
- O1: `xpEvents`, `PlayerSummary`, `Rank`, `RankBadge`, `gamification.muscle_short.<kas>` çevirileri.
- K3: `muscleWeight(exercise, muscle)`.
- Kas grupları: `muscleGroups` (17).
- Migration'lar SQL Editor'da kullanıcı tarafından uygulanır; RLS kontrolleri `checks/*.sql` DO blokları.

## 2. Kararlar (kullanıcıyla onaylı)

1. **Unvan alanları:** 17 kas (dönemde en çok ağırlıklı set) + genel XP ("Yıldız"). Hareket unvanı yok.
2. **Kapsam:** Unvanlar ve sıralama hem her toplulukta hem **genel** (tüm kullanıcılar) olarak.
3. **Dönemler:** hafta (ISO, pazartesi başlar) ve ay. **Geçen dönemin** sahipleri kesin unvandır ("Haftanın Kanat Şampiyonu"); **bu dönem** canlı sıralama/lider olarak gösterilir.
4. **Topluluklar:** herkese açık ve adla aranabilir; sahibi kapalıya çevirebilir (aramada görünmez, yalnız davet koduyla). Davet kodu her toplulukta var.
5. **Görünürlük:** Arkadaş olmayan topluluk üyeleri birbirinin yalnız sıralama verisini görür (ad, @kullanıcıadı, rütbe/seviye, takılı unvan, dönem XP'si ve kas setleri). Haftalık özet, son antrenmanlar, ısı haritası S1'deki gibi yalnız arkadaşlara. Katılırken bu bir satırla söylenir.
6. **Genel yarış:** sosyal kimliği olan herkes varsayılan olarak dahil; Sosyal ayarlarındaki "Genel sıralamada yer al" anahtarıyla çıkılır. Genel sonuçlarda yalnız ad, @kullanıcıadı, rütbe/seviye, takılı unvan ve değer görünür.
7. **Yönetim:** sahip ad/açıklama düzenler, açık/kapalı yapar, kodu yeniler, üye çıkarır/yasaklar. Sahip ayrılırsa en eski üye sahip olur; son üye ayrılırsa topluluk silinir. Sınırlar: kişi başı en çok 5 topluluk, toplulukta en çok 100 üye. Şikâyet yok.
8. **Yaklaşım A:** Uygulama dönem özetini ayrı `period_stats` satırına yazar; topluluk sıralaması uygulamada, genel sonuçlar sunucuda yayınlanmış sayılar üzerinde gruplamayla (`global_titles`, `global_leaderboard`) hesaplanır. XP/kas kuralları yalnız Dart'ta.
9. **Kapsam dışı:** kazanılan dönem unvanlarını profilde/arkadaş listesinde göstermek (S3 ya da ayrı iş).
10. **Stitch taslakları:** projeler 13488093778238513971 (topluluk sayfası) ve 4065884219403515497 (Genel sekmesi); görseller `.superpowers/brainstorm/s2-stitch/` (git'e girmez). Bağlayıcı tarif §6.

## 3. Veritabanı (`supabase/migrations/0014_social_communities.sql`)

### 3.1 `period_stats`

| Sütun | Tür |
|---|---|
| `user_id` | uuid PK → `auth.users` cascade |
| `level` | int not null |
| `rank` | text not null |
| `active_title` | jsonb null (S1 `SharedTitle` biçimi) |
| `periods` | jsonb not null |
| `updated_at` | timestamptz not null default now() |

`periods` biçimi (dört alan; her dönem kendi anahtarıyla):

```json
{
  "week":       {"key": "2026-W41", "xp": 640, "muscles": {"lats": 14.5, "chest": 9}},
  "prev_week":  {"key": "2026-W40", "xp": 910, "muscles": {}},
  "month":      {"key": "2026-10",  "xp": 1550, "muscles": {}},
  "prev_month": {"key": "2026-09",  "xp": 4120, "muscles": {}}
}
```

RLS: sahibi `insert/update/select`; `select` ayrıca `are_friends(auth.uid(), user_id)` ya da `shares_community(auth.uid(), user_id)`.

### 3.2 `public_profiles` değişikliği

- `compete_globally boolean not null default true`.
- Select politikası yeniden yazılır: kendisi, `has_friendship` ya da `shares_community`.

### 3.3 `communities`

| Sütun | Tür | Kural |
|---|---|---|
| `id` | uuid PK default `gen_random_uuid()` | |
| `name` | text not null | trim sonrası 3–40 |
| `description` | text not null default '' | ≤ 200 |
| `is_public` | boolean not null default true | |
| `invite_code` | text not null unique | `new_invite_code()` |
| `owner` | uuid not null → `auth.users` | |
| `created_at` | timestamptz default now() | |

RLS: `select` → `is_public` ya da `is_member(auth.uid(), id)`; `update` → `owner = auth.uid()` (`owner` ve `invite_code` sütunları güncellemede değişmez — politika `with check` ile sahibi korur; kod yenileme fonksiyonla). `insert/delete` politikası yok.

### 3.4 `community_members`

`community_id` → `communities` cascade, `user_id` → `auth.users` cascade, `role` (`owner` / `member`), `joined_at`; PK `(community_id, user_id)`; indeks `user_id`.
RLS: `select` → `is_member(auth.uid(), community_id)`. Yazma yalnız fonksiyonlarla.

### 3.5 `community_bans`

`community_id`, `user_id`, `created_at`; PK ikili. RLS: `select` yalnız topluluk sahibi. Yazma fonksiyonla.

### 3.6 Fonksiyonlar (security definer, `search_path = public`, `authenticated`'a izin, `anon`/`public`'ten alınır)

| Fonksiyon | Davranış |
|---|---|
| `is_member(u uuid, c uuid) returns boolean` (stable) | Üyelik var mı. |
| `shares_community(a uuid, b uuid) returns boolean` (stable) | Ortak bir topluluk var mı. |
| `create_community(p_name text, p_description text, p_is_public boolean) returns uuid` | Sosyal kimlik gerekli; çağıranın üyelik sayısı < 5; topluluk + sahip üyeliği. Hatalar: `no_profile`, `community_limit`. |
| `join_community(p_id uuid)` | Açık olmalı (`not_public`), yasaklı değil (`banned`), üye < 100 (`community_full`), çağıranın üyeliği < 5 (`community_limit`), sosyal kimlik (`no_profile`); zaten üyeyse sessiz. |
| `join_community_by_code(p_code text) returns uuid` | `upper(trim)` eşleşmesi (kapalı topluluklar dahil); aynı denetimler (`unknown_code`). |
| `leave_community(p_id uuid)` | Üyeliği siler; sahipse en eski üye sahip olur (`communities.owner` + rol); kimse kalmadıysa topluluk silinir. |
| `remove_member(p_id uuid, p_user uuid, p_ban boolean)` | Yalnız sahip (`not_owner`); kendini çıkaramaz; `p_ban` ise `community_bans`'a ekler. |
| `regenerate_community_code(p_id uuid) returns text` | Yalnız sahip. |
| `search_communities(p_query text)` | Açık topluluklar, `name ilike '%q%'` (q ≥ 2 karakter), `table(id, name, description, member_count, is_member)`, üye sayısına göre, en çok 20. |
| `community_period_value(periods jsonb, p_slot_kind text, p_key text, p_field text)` (immutable, iç yardımcı) | `p_slot_kind` `week` ise `week`/`prev_week`, `month` ise `month`/`prev_month` alanlarından anahtarı eşleşenin değerini döndürür (`xp` ya da `muscles.<kas>`); yoksa 0. |
| `global_titles(p_kind text, p_key text)` | `compete_globally` olan sosyal kimlikler arasında kategori başına (`xp` + 17 kas) en yüksek değer > 0 olan(lar): `table(category text, user_id uuid, username text, display_name text, level int, rank text, value numeric)`. Eşitlikte hepsi. |
| `global_leaderboard(p_kind text, p_key text)` | Aynı kişiler arasında dönem XP'sine göre ilk 50 (> 0): `table(position int, user_id, username, display_name, level, rank, active_title jsonb, xp int)`. |

### 3.7 RLS kontrolleri (`supabase/migrations/checks/s2_rls_checks.sql`)

A, B, C ile (C yoksa ilgili satırlar "atlandi"); beklenenler:
- A topluluk kurar; B adla arayınca bulur; A kapalıya çevirince B aramada bulamaz ama kodla katılır.
- C (üye değil) A'nın `period_stats` satırını göremez; B (üye) görür.
- A, B'yi yasaklayarak çıkarır; B kodla tekrar katılamaz (`banned`).
- A ayrılınca topluluğun sahibi B olur (yasak öncesi senaryoda), son üye ayrılınca topluluk silinir.
- A'nın 6. topluluğu `community_limit` verir.
- `compete_globally = false` olan kişi `global_titles` / `global_leaderboard` sonuçlarında yok.
- Doğrudan `community_members` insert'ü engellenir.

Plan, beklenen `SONUC:` satırını tam yazar.

## 4. Domain (`lib/features/social/domain/`)

```dart
// period_keys.dart
enum PeriodKind { week, month }
String weekKey(DateTime local);            // ISO: '2026-W41'; 2026-12-31 ve 2027-01-01 → '2026-W53', 2027-01-04 → '2027-W01'
String monthKey(DateTime local);           // '2026-10'
({DateTime start, DateTime end}) periodRange(PeriodKind kind, DateTime local, {bool previous = false}); // [start, end)
String periodKey(PeriodKind kind, DateTime local, {bool previous = false});

// period_stats.dart
class PeriodSlot { final String key; final int xp; final Map<String, double> muscles; }
class PeriodStats {
  final int level; final Rank rank; final SharedTitle? activeTitle;
  final PeriodSlot week, prevWeek, month, prevMonth;
  final DateTime? updatedAt;
  PeriodSlot? slotFor(PeriodKind kind, String key); // anahtarı eşleşen alan, yoksa null
  Map<String, dynamic> toJson(); factory fromJson; == / hashCode (updatedAt hariç, kas anahtarları sıralı)
}
PeriodStats buildPeriodStats({required PlayerSummary summary, required List<WorkoutSession> sessions,
  required List<DateTime> mealTimes, required Map<String, Exercise> exercisesById, required DateTime now,
  required String? activeTitleId});

// standings.dart
class Standing { final String userId; final int xp; final int position; } // 1'den, eşit XP aynı sıra
List<Standing> standings(Map<String, PeriodStats> members, PeriodKind kind, String key); // xp > 0, büyükten küçüğe
class PeriodTitle { final String category; final List<String> holders; final double value; } // category: 'xp' ya da kas adı
List<PeriodTitle> periodTitles(Map<String, PeriodStats> members, PeriodKind kind, String key); // value > 0; sıra: 'xp' önce, sonra muscleGroups sırası

// community.dart
class Community { final String id, name, description, inviteCode; final bool isPublic; final String owner; final int memberCount; }
class CommunityMember { final String userId; final bool isOwner; final DateTime joinedAt; }
class CommunitySearchResult { final String id, name, description; final int memberCount; final bool isMember; }
class GlobalTitle { final String category; final String userId, username, displayName; final int level; final Rank rank; final double value; }
class GlobalRow { final int position; final String userId, username, displayName; final int level; final Rank rank; final SharedTitle? activeTitle; final int xp; }
```

Kurallar:
- Dönem XP'si: `xpEvents(sessions, mealTimes)` olaylarından tarihi dönem aralığında olanların toplamı.
- Kas setleri: bitmiş oturumların (bitişi dönem aralığında) tamamlanmış setleri × `muscleWeight` (yalnız `muscleGroups`).
- `buildPeriodStats` dört alanı `now`'a göre doldurur (bu ve önceki hafta/ay).
- `slotFor`: hafta için `week` ve `prevWeek`, ay için `month` ve `prevMonth` alanlarına bakar.

## 5. Veri ve sağlayıcılar

`SocialRepository`'ye eklenenler:

```dart
Future<List<Community>> fetchMyCommunities();
Future<Community?> fetchCommunity(String id);
Future<List<CommunityMember>> fetchMembers(String communityId);
Future<List<CommunitySearchResult>> searchCommunities(String query);
Future<String> createCommunity({required String name, required String description, required bool isPublic});
Future<void> joinCommunity(String id);
Future<String> joinCommunityByCode(String code);
Future<void> leaveCommunity(String id);
Future<void> updateCommunity(String id, {String? name, String? description, bool? isPublic});
Future<void> removeMember(String communityId, String userId, {required bool ban});
Future<String> regenerateCommunityCode(String id);
Future<Map<String, PeriodStats>> fetchPeriodStats(List<String> userIds);
Future<void> upsertMyPeriodStats(PeriodStats stats);
Future<List<GlobalTitle>> globalTitles(PeriodKind kind, String key);
Future<List<GlobalRow>> globalLeaderboard(PeriodKind kind, String key);
```

`updateProfile`'a `competeGlobally` eklenir; `PublicProfile`'a `competeGlobally`.

Fonksiyon hataları (`community_limit`, `community_full`, `banned`, `not_public`, `unknown_code`, `no_profile`) `CommunityException(code)` olarak fırlatılır; ekranlar koda göre metin gösterir.

Sağlayıcılar:
- `myCommunitiesProvider` — `FutureProvider.autoDispose<List<Community>>` (profil yoksa boş).
- `communityDetailProvider(id)` — `FutureProvider.autoDispose.family<CommunityDetail?, String>`: topluluk, üyeler, profiller, `period_stats`; üye değilse null.
- `globalBoardProvider(kind)` — `FutureProvider.autoDispose.family<GlobalBoard, PeriodKind>`: geçen dönemin `globalTitles` + bu dönemin `globalLeaderboard`.
- `statsSyncProvider`: `player_stats`'a ek olarak `period_stats`'ı hesaplar; `lastPublishedPeriodStatsProvider` ile aynıysa yazmaz.
- `CommunityActions`: oluşturma, katılma, ayrılma, düzenleme, çıkarma, kod yenileme; sonrasında ilgili sağlayıcıları geçersiz kılar.

`CommunityDetail { Community community; List<CommunityMember> members; Map<String, PublicProfile> profiles; Map<String, PeriodStats> stats; bool get iAmOwner; }`.

## 6. Arayüz

### 6.1 `SocialScreen`

Profil varken gövde `DefaultTabController(length: 3)`: `TabBar` (`social_tab_friends`, `social_tab_communities`, `social_tab_global`) + `TabBarView`. "Arkadaşlar" bugünkü S1 görünümüdür (kendi kartı dahil). Profil yoksa kimlik oluşturma değişmez.

### 6.2 Topluluklar sekmesi (`CommunitiesTab`)

- "Topluluk kur" (`community_create`) ve "Katıl" (`community_join`) düğmeleri; üyelik 5 ise ikisi de devre dışı ve altında `community_limit_note`.
- "Topluluklarım" listesi (`my_communities`): satır `community_<id>`: ad, "{n} üye", bu haftaki sıram ("{p}. / {n}", sıralamada yoksam "—"); dokununca `/social/community/<id>`. Boşsa `communities_empty`.
- **Kurma sayfası** (`CommunityFormSheet`): ad (`community_name_field`), açıklama (`community_description_field`), "Açık / Kapalı" anahtarı (`community_public_switch`), "OLUŞTUR" (`community_form_save`); kurunca topluluk sayfasına gider.
- **Katılma sayfası** (`JoinCommunitySheet`): `SegmentedButton` "Ara" / "Davet kodu" (`join_mode_search`, `join_mode_code`); arama ≥ 2 karakter → sonuç satırları `join_result_<id>` (ad, açıklama, üye sayısı, "KATIL" `join_result_join_<id>` ya da "Üyesin"); kod alanı + "KATIL" (`join_code_submit`). Üstte gizlilik notu (`join_privacy_note`). Hata kodları SnackBar metni.

### 6.3 Topluluk sayfası (`CommunityScreen`, `/social/community/:id`)

- Yükleniyor / hata (`community_retry`) / üye değil (`community_not_member`).
- AppBar: ad; menü (`community_menu`): "Topluluktan ayrıl" (`community_leave` → onay `community_leave_confirm` → ayrıl → `canPop` ise geri); sahipse ayrıca "Düzenle" (`community_edit` → `CommunityFormSheet` düzenleme modu), "Kodu yenile" (`community_regenerate`), "Üyeleri yönet" (`community_manage`).
- Başlık kartı (`community_header`): ad, açıklama, "{n} üye", "AÇIK/KAPALI" etiketi, davet kodu + kopyala (`community_copy_code`).
- `SegmentedButton` HAFTA / AY (`period_week`, `period_month`).
- "Geçen haftanın / ayın şampiyonları" (`community_titles`): `PeriodTitlesList` — satır `title_<category>`: kupa ikonu, unvan adı, sahip(ler) adı ve değer ("1.240 XP" / "22 set"). Boşsa `community_titles_empty`.
- "Bu hafta / bu ay · canlı" (`community_standings`): başlığın sağında dönem bitişine kalan süre (`period_remaining`: 24 saatten azsa "{n} saat kaldı", değilse "{n} gün kaldı"; `PeriodKey` aralık sonundan hesaplanır). `StandingsList` — satır `standing_<userId>`: sıra (ilk üç lime madalya), avatar, ad, "Sv n", XP; benim satırım lime çerçeveli ve üstünde "SENİN SIRAN" etiketi. Altında açılır "Kas liderleri" (`community_muscle_leaders`): bu dönemin `periodTitles` (XP hariç).
- **Üye yönetimi** (`ManageMembersSheet`): üye satırları `manage_<userId>` + "Çıkar" (`manage_remove_<id>`) ve "Yasakla" (`manage_ban_<id>`), onaylı; kendim ve sahip için düğme yok.

### 6.4 Genel sekmesi (`GlobalTab`)

- HAFTA / AY (`global_period_week`, `global_period_month`).
- `compete_globally` kapalıysa üstte `global_opted_out` metni + ayarlara bağlantı (`global_open_settings`).
- "Geçen haftanın / ayın genel şampiyonları" (`global_titles`): `PeriodTitlesList` (sahip @kullanıcıadı ile).
- "Bu hafta / bu ay · ilk 50" (`global_standings`): başlıkta `period_remaining`; `StandingsList` ad altında @kullanıcıadı ile; benim satırım (ilk 50'deysem) vurgulu.
- Yükleniyor / hata (`global_retry`).

### 6.5 Sosyal ayarlar

"Arkadaşlarım görebilir" bölümünden sonra "Yarış" başlığı ve `SwitchListTile` `compete_globally` ("Genel sıralamada yer al") + açıklama.

### 6.6 Unvan adları ve çeviriler

- Kas: `social.period_title_<kind>` = "Haftanın {name} Şampiyonu" / "Ayın {name} Şampiyonu" (EN: "{name} Champion of the Week/Month"); `name` = `gamification.muscle_short.<kas>`.
- XP: "Haftanın Yıldızı" / "Ayın Yıldızı" (EN: "Star of the Week/Month").
- Diğer metinler `social.` altında; plan tam listeyi verir (sekme adları, topluluk formu, katılma, hata kodları, menü, onaylar, dönem başlıkları, boş durumlar, gizlilik notu, "Genel sıralamada yer al").

## 7. Hata ve kenar durumları

- Eşitlik: unvanda tüm sahipler gösterilir; sıralamada aynı sıra numarası.
- Eski veri: bir üyenin anahtarı dönemle eşleşmiyorsa o dönem için 0 (sıralamada yok).
- Topluluk silindiyse ya da çıkarıldıysam sayfa `community_not_member` gösterir.
- Sahip son üyeyse ayrılınca topluluk silinir (onay metninde söylenir).
- Ağ hataları SnackBar; yayınlama sessizce loglanır.

## 8. Testler (TDD)

- **Domain:** ISO hafta (2026-12-28/31, 2027-01-01, 2027-01-03/04), ay anahtarı, önceki dönem; dönem aralık sınırları; `buildPeriodStats` (XP ve kas setleri, sınır anları); `slotFor` (iki alandan eşleşme, eşleşmeyen → null); `standings` (eşit sıra, 0 hariç); `periodTitles` (eşitlikte çok sahip, 0 hariç, sıra); JSON gidiş-dönüş ve eşitlik.
- **Sağlayıcı:** `communityDetailProvider` (üyeler + sıralama verisi); `statsSyncProvider` iki satırı yazar, aynıysa yazmaz; `CommunityActions` yenileme; `globalBoardProvider`.
- **Ekran:** üç sekme; topluluk kurma ve katılma (arama, kod, hata kodu metni, 5 sınırı); topluluk sayfası (başlık, HAFTA/AY, kesin unvanlar, canlı sıralama ve vurgu, ayrılma onayı, sahip menüsü ve üye yönetimi); Genel sekmesi (unvanlar, ilk 50, yarış dışı metni); ayarlarda anahtar.
- **SQL:** `checks/s2_rls_checks.sql` (§3.7).

## 9. Dal, sıra, manuel kontrol

- Dal: `s2-topluluklar`. Sıra: migration + RLS kontrolü → dönem anahtarları ve `PeriodStats` → sıralama/unvan domain'i → depo + sağlayıcılar + yayın → Sosyal sekmeleri + Topluluklar sekmesi (kurma/katılma) → topluluk sayfası + yönetim → Genel sekmesi + ayar → doğrulama.
- Kullanıcı `0014`'ü SQL Editor'da uygular ve `s2_rls_checks.sql`'i çalıştırır.

Manuel kontrol (iki hesap):
1. A topluluk kurar; B adla arayıp katılır; ikisi de "Topluluklarım"da görür.
2. Antrenmandan sonra topluluk sayfasında canlı sıralama ve kas liderleri doğru.
3. A topluluğu kapalı yapar; aramada çıkmaz; B'nin üçüncü hesabı/ya da çıkıp tekrar katılma kodla çalışır.
4. A, B'yi yasaklar; B kodla katılamaz ve hata metni görür.
5. Genel sekmesinde iki hesap ilk 50'de görünür; A "Genel sıralamada yer al"ı kapatınca A listeden çıkar ve yarış dışı metni görür.
6. Geçen dönem şampiyonları bölümü (henüz geçmiş dönem verisi yoksa boş metni) doğru.
7. Sahip ayrılınca yönetim diğer üyeye geçer.
8. ~360 px'te taşma yok; EN metinler doğru.

## 10. Kapsam dışı

- Şikâyet / moderatör ekranı.
- Genel sekmesinde ilk 50 dışındaysam kendi sıramın altta sabit gösterimi ve "+3 sıra" gibi değişim göstergesi (Stitch taslağında var; sunucuda ayrı sıra sorgusu ve geçmiş sıra gerektirir).
- Kazanılan dönem unvanlarının profilde veya arkadaş listesinde gösterimi; unvan geçmişi (dondurma).
- Topluluk sohbeti, gönderiler, bildirimler.
- Hareket bazlı dönem unvanları.
- Meydan okumalar (S3).
