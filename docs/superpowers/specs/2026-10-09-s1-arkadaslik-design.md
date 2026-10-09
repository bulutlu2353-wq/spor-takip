# S1 — Arkadaşlık Temeli — Tasarım Spec'i

> Durum: Bölümler kullanıcıyla tek tek onaylandı (2026-10-09). Sonraki adım: kullanıcı spec'i gözden geçirir → writing-plans ile S1 implementasyon planı. Dal: `s1-arkadaslik`.

## 1. Bağlam

Oyunlaştırma dört faza bölündü (O1 spec §10): O1 kişisel (master `a4d8129`) → **S1 arkadaşlık** → S2 topluluklar → S3 meydan okumalar. S1, kullanıcıların birbirini bulup arkadaş olmasını ve arkadaşının ilerlemesini görmesini sağlar. S2 ve S3 aynı kimlik, arkadaşlık ve `player_stats` altyapısının üstüne kurulur.

Mevcut kod:
- O1: `PlayerSummary`, `playerSummaryProvider`, `xpEvents` (rekor olayları), `RankBadge`, `Rank`, `TitleProgress`, `titleName` (`lib/features/gamification/`).
- K3: `historyMuscleLoad`, `heatTiers`, `HeatTier` (`lib/features/workout/domain/muscle_heat.dart`); `MiniMuscleMapCard` (`widgets/muscle_map.dart`; şu an `onTap` zorunlu).
- İlerleme: `allSessionsProvider`, `mealTimesProvider`, `startOfWeek` (`lib/features/progress/domain/weekly_summary.dart`).
- Kabuk: `lib/core/app_shell.dart` (4 sekme: ana sayfa, beslenme, antrenman, kilitli antrenör), `lib/core/router.dart` (`StatefulShellRoute.indexedStack`, 4 dal).
- Migration'lar `supabase/migrations/` (son: `0012_adaptive_calories.sql`); kullanıcı SQL Editor'da uygular. RLS kontrolleri `supabase/migrations/checks/*.sql` DO blokları; sonuç bilerek HATA olarak basılır, değişiklikler geri alınır.
- Profiller: `profiles` (yalnız sahibi okur); görünen ad / kullanıcı adı yok.

## 2. Kararlar (kullanıcıyla onaylı)

