# F5 — AI Antrenör Chat: Tasarım Spec'i

> Durum: Bölümler kullanıcıyla tek tek onaylandı (2026-10-01). Sonraki adım: kullanıcı spec'i gözden geçirir → writing-plans ile implementasyon planı.

## 1. Kapsam

PLAN.md F5 fazı (E7). Dal `f5-ai-antrenor`, `master`'dan açılır.

**Kapsamda:**
- Alt menüde dördüncü sekme **Antrenör**: kullanıcının verisini bilen, soru yanıtlayan, öneri yapan tek ve sürekli bir sohbet.
- Sohbetten veri değiştirme (tool calling), altı araçla: `log_body_weight`, `update_profile`, `set_goal`, `create_meal`, `log_set`, `edit_program`.
- Her değişiklik önce sohbette **onay kartı** olarak gösterilir; kullanıcı onaylamadan hiçbir şey değişmez.
- Uygulanan her değişiklik süre sınırı olmadan **geri alınabilir**; kayıt sonradan değiştiyse geri alma engellenir.
- Kullanıcı başına günlük mesaj sınırı.

**Kapsam dışı:**
- pgvector / anlamsal arama (her mesajda güncel veri özeti yeterli).
- Hedef kalori/proteinin elle girilmesi (bir sonraki kilo kaydında üzerine yazılırdı).
- 1RM güncelleme aracı (1RM, F4a'daki antrenman sonu önerisiyle güncellenmeye devam eder).
- Hazır programları sohbetten düzenleme (önce kullanıcının kopyalaması önerilir).
- Cevapların akış (streaming) olarak gelmesi.
- Görsel tasarım yenileme ve oyunlaştırma (seviye, unvan): kullanıcı istedi, F5'ten sonra ayrı faz olarak ele alınacak (bkz. PLAN.md yol haritası).

**Ücretsizlik ve hedef kitle:** Uygulama store'da herkese açık olacak, başta az kullanıcı bekleniyor. LLM olarak F2'de kullanılan **Gemini ücretsiz katmanı** (aynı API anahtarı) kullanılır. Ücretsiz kota tüm uygulamanın ortak kotası olduğu için kullanıcı başına günlük sınır konur. Kullanıcı ileride başka sağlayıcıların API anahtarlarını verebilir; bu yüzden LLM erişimi sağlayıcıdan bağımsız bir arayüzün arkasındadır (§4.3).

## 2. Mimari Karar

Yaklaşım A (onaylandı):

1. `coach-chat` Edge Function'ı veri özetini hazırlar, LLM'i araç tanımlarıyla çağırır.
2. LLM bir araç çağırırsa hiçbir şey değişmez: Edge Function argümanları doğrular, gerekeni hazırlar (USDA makroları, programın yeni hali) ve `chat_events` tablosuna **beklemede** bir öneri yazar.
3. Kullanıcı **Onayla**'ya basınca uygulama doğrudan `apply_chat_action` SQL fonksiyonunu çağırır; değişiklik tek transaction'da, RLS altında uygulanır, öncesi/sonrası saklanır.
4. **Geri al**, `undo_chat_action` ile yapılır: mevcut veri uygulama sonrasıyla aynıysa öncesi geri yazılır.

Elenen yaklaşımlar: değişikliği Flutter'ın mevcut repository'lerle uygulaması (B) ve Edge Function'ın uygulaması (C). İkisinde de bir değişiklik birden fazla istekle yapılır, yarım kalabilir ve "sonradan değişti mi" kontrolü güvenilir olmaz.

## 3. Veri Modeli (`0010_create_coach_chat.sql`)

### `chat_messages`

| Kolon | Tip | Not |
|---|---|---|
| `id` | uuid pk | |
| `user_id` | uuid not null → auth.users, cascade | |
| `role` | text, `user` / `assistant` | |
| `content` | text not null | |
| `event_id` | uuid null → chat_events, `on delete set null` | Onay kartı taşıyan asistan mesajı |
| `created_at` | timestamptz default now() | |

İndeks: `(user_id, created_at desc)`.

### `chat_events`

| Kolon | Tip | Not |
|---|---|---|
| `id` | uuid pk | |
| `user_id` | uuid not null → auth.users, cascade | |
| `tool` | text, altı araç adından biri (check) | |
| `status` | text: `pending` / `applied` / `cancelled` / `undone` / `stale` | |
| `summary` | text not null | Kartta ve LLM geçmişinde kullanılan kısa özet |
| `payload` | jsonb not null | Uygulanacak değişiklik (§3.2) |
| `base` | jsonb not null | Öneri anındaki hedef verinin görüntüsü (`create_meal`'da `{"meal": null}`) |
| `before` | jsonb null | Uygulamadan hemen önceki görüntü |
| `after` | jsonb null | Uygulamadan sonraki görüntü |
| `created_at`, `applied_at`, `resolved_at` | timestamptz | `resolved_at`: vazgeçme / geri alma / bayatlama zamanı |

`chat_messages` silinince (Sohbeti temizle) `chat_events` satırları kalır; ekranda görünmedikleri için artık geri alınamazlar.

### `chat_usage`

`id bigserial pk`, `user_id` → auth.users cascade, `created_at timestamptz default now()`; indeks `(user_id, created_at)`. Her başarılı cevapta bir satır. RLS: yalnız kendi satırlarını **select** ve **insert**; update/delete politikası yok.

### RLS

İki tabloda da `user_id = auth.uid()` için select/insert/update/delete. Kullanıcı REST üzerinden kendi adına bir `chat_events` satırı yazıp uygulatabilir; bu, zaten yapabildiği değişikliklerden fazlasını sağlamaz (tüm yazmalar yine RLS altında), ama `apply_chat_action` payload'ı yine de tip ve aralık olarak doğrular.

### 3.1 Görüntü (snapshot) kapsamı

`chat_target_snapshot(tool, payload) returns jsonb` (security invoker) hedef verinin mevcut halini döndürür. `base`, `before`, `after` hep bu fonksiyonla alınır ve jsonb eşitliğiyle karşılaştırılır; böylece `updated_at` kolonu olmayan tablolarda da çalışır.

| Araç | Görüntüye giren veri |
|---|---|
| `log_body_weight` | O tarihteki `body_weight_logs` satırı (yoksa null) + `profiles.weight_kg`, `daily_calorie_target`, `daily_protein_target_g` |
| `update_profile`, `set_goal` | Payload'daki değişen `profiles` alanları + iki hedef alanı |
| `create_meal` | Payload'daki `meal_id`'li `meals` satırı + `meal_items` (öneri anında `{"meal": null}`) |
| `log_set` | İlgili `session_sets` satırı + oturumun `finished_at`'i |
| `edit_program` | Programın `save_program` formatındaki tam hali (`program_snapshot(id)` yardımcısıyla) |

### 3.2 Araçlar ve payload'lar

| Araç | Payload | Uygulama |
|---|---|---|
| `log_body_weight` | `{date, kg}` | `log_body_weight` mantığı: kayıt upsert; tarih en yeni kayıtsa profildeki kilo ve hedefler güncellenir |
| `update_profile` | `{changes: {height_cm?, activity_level?, does_exercise?, sport_type?, exercise_days_per_week?, health_notes?}}` | `profiles` güncellenir + hedefler. Kilo bu araçla değişmez (yalnız `log_body_weight`). |
| `set_goal` | `{goal}` | `profiles.goal` + hedefler |
| `create_meal` | `{meal_type, logged_at, items: [{name, grams, per100: {calories, protein_g, carbs_g, fat_g}, usda_fdc_id, needs_review}]}` | `meals` + `meal_items`; makrolar `grams × per100 / 100` |
| `log_set` | `{session_id, exercise_position, set_index, weight_kg, reps}` | Var olan set satırına yazar, `completed_at = now()`. Oturum bitmişse uygulanmaz. Yeni set eklemez. |
| `edit_program` (yalnız **aktif program**) | `{program_id, program: <save_program formatında tam hal>, changes: [{kind: add/remove/modify/rename, label}]}` | `save_program(program)`; `changes` yalnız kartta gösterilir |

### 3.3 Sunucu fonksiyonları (`security invoker`, tek transaction)

- **`apply_chat_action(p_event_id uuid, p_extras jsonb) returns text`**
  - Olay kullanıcıya ait ve `pending` değilse hata.
  - `chat_target_snapshot(...)` `base`'den farklıysa olayı `stale` yapar, değişiklik yapmadan `'stale'` döndürür.
  - Aksi halde `before` alır, değişikliği uygular, `after` alır, `applied` yapar, `'applied'` döndürür.
  - `p_extras`: `log_body_weight` / `update_profile` / `set_goal` için `{calorie_target, protein_target}` (zorunlu, > 0); `create_meal` için isteğe bağlı `{item_grams: [..]}` (kartta düzenlenen gramlar, her biri > 0, uzunluğu kalem sayısına eşit).
- **`cancel_chat_action(p_event_id)`**: yalnız `pending` → `cancelled`.
- **`undo_chat_action(p_event_id) returns text`**
  - Yalnız `applied` olaylar.
  - Mevcut görüntü `after`'a eşit değilse değişiklik yapmadan `'modified'` döndürür.
  - Eşitse `before`'u geri yazar (`create_meal`: öğünü siler; `edit_program`: `save_program(before)`; `log_body_weight`: önceki kayıt yoksa satırı siler, varsa geri yazar; profil alanları ve hedefler `before`'daki değerlere döner), `undone` yapar, `'undone'` döndürür.
- **`program_snapshot(p_program_id) returns jsonb`**: programı `save_program` girdisiyle aynı formatta döndürür (Edge Function'ın da kullandığı tek kaynak).

Not: `save_program` antrenmanları silip yeniden oluşturduğu için `program_workouts` id'leri değişir; `workout_sessions` bu id'lere değil ad/pozisyon kopyasına bağlı olduğundan sorun yoktur.

## 4. `coach-chat` Edge Function

### 4.1 İstek ve akış

`POST {message: string, locale: 'tr' | 'en', utc_offset_minutes: number}` (cihazın saat farkı: "bugün" ve öğün saati için); `Authorization: Bearer <kullanıcı JWT>`. Supabase istemcisi **kullanıcının JWT'siyle** oluşturulur; tüm okuma/yazma RLS'ten geçer.

1. **Günlük sınır:** Son 24 saatte verilen cevap sayısı ≥ `COACH_DAILY_LIMIT` (secret, varsayılan 30) ise `429 DAILY_LIMIT`. Cevaplar ayrı bir `chat_usage` tablosunda sayılır (kullanıcı yalnız okuyup ekleyebilir, silemez); böylece "Sohbeti temizle" sınırı sıfırlamaz. Hata alan istekler sınırdan düşmez. `{action: 'status'}` isteği LLM çağırmadan kalan hakkı döndürür (ekran açılışında).
2. **Veri özeti** (`context.ts`), kısa metin olarak:
   - profil, amaç, kalori/protein hedefi
   - bugünkü öğünler ve toplamları
   - son 30 günün kilo kayıtları
   - son 5 bitmiş antrenman (hareket başına en iyi set)
   - aktif programın yapısı (program id, antrenmanlar, hareket adları, set/tekrar)
   - devam eden oturum varsa setleri (pozisyon, set indeksi, hedef, yapılan)
   - 1RM değerleri
3. **Geçmiş:** son 20 mesaj; kart taşıyan asistan mesajlarına durum eklenir (`[kullanıcı onayladı]`, `[vazgeçti]`, `[geri aldı]`, `[veri değişmişti, uygulanmadı]`).
4. **LLM çağrısı:** sistem talimatı + veri özeti + geçmiş + yeni mesaj + araç tanımları. Sistem talimatı:
   - antrenör kimliği; cevap dili `locale`
   - değişiklikler yalnızca araçlarla yapılır, her cevapta en fazla bir araç çağrılır
   - tıbbi teşhis koymaz, gerekirse doktora yönlendirir
   - hazır programlar düzenlenemez, kopyalanması önerilir
   - makro/kalori hesabı yapmaz (`create_meal`'da yalnız yiyecek adı, gram ve İngilizce USDA sorgusu verir)
5. **Düz metin cevap:** kullanıcı ve asistan mesajı birlikte kaydedilir, döndürülür.
6. **Araç çağrısı:** `tools.ts` argümanları doğrular ve hazırlar:
   - `create_meal`: her kalem için USDA araması ve 100 g makroları (F2'deki `usda_client`); bulunamazsa sıfır makro + `needs_review: true`.
   - `edit_program`: LLM'in verdiği işlemler (`add_exercise`, `remove_exercise`, `modify_exercise`, `rename_workout`) `program_snapshot` üzerinde uygulanır (`program_ops.ts`); hareket adları `exercises` tablosunda aranır.
   - `log_set`: hedef setin devam eden oturumda var olduğu doğrulanır.
   - Diğerleri: aralık kontrolleri (kilo 20–400, boy 100–250, tarih gelecekte değil vb.).
   - Doğrulama hatası veya belirsiz hareket adı → hata / aday listesi LLM'e araç yanıtı olarak döner; **en fazla 3 LLM çağrısı**. Sonunda geçerli çağrı yoksa sabit, yerelleştirilmiş bir "tam anlayamadım, biraz daha açık yazar mısın?" cevabı döner (kotayı korumak için ek çağrı yapılmaz).
   - Geçerliyse: `base` görüntüsü alınır, `chat_events` (`pending`) + kartlı asistan mesajı + kullanıcı mesajı kaydedilir, döndürülür.

**Yanıt:** `{messages: [userMsg, assistantMsg], event?: {...}, remaining: number}`.

### 4.2 Hatalar

| Durum | Kod | Kullanıcının gördüğü |
|---|---|---|
| Günlük sınır doldu | 429 `DAILY_LIMIT` | "Mesaj hakkın doldu, biraz sonra tekrar dene" (yazma alanı kilitlenir) |
| LLM 429 (ortak kota) | 429 `LLM_QUOTA` | "Antrenör şu an çok yoğun, biraz sonra tekrar dene" |
| LLM erişilemiyor / zaman aşımı | 503 `LLM_UNAVAILABLE` | "Antrenöre şu an ulaşılamıyor" + tekrar dene |
| Geçersiz istek / JWT yok | 400 / 401 | Genel hata |

Hata durumunda hiçbir mesaj kaydedilmez; uygulama gönderilmemiş balonu yerelde tutar ve "tekrar dene" sunar. Hatalar Edge Function loguna yazılır (F2'deki gibi sessiz yutma yok).

### 4.3 Sağlayıcıdan bağımsız LLM katmanı

- `llm/llm_client.ts`: `interface LlmClient { generate(req: {system, messages, tools}): Promise<{type: 'text', text} | {type: 'tool_call', name, args}> }`. Mesajlar, araç tanımları (JSON Schema) ve araç yanıtları **uygulamanın kendi formatında**dır.
- `llm/gemini_client.ts`: Gemini implementasyonu; formata çevirme yalnız burada. Kota/erişim hataları ortak `LlmQuotaError` / `LlmUnavailableError` sınıflarına çevrilir.
- Seçim secret'larla: `LLM_PROVIDER` (varsayılan `gemini`), `LLM_MODEL` (varsayılan `gemini-3.5-flash-lite`). Yeni sağlayıcı = yeni bir `*_client.ts` + fabrika satırı.

### 4.4 Dosyalar

```
supabase/functions/
  _shared/usda_client.ts        # analyze-meal-photo'dan taşınır (import güncellenir)
  _shared/http.ts               # JWT'den user id, CORS başlıkları, jsonResponse (aynı şekilde taşınır)
  coach-chat/
    index.ts                    # HTTP, CORS, istemci oluşturma
    handler.ts                  # akış; bağımlılıklar enjekte edilir (test için)
    context.ts                  # veri özeti
    tools.ts                    # araç şemaları, doğrulama, hazırlama
    program_ops.ts              # program işlemleri (saf fonksiyonlar)
    prompts.ts                  # sistem talimatı (tr/en)
    llm/llm_client.ts, llm/gemini_client.ts, llm/factory.ts
```

## 5. Uygulama (Flutter)

### 5.1 Katmanlar (`lib/features/chat/`)

- `domain/`: `ChatMessage`, `ChatEvent` (araç, durum, payload, özet), araç başına kart modelleri; `ChatEvent`'ten kart verisini çıkaran saf fonksiyonlar.
- `data/`: `ChatRepository` — `loadMessages()`, `send(message, locale)` (`functions.invoke('coach-chat')`), `apply(eventId, extras)`, `cancel(eventId)`, `undo(eventId)`, `clear()`; hata kodlarını tipli istisnalara çevirir.
- `application/`: `ChatNotifier` (Riverpod) — mesaj listesi, gönderiliyor durumu, gönderilemeyen mesaj, kalan hak.
- `presentation/`: `CoachScreen`, `MessageBubble`, `ConfirmCard` ve araç başına kart gövdeleri.

### 5.2 Antrenör sekmesi

- `app_shell.dart`'a dördüncü sekme (ikon + `nav.coach`).
- Mesaj balonları; altta yazma alanı + gönder; beklerken "yazıyor…".
- Sohbet boşken öneri çipleri: "Bugün ne yemeliyim?", "Programımı değerlendir", "Kilomu kaydet".
- Kalan hak ≤ 5 ise yazma alanının üstünde "N mesaj hakkın kaldı" (son 24 saat); 0 ise alan kilitli.
- Menü: **Sohbeti temizle** → onay penceresi ("Mesajlar silinir, sohbetten yapılan değişiklikler artık geri alınamaz") → `clear()`.
- Gönderilemeyen mesaj: balonun yanında "Gönderilemedi, tekrar dene".
- Tüm metinler TR/EN i18n dosyalarında.

### 5.3 Onay kartları

| Araç | Kart içeriği |
|---|---|
| Kilo | "80 → 82 kg" (tarih), yeni kalori/protein hedefi |
| Profil / amaç | Değişen her alan önce → sonra; yeni hedefler |
| Öğün | Öğün türü, kalemler (gram düzenlenebilir, makrolar yeniden hesaplanır), toplam; `needs_review` kalemde uyarı |
| Set | "Squat 3. set: 80 kg × 5" |
| Program | "+ Eklenen", "− Çıkarılan", "~ Değişen (3×5 → 4×6)", "✎ Ad" |

**Durumlar:** `pending` → [Onayla] [Vazgeç]; `applied` → ✓ + [Geri al]; `cancelled` / `undone` → soluk; `stale` → "Veri bu arada değişti, tekrar iste"; geri alma `'modified'` döndürürse buton pasifleşir ve "Sonradan değişti" yazar.

**Hedef hesabı:** Kilo, profil ve amaç kartlarında yeni hedefler mevcut `TdeeCalculator` ile, kullanıcının güncel profiline değişiklik uygulanarak hesaplanır ve kartta gösterilir; onayda `p_extras` olarak gönderilir. Geri almada hesap yapılmaz (`before` eski hedefleri içerir).

### 5.4 Yenileme

Onay veya geri alma sonrası ilgili provider'lar yenilenir: profil/hedefler, günlük öğünler, ilerleme kartları (F4b yenileme yolu), programlar, devam eden oturum.

## 6. Test Stratejisi

- **SQL** (`supabase/migrations/checks/f5_rls_checks.sql`, tek DO bloğu, sonuç `raise exception` ile SONUC satırında, otomatik rollback):
  - her araç için uygula → beklenen veri; geri al → veri ve hedefler öncekiyle aynı
  - öneriden sonra veri değişince `apply` → `'stale'`, veri değişmedi
  - uygulamadan sonra veri değişince `undo` → `'modified'`, veri değişmedi
  - vazgeçilmiş / uygulanmış öneri tekrar uygulanamıyor
  - B kullanıcısı A'nın mesaj ve olaylarını göremiyor, uygulayamıyor, geri alamıyor
- **Deno** (`coach-chat`, LLM ve USDA sahte `fetch`/bağımlılıkla): veri özeti, araç doğrulama, `program_ops`, belirsiz hareket → aday listesi → düzeltme, 3 tur sınırı, günlük sınır, Gemini yanıt çevirisi (metin / araç çağrısı / 429 / 5xx), hata kodları; `analyze-meal-photo` testleri `_shared` taşımasından sonra da geçer.
- **Flutter:** model ve kart verisi testleri, sahte repository ile notifier testleri, araç başına kart widget testleri (önce/sonra, durumlar, gram düzenleme), sekme ve sohbet ekranı widget testleri; `flutter analyze` temiz.
- **Manuel** (release web build, gerçek Gemini): her araç için öner → onayla → ana sayfada etkisi → geri al; vazgeç; sonradan elle değiştirip geri alma engeli; öneriden sonra elle değiştirip bayatlama; günlük sınır (secret düşük ayarlanarak); İngilizce arayüzde İngilizce cevap; sohbeti temizle.

## 7. Devreye Alma (kullanıcı)

1. SQL Editor'da `0010_create_coach_chat.sql`, ardından `checks/f5_rls_checks.sql`.
2. `coach-chat` deploy; `_shared` taşıması nedeniyle `analyze-meal-photo` da yeniden deploy. Gemini anahtarı mevcut; `COACH_DAILY_LIMIT`, `LLM_PROVIDER`, `LLM_MODEL` isteğe bağlı.
3. Release web build ve manuel kontrol listesi.

## 8. Riskler

- **Ortak ücretsiz kota:** kullanıcı artarsa yetmeyebilir → günlük sınır + sağlayıcı değiştirilebilir katman.
- **Gizlilik:** Gemini ücretsiz katmanında gönderilen veriler Google tarafından ürün geliştirme için kullanılabilir; sohbete kişisel sağlık/kilo verisi gider. Store yayınından (F7) önce gizlilik metninde belirtilmeli.
- **LLM hatalı anlama:** her değişiklik onay kartından geçer; kart önce/sonra gösterir.
- **Program düzenlemede hareket eşleştirme:** kütüphane İngilizce adlı (free-exercise-db); LLM İngilizce ad verir, belirsizlikte aday listesiyle düzeltir.
- **Gecikme:** düzeltme turları bir cevabı 3 LLM çağrısına kadar uzatabilir; "yazıyor…" göstergesi ve zaman aşımı hata mesajı.