1. **Ekleme yolu:** benzersiz @kullanıcıadı ile tam eşleşme araması + kişisel davet kodu. Kısmi arama, liste, öneri yok.
2. **Arkadaş profili:** seviye/rütbe/unvanlar, haftalık özet, son antrenmanlar, 7 günlük kas ısısı.
3. **Gizlilik:** haftalık özet, son antrenmanlar ve kas ısısı ayrı ayrı açılıp kapanır (varsayılan açık). Seviye/rütbe/unvan her zaman paylaşılır. Kilo, ölçü, beslenme içeriği, sağlık notları, e-posta asla paylaşılmaz.
4. **Yer:** alt menüde beşinci "Sosyal" sekmesi; kilitli Antrenör sekmesi yerinde kalır.
5. **Yaklaşım A:** Uygulama kendi özetini `player_stats` satırına yazar, arkadaşlar okur. Kurallar Dart'ta tek yerde; satır biraz eski kalabilir ("güncellendi: …" gösterilir).
6. **Kimlik:** Sosyal sekmesi ilk açıldığında kullanıcı adı ve görünen ad seçilir.
7. **Stitch taslakları:** projeler 2855319676009028316 (Sosyal sekmesi) ve 6071504996184780635 (arkadaş profili); görseller `.superpowers/brainstorm/s1-stitch/` (git'e girmez): `social_tab.png`, `friend_profile.png`. Alınanlar: baş harfli, lime çerçeveli köşeli avatar (arkadaş olmayan/giden istekte gri çerçeve); "SV n · RÜTBE" hapı; kesik çerçeveli davet kodu kutusu + "KOPYALA"; istek kartında ad altında yan yana REDDET / KABUL; arkadaş satırında SV hapı ve unvan hapı; profilde ikonlu üç sayı kutusu, ikonlu son antrenman satırları ve tarih etiketi, lime şimşekli rekor satırı. Kapsam dışı: Haftalık Lig kartı, "YÖNET", sıralama düğmesi, bölge, aktif seri, "odak", "tümünü gör", farklı alt menü, beslenme yer tutucusu (beslenme hiç paylaşılmaz). Yerleşimin bağlayıcı tarifi §6'dır.

## 3. Veritabanı (`supabase/migrations/0013_social_friends.sql`)

### 3.1 `public_profiles`

| Sütun | Tür | Kural |
|---|---|---|
| `user_id` | uuid PK | → `auth.users(id)` on delete cascade |
| `username` | text not null unique | `^[a-z0-9_]{3,20}$` |
| `display_name` | text not null | trim sonrası 1–30 karakter |
| `invite_code` | text not null unique | varsayılan: 8 karakter, `A-Z` + `2-9` (karışan `0 O 1 I` yok) |
| `share_weekly`, `share_workouts`, `share_heat` | boolean not null | varsayılan `true` |
| `created_at`, `updated_at` | timestamptz | `now()` |

- Davet kodu: `public.new_invite_code()` fonksiyonu; çakışma olursa insert hatası, istemci yeniden dener (olasılık ihmal edilebilir).
- RLS: sahibi `select/insert/update`; aralarında herhangi bir `friendships` satırı (bekleyen ya da kabul edilmiş) olan kişi `select` (politika `has_friendship(auth.uid(), user_id)`), böylece istek tarafları birbirinin adını görür. Bu kişiler gizlilik sütunlarını da teknik olarak okur; bayraklar hassas değildir ve paylaşımı istemci zaten `player_stats`'ta uygular.
- `delete` politikası yok (hesap silinince cascade).

### 3.2 `friendships`

| Sütun | Tür | Kural |
|---|---|---|
| `requester` | uuid not null | → `auth.users(id)` cascade |
| `addressee` | uuid not null | → `auth.users(id)` cascade |
| `status` | text not null | `pending` / `accepted` |
| `created_at` | timestamptz | `now()` |
| `accepted_at` | timestamptz null | |

- PK `(requester, addressee)`; `check (requester <> addressee)`; benzersiz indeks `(least(requester, addressee), greatest(requester, addressee))`.
- RLS: taraflar `select`. `insert/update/delete` politikası yok; değişiklik yalnız aşağıdaki fonksiyonlarla.

### 3.3 `player_stats`

| Sütun | Tür |
|---|---|
| `user_id` | uuid PK → `auth.users(id)` cascade |
| `level` | int not null |
| `total_xp` | int not null |
| `rank` | text not null (`Rank.name`) |
| `active_title` | jsonb null (`{kind, subject_id, exercise_name, tier}`) |
| `titles` | jsonb not null (en çok 10; aynı biçimde liste) |
| `weekly` | jsonb null (`{workouts, sets, meal_days}`) |
| `recent` | jsonb null (en çok 5: `{name, date, sets, records: [{name, weight_kg, reps}]}`) |
| `heat` | jsonb null (`{"<kas>": "<HeatTier.name>"}`) |
| `updated_at` | timestamptz not null |

- RLS: sahibi `insert/update/select`; arkadaşlar `select` (`are_friends`).

### 3.4 Fonksiyonlar (security definer, `set search_path = public`)

| Fonksiyon | Davranış |
|---|---|
| `are_friends(a uuid, b uuid) returns boolean` (stable) | `accepted` satır var mı. |
| `has_friendship(a uuid, b uuid) returns boolean` (stable) | Herhangi bir durumda satır var mı. |
| `find_user(p_username text)` | `lower(trim(p_username))` tam eşleşmesi; `table(user_id uuid, username text, display_name text)`; kendini döndürmez. Giriş yoksa hata. |
| `find_user_by_invite(p_code text)` | `upper(trim(p_code))` tam eşleşmesi; aynı dönüş. |
| `send_friend_request(p_target uuid) returns text` | Kendine → hata. Hedefin `public_profiles` satırı yoksa → hata. Ters yönde `pending` varsa → `accepted` yapar, `'accepted'` döner. Zaten arkadaş → `'already_friends'`. Aynı yönde bekleyen → `'pending'`. Yoksa insert → `'pending'`. Çağıranın kendi `public_profiles` satırı yoksa hata. |
| `respond_friend_request(p_requester uuid, p_accept boolean)` | Çağıran `addressee` olan `pending` satır; kabul → `accepted` + `accepted_at`; ret → siler. Satır yoksa hata. |
| `remove_friend(p_other uuid)` | İki yönde de satırı siler (arkadaşlığı bitirir ya da isteği geri çeker/reddeder). |
| `username_available(p_username text) returns boolean` | Kurala uyuyor ve başkası almamışsa `true` (kendi adı da `true`). |

`execute` izni `authenticated` rolüne; `anon`'dan alınır.

### 3.5 RLS kontrolleri (`supabase/migrations/checks/s1_rls_checks.sql`)

A, B, C üç mevcut kullanıcıyla tek DO bloğu (gerekirse geçici `public_profiles` satırları içinde oluşturulur; sonunda bilerek hata → geri alınır). Beklenen çıktı satırı tek tek isimlendirilir:
- A → B istek: `'pending'`; B → A istek: `'accepted'` (karşılıklı otomatik kabul).
- C, A'nın `player_stats` satırını göremez (0 satır); B görür (1).
- C, `friendships`'e doğrudan insert yapamaz (RLS hatası).
- `find_user` kendini döndürmez; büyük harfli ad bulunur.
- `remove_friend` sonrası B, A'nın `player_stats`'ını göremez.
- `username_available('A_kullanici_adi')` B için `false`, A için `true`.

## 4. Domain (`lib/features/social/domain/`)

```dart
// username.dart
enum UsernameProblem { tooShort, tooLong, invalidCharacters }
String normalizeUsername(String raw);           // trim + lowercase + baştaki '@' atılır
UsernameProblem? checkUsername(String normalized); // 3–20, [a-z0-9_]

// public_profile.dart
class PublicProfile {
  final String userId, username, displayName, inviteCode;
  final bool shareWeekly, shareWorkouts, shareHeat;
  factory PublicProfile.fromJson(Map<String, dynamic> json);
}
class FoundUser { final String userId, username, displayName; }

// friendship.dart
enum FriendshipState { incoming, outgoing, friends }
class Friendship {
  final String requester, addressee;
  final bool accepted;
  final DateTime createdAt;
  FriendshipState stateFor(String me);
  String otherThan(String me);
}

// player_stats.dart
class SharedPrivacy { final bool weekly, workouts, heat; }
class WeeklyStats { final int workouts, sets, mealDays; }
class SharedRecord { final String name; final double weightKg; final int reps; }
class RecentWorkout { final String name; final DateTime date; final int sets; final List<SharedRecord> records; }
class SharedTitle { final TitleKind kind; final String subjectId; final String? exerciseName; final TitleTier tier; }
class PlayerStats {
  final int level, totalXp;
  final Rank rank;
  final SharedTitle? activeTitle;
  final List<SharedTitle> titles;        // ≤ 10
  final WeeklyStats? weekly;             // gizliyse null
  final List<RecentWorkout>? recent;     // ≤ 5; gizliyse null
  final Map<String, HeatTier>? heat;     // gizliyse null
  final DateTime? updatedAt;             // okunurken dolu; yazarken null
  Map<String, dynamic> toJson();          // updated_at hariç
  factory PlayerStats.fromJson(Map<String, dynamic> json);
  // == ve hashCode: updatedAt hariç tüm alanlar (değişmediyse yazılmaz)
}

PlayerStats buildPlayerStats({
  required PlayerSummary summary,
  required List<WorkoutSession> sessions,
  required List<DateTime> mealTimes,
  required Map<String, Exercise> exercisesById,
  required DateTime now,
  required String? activeTitleId,
  required SharedPrivacy privacy,
});
```

Kurallar:
- **Hafta:** `startOfWeek(now)` dahil, sonraki pazartesi hariç; bitmiş oturum sayısı (tamamlanmış seti olan), tamamlanmış set sayısı (sınırsız), öğün günü sayısı (yerel gün).
- **Son antrenmanlar:** tamamlanmış seti olan son 5 bitmiş oturum, yeniden eskiye; `sets` = tamamlanmış set; `records` = `xpEvents`'teki aynı `finishedAt` tarihli rekor olayları.
- **Isı:** `heatTiers(historyMuscleLoad(sessions, exercisesById, now − 7 gün), days: 7)`.
- **Unvanlar:** `summary.titles`'ın ilk 10'u; `activeTitle` = `summary.titleById(activeTitleId)`.
- Gizlilik kapalı bölüm `null`.

## 5. Veri ve sağlayıcılar

`lib/features/social/data/social_repository.dart`:

```dart
abstract class SocialRepository {
  Future<PublicProfile?> fetchMyProfile();
  Future<PublicProfile> createProfile({required String username, required String displayName});
  Future<PublicProfile> updateProfile({String? username, String? displayName, bool? shareWeekly, bool? shareWorkouts, bool? shareHeat});
  Future<bool> usernameAvailable(String username);
  Future<FoundUser?> findByUsername(String username);
  Future<FoundUser?> findByInviteCode(String code);
  Future<List<Friendship>> fetchFriendships();
  Future<String> sendRequest(String targetId);          // 'pending' | 'accepted' | 'already_friends'
  Future<void> respond(String requesterId, {required bool accept});
  Future<void> removeFriend(String otherId);
  Future<List<PublicProfile>> fetchProfiles(List<String> userIds);
  Future<Map<String, PlayerStats>> fetchStats(List<String> userIds);
  Future<void> upsertMyStats(PlayerStats stats);
}
```

Sağlayıcılar (`lib/features/social/application/social_providers.dart`):
- `socialRepositoryProvider`
- `myPublicProfileProvider` — `FutureProvider<PublicProfile?>`; giriş yoksa null.
- `friendshipsProvider` — `FutureProvider.autoDispose<List<Friendship>>`.
- `friendsProvider` — `FutureProvider.autoDispose<List<FriendEntry>>`: kabul edilmişlerin profilleri + istatistikleri; seviyeye göre büyükten küçüğe, eşitlikte görünen ad.
- `incomingRequestCountProvider` — `Provider<int>` (`friendshipsProvider` değeri yoksa 0).
- `friendProfileProvider(id)` — `FutureProvider.autoDispose.family<FriendEntry?, String>`; arkadaş değilse null.
- `statsSyncProvider` — `FutureProvider.autoDispose<void>`: profil yoksa hiçbir şey yapmaz; varsa `buildPlayerStats` ile hesaplar, `lastPublishedStatsProvider` (bellek) ile aynıysa yazmaz, değilse `upsertMyStats` ve son yazılanı günceller. Hata yutulur ve `debugPrint`'le loglanır (yayınlama arka plan işidir).
- `SocialActions` (`Provider`): `send`, `respond`, `remove`, `createProfile`, `updateProfile`; her işlemden sonra ilgili sağlayıcıları geçersiz kılar.

`FriendEntry { PublicProfile profile; PlayerStats? stats; }`.

## 6. Arayüz

### 6.1 Kabuk ve rotalar

- `AppShell` `ConsumerWidget` olur; `ref.watch(statsSyncProvider)` (değer kullanılmaz); beşinci `NavigationDestination` (`Icons.group_outlined` / `Icons.group`, `nav.social`), gelen istek > 0 ise ikon `Badge(label: Text('$n'))` ile sarılı. Anahtar `nav_social_badge`.
- Router: beşinci `StatefulShellBranch`: `/social` (`SocialScreen`), alt rotalar `friend/:id` (`FriendProfileScreen`), `settings` (`SocialSettingsScreen`).

### 6.2 `SocialScreen`

- Profil yükleniyor → `CircularProgressIndicator`; hata → `social_retry`.
- Profil yok → **kimlik oluşturma** (`social_create`): başlık + açıklama; kullanıcı adı alanı (`social_username_field`, `@` öneki) ve yazarken 400 ms gecikmeli `usernameAvailable` (`social_username_status`: uygun / alınmış / geçersiz + `UsernameProblem` metni); görünen ad alanı (`social_display_name_field`); "OLUŞTUR" (`social_create_button`, yalnız geçerli + uygun + ad doluysa etkin).
- Profil var → `ListView`:
  1. **Kendi kartım** (`social_me_card`): baş harf avatarı, görünen ad, @kullanıcıadı, `RankBadge` + "Sv n · rütbe" (`playerSummaryProvider`'dan); "Davet kodum" + kod (`social_invite_code`) + kopyala (`social_copy_invite`; panoya "`social.invite_text`" kalıbı, SnackBar).
  2. **"ARKADAŞ EKLE"** dolu düğme (`social_add_friend`) → `AddFriendSheet`.
  3. **İstekler** (yalnız varsa; `social_requests`): gelen satırlar `request_<userId>` + "KABUL" (`request_accept_<id>`) / "REDDET" (`request_decline_<id>`); giden satırlar "Gönderildi" + "GERİ ÇEK" (`request_cancel_<id>`).
  4. **Arkadaşlar** (`social_friends`): satır `friend_<userId>`: avatar, görünen ad, @kullanıcıadı, küçük `RankBadge` + "Sv n", takılı unvan hapı; dokununca `/social/friend/<id>`. Boşsa `social_friends_empty`.
- AppBar sağında dişli (`social_settings_button`) → `/social/settings` (yalnız profil varsa).

İstek satırlarındaki adlar için `fetchProfiles` kullanılır; istek tarafları birbirinin profilini `has_friendship` politikasıyla görür (§3.1).

### 6.3 `AddFriendSheet`

- `SegmentedButton`: "Kullanıcı adı" / "Davet kodu" (`add_mode_username`, `add_mode_invite`).
- Alan (`add_query_field`) + "ARA" (`add_search`).
- Sonuç: bulunamadı (`add_not_found`); bulundu kartı (`add_result`): avatar, görünen ad, @kullanıcıadı, "İSTEK GÖNDER" (`add_send`). Gönderince sonuç metni: `pending` → "İstek gönderildi", `accepted` → "Artık arkadaşsınız", `already_friends` → "Zaten arkadaşsınız" (`add_outcome`); ardından sağlayıcılar yenilenir.

### 6.4 `FriendProfileScreen`

- Yükleniyor / hata (`friend_retry`) / arkadaş değil (`friend_not_found`).
- AppBar: "@kullanıcıadı"; menü (`friend_menu`) → "Arkadaşlıktan çıkar" (`friend_remove`) → onay diyaloğu (`friend_remove_confirm`) → `remove` → `pop`.
- `ListView`:
  1. **Başlık** (`friend_header`): `RankBadge` (88), görünen ad, takılı unvan hapı (`friend_active_title`), "SEVİYE n · rütbe", "Toplam n XP", soluk "Güncellendi: …" (`friend_updated`; dakika/saat/gün önce).
  2. **Unvanlar** (`friend_titles`): `Wrap` çipleri (`titleName`); yoksa boş metin.
  3. **Bu hafta** (`friend_weekly`): üç kutu; `weekly == null` → `friend_hidden_weekly` ("Paylaşılmıyor", kilit ikonu).
  4. **Kas ısısı · son 7 gün** (`friend_heat`): `MiniMuscleMapCard(onTap: null)`; `heat == null` → `friend_hidden_heat`.
  5. **Son antrenmanlar** (`friend_recent`): satır `friend_recent_<i>`: ad, "n set · tarih", her rekor için lime şimşek satırı "Rekor: {ad} {kg} kg × {tekrar}"; `recent == null` → `friend_hidden_recent`; boş liste → boş metin.
- `stats == null` (henüz yayın yok): başlıkta yalnız ad ve kullanıcı adı + "Henüz istatistik yok" (`friend_no_stats`).

### 6.5 `SocialSettingsScreen`

- Görünen ad alanı (`settings_display_name`), kullanıcı adı alanı (`settings_username`, uygunluk göstergesi), "KAYDET" (`settings_save`).
- "Arkadaşlarım görebilir" başlığı altında üç `SwitchListTile`: `share_weekly`, `share_workouts`, `share_heat`; değişince hemen `updateProfile` → `statsSyncProvider` yeniden hesaplar.
- Açıklama: seviye/rütbe/unvanlar her zaman görünür; kilo, ölçü, beslenme asla paylaşılmaz.

### 6.6 `MiniMuscleMapCard`

`onTap` isteğe bağlı olur; `null` ise `InkWell` yerine düz içerik ve sağ üstteki ok yok. Başlık metni isteğe bağlı `title` parametresiyle verilebilir (varsayılan mevcut "Çalışan kaslar").

### 6.7 Çeviriler

`nav.social`; yeni `social` bloğu: başlıklar, kimlik oluşturma metinleri, `UsernameProblem` metinleri, uygun/alınmış, davet metni (`invite_text`: "LevelUp Fit'te arkadaşım ol — kod: {code}" / "Join me on LevelUp Fit — code: {code}"), kopyalandı, ekleme sayfası metinleri ve sonuçları, istek düğmeleri, boş durumlar, arkadaş profili bölüm başlıkları, "Paylaşılmıyor", "Henüz istatistik yok", "Güncellendi: {ago}" ve göreli zaman kalıpları (`ago_minutes`, `ago_hours`, `ago_days`, `ago_now`), çıkarma onayı, ayarlar metinleri. Plan tam anahtar listesini verir.

## 7. Hata ve kenar durumları

- Kullanıcı adı yarışı: oluşturma/güncellemede benzersizlik ihlali (`23505`) → alanın altında "alınmış" gösterilir.
- Ağ hataları: ekran işlemleri SnackBar (`social.action_error`); yayınlama sessizce loglanır.
- Kendi kodunu/adını aramak: `find_*` kendini döndürmez → "bulunamadı".
- Arkadaşlıktan çıkarılan biri profil ekranındayken: yenilemede `friend_not_found`.
- `player_stats`'ta bilinmeyen `rank`/`tier`/`kind` (gelecek sürüm): `rookie` / satır atlanır.
- Profil yokken Sosyal dışındaki ekranlar etkilenmez; yayın yapılmaz.

## 8. Testler (TDD)

- **Domain:** `normalizeUsername` / `checkUsername` (sınırlar 2/3/20/21, `@` öneki, büyük harf, tire, Türkçe karakter); `Friendship.stateFor`; `buildPlayerStats` (hafta sınırı pazar 23:59 / pazartesi 00:00, son 5 sırası ve rekor eşleşmesi, ısı kademeleri, her gizlilik anahtarı, unvan sınırı 10, aktif unvan); `PlayerStats` JSON gidiş-dönüş ve eşitlik (`updatedAt` hariç).
- **Sağlayıcı:** sahte depo ile `friendsProvider` sırası; `incomingRequestCountProvider`; `statsSyncProvider` profil yokken yazmaz, aynı içerikte ikinci kez yazmaz, gizlilik değişince yazar.
- **Ekran:** kimlik oluşturma (uygunluk göstergesi, düğme etkinliği, oluşturunca ana görünüm); ana görünüm (kart, kod kopyalama, istek kabul/ret/geri çekme, arkadaş satırı → rota); ekleme sayfası (bulunamadı, gönder → sonuç metni); arkadaş profili (beş bölüm, gizli bölümler, istatistiksiz durum, çıkarma onayı); ayarlar (anahtarlar `updateProfile` çağırır); `AppShell` beşinci sekme ve rozet.
- **SQL:** `checks/s1_rls_checks.sql` (§3.5).

## 9. Dal, sıra, manuel kontrol

- Dal: `s1-arkadaslik`. Sıra: migration + RLS kontrolü → domain → depo + sağlayıcılar + yayın → kabuk/rotalar → Sosyal ekranı + ekleme sayfası → arkadaş profili → ayarlar → doğrulama.
- Kullanıcı `0013`'ü SQL Editor'da uygular, `s1_rls_checks.sql`'i çalıştırır (en az iki hesap gerekir; üçüncü hesap yoksa kontrol C adımlarını atlar ve bunu sonuçta yazar).
- Tam test paketi ve web release derlemesi kullanıcının terminalinde.

Manuel kontrol listesi (iki hesap, iki tarayıcı profili):
1. Sosyal sekmesi ilk açılışta kimlik oluşturmayı istiyor; alınmış ad "alınmış" gösteriyor.
2. A, B'yi kullanıcı adıyla buluyor ve istek gönderiyor; B'nin sekmesinde rozet "1".
3. B kabul ediyor; iki tarafta da arkadaş listesinde görünüyorlar.
4. Davet koduyla ekleme çalışıyor (üçüncü hesap ya da çıkarıp yeniden ekleme ile).
5. A antrenman bitiriyor; B yenileyince A'nın profilinde son antrenman ve rekor görünüyor.
6. A haftalık özeti kapatıyor; B yenileyince "Paylaşılmıyor".
7. Arkadaşlıktan çıkarınca iki tarafta da liste boşalıyor, profil açılmıyor.
8. ~360 px genişlikte taşma yok; EN metinler doğru.

## 10. Kapsam dışı

- Kısmi arama, öneriler, engelleme, şikâyet.
- Bildirimler (push / e-posta).
- Davet bağlantısıyla uygulamayı açma (derin bağlantı); yalnız kodu kopyalama.
- Profil fotoğrafı.
- Arkadaş aktivite akışı (feed), beğeni/yorum.
- Topluluklar (S2), meydan okumalar (S3).
