# F2 — Fotoğrafla Besin Takibi: Tasarım Spec'i

> Durum: Onaylandı (2026-09-23). Sonraki adım: writing-plans ile implementasyon planı.

## 1. Kapsam

Bu spec, PLAN.md §3 E2 epic'ini (Fotoğraflı Besin Takibi) kapsar: kullanıcı bir öğün fotoğrafı çeker, AI yemek/porsiyon tahmini yapar, kullanıcı düzenler/onaylar, günlük makro toplamları hedefe karşı gösterilir.

**Kapsam dışı (bilinçli olarak ertelendi):**
- E3 epic'i — manuel arama / elle yemek ekleme / sık kullanılanlar (ayrı bir sonraki spec).
- Offline fotoğraf kuyruğu — F2 MVP internet bağlantısı gerektirir.
- Gemini/USDA API anahtarlarının temini — implementasyon mock/stub API yanıtlarıyla ilerler, gerçek anahtarlar geldiğinde F1'deki Supabase bağlantısı gibi ayrı bir uçtan uca doğrulama adımı olur.

## 2. Sağlayıcı Kararı (önceki araştırmadan)

- **Vision modeli**: Gemini 2.5 Flash-Lite (kalıcı ücretsiz katman: 1000 istek/gün, 15 RPM, kredi kartı gerekmez).
- **Beslenme veritabanı**: USDA FoodData Central (ücretsiz API).
- **Mimari ilke**: LLM sadece yiyecek tanıma + porsiyon tahmini yapar (JSON); gerçek makro değerleri USDA'dan çekilir. Gerekçe: macroscanner açık kaynak projesi, LLM'e ham makro hesaplattırmanın hem daha az doğru hem daha pahalı olduğunu gösterdi (bkz. PLAN.md §6).

## 3. Veri Modeli

```sql
create table if not exists public.meals (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users (id) on delete cascade,
  meal_type text not null check (meal_type in ('breakfast', 'lunch', 'dinner', 'snack')),
  photo_path text,
  logged_at timestamptz not null default now(),
  created_at timestamptz not null default now()
);

create table if not exists public.meal_items (
  id uuid primary key default gen_random_uuid(),
  meal_id uuid not null references public.meals (id) on delete cascade,
  name text not null,
  grams numeric not null check (grams > 0),
  calories numeric not null default 0,
  protein_g numeric not null default 0,
  carbs_g numeric not null default 0,
  fat_g numeric not null default 0,
  usda_fdc_id text,
  needs_review boolean not null default false,
  created_at timestamptz not null default now()
);

alter table public.meals enable row level security;
alter table public.meal_items enable row level security;

create policy "Users can manage own meals"
  on public.meals for all
  using (auth.uid() = user_id)
  with check (auth.uid() = user_id);

create policy "Users can manage own meal items"
  on public.meal_items for all
  using (exists (select 1 from public.meals m where m.id = meal_id and m.user_id = auth.uid()))
  with check (exists (select 1 from public.meals m where m.id = meal_id and m.user_id = auth.uid()));
```

**Storage**: `meal-photos` bucket, yol düzeni `{user_id}/{meal_id}.jpg`. RLS politikası: kullanıcı yalnızca kendi `{user_id}/` önekindeki dosyalara erişebilir (standart Supabase Storage RLS paterni, `storage.objects` üzerinde).

## 4. Flutter Feature Yapısı

`lib/features/nutrition/` — mevcut `onboarding` feature'ının katman paternini izler:

```
nutrition/
  domain/
    meal_type.dart          # enum: breakfast, lunch, dinner, snack
    food_item.dart          # ad, gram, makrolar, usdaFdcId, needsReview
    meal.dart                # id, type, loggedAt, photoPath, items
  data/
    meal_repository.dart     # Storage upload, Edge Function çağrısı, DB yazma/okuma
  application/
    meal_capture_notifier.dart   # durum makinesi: idle/uploading/analyzing/reviewing/saving/error
    today_meals_provider.dart    # günün öğünlerini + toplamlarını sağlar
  presentation/
    nutrition_screen.dart    # günlük öğün listesi + FAB
    meal_capture_screen.dart # kamera/galeri seç → yükleniyor → review/edit
    widgets/
      food_item_edit_tile.dart # tek öğe: ad/gram düzenleme, sil, needs_review rozeti
```

**Navigasyon**: `lib/core/router.dart` içinde `StatefulShellRoute.indexedStack` ile alt nav bar kurulur — `/home` ve `/nutrition` sekmeleri. Mevcut `redirect_logic.dart` mantığı (auth/profil durumuna göre yönlendirme) korunur, shell route'un altına taşınır.

## 5. Edge Function: `analyze-meal-photo`

**Girdi** (POST body):
```json
{ "photo_path": "{user_id}/{meal_id}.jpg" }
```

**Çıktı** (başarılı):
```json
{
  "items": [
    {
      "name": "Izgara tavuk göğsü",
      "grams": 150,
      "calories": 247,
      "protein_g": 46.5,
      "carbs_g": 0,
      "fat_g": 5.4,
      "usda_fdc_id": "171077",
      "needs_review": false
    },
    {
      "name": "Bilinmeyen sos",
      "grams": 30,
      "calories": 0,
      "protein_g": 0,
      "carbs_g": 0,
      "fat_g": 0,
      "usda_fdc_id": null,
      "needs_review": true
    }
  ]
}
```

**Adımlar**:
1. `photo_path` ile Storage'dan fotoğrafı indir (service role key).
2. Gemini 2.5 Flash-Lite'a görsel + yapılandırılmış prompt gönder → yalnızca `[{name, estimated_grams}]` JSON iste (makro hesaplattırma).
3. Her `name` için USDA FDC `/foods/search` çağrısı yap, en iyi eşleşmeyi seç (basit skor: isim benzerliği + `dataType` önceliği — `Foundation`/`SR Legacy` tercih edilir).
4. Eşleşme bulunursa `/food/{fdcId}` ile 100g başına makroları çek, `grams/100` ile çarp, `usda_fdc_id` doldur, `needs_review: false`.
5. Eşleşme bulunamazsa (skor eşiğinin altında veya sonuç yok) → makrolar 0, `needs_review: true`, `usda_fdc_id: null`.
6. Sonuçları döndür.

**Hata kodları**: `GEMINI_UNAVAILABLE`, `GEMINI_QUOTA_EXCEEDED`, `PHOTO_NOT_FOUND`, `INTERNAL_ERROR` — Flutter tarafı bunlara göre TR mesaj gösterir; `GEMINI_*` hatalarında review ekranı boş öğe listesiyle açılır (elle giriş).

**Ortam değişkenleri** (Supabase secrets): `GEMINI_API_KEY`, `USDA_FDC_API_KEY`.

## 6. Kullanıcı Akışı

1. Beslenme sekmesinde FAB → öğün türü seçimi (kahvaltı/öğle/akşam/atıştırmalık) → kamera/galeri.
2. Fotoğraf seçilir → yükleniyor göstergesi → Edge Function çağrılır → analiz ediliyor göstergesi.
3. Review ekranı: tahmin edilen öğeler düzenlenebilir liste halinde (ad, gram alanları), `needs_review` olan öğeler vurgulanır ve makro alanları elle doldurulmadan kaydetme engellenir. Kullanıcı öğe silebilir / elle yeni öğe ekleyebilir.
4. Onayla → `meals` + `meal_items` yazılır, review ekranı kapanır, günlük liste ve toplamlar güncellenir.
5. Beslenme sekmesi: bugünün öğünleri öğün türüne göre gruplu liste + günlük toplam (kalori/protein/karbonhidrat/yağ) hedefe karşı gösterim (profildeki `dailyCalorieTarget`/`dailyProteinTargetG` kullanılır).

## 7. Hata Yönetimi (özet tablo)

| Durum | Davranış |
|-------|----------|
| İnternet yok / yükleme başarısız | TR hata mesajı + "Tekrar Dene" butonu, fotoğraf atılır |
| Gemini timeout/hata | "AI şu an kullanılamıyor, öğünü elle ekleyebilirsin" + boş review ekranı |
| Gemini günlük kota doldu | Özel mesaj: "Günlük AI analiz limiti doldu, öğünü elle ekleyebilirsin" |
| USDA eşleşme yok | `needs_review` rozeti, makro alanları zorunlu elle giriş olmadan kayıt engellenir |
| Grams ≤ 0 | Form doğrulama hatası, kayıt engellenir |

## 8. Test Stratejisi

- **Domain**: `meal.dart` için günlük makro toplama unit testleri (birden fazla öğün/öğe toplamı, boş liste).
- **Data**: `MealRepository` için mock Supabase client testleri (mevcut `profile_repository_test.dart` paterni) — upload, insert, fetch senaryoları.
- **Edge Function**: Deno unit testleri — prompt oluşturma, USDA eşleştirme skorlama mantığı, hata kodu haritalama; mock HTTP yanıtlarıyla (gerçek Gemini/USDA çağrısı yok).
- **Application**: `meal_capture_notifier` durum geçişi testleri (idle→uploading→analyzing→reviewing→saving, hata dalları).
- **Widget**: review ekranı doğrulama (0 gram engellenir, needs_review öğe kaydı engeller), günlük liste render testi.
- **Uçtan uca**: gerçek Gemini + USDA anahtarları elimize geçince, F1'deki Supabase doğrulama adımına benzer şekilde manuel test yapılacak; CI'da gerçek dış API çağrısı yapılmaz.

## 9. Açık Riskler / Notlar

- USDA eşleştirme skorlama basit (isim benzerliği) olduğu için yanlış eşleşme riski var; kullanıcının düzenleme imkânı bu riski azaltıyor.
- Gemini 2.5 Flash-Lite günlük 1000 istek limiti tek kullanıcılı geliştirme/test için yeterli; çok kullanıcılı prod ölçeğinde izlenmeli (PLAN.md §8 madde 3 — rate-limit/önbellek tavsiyesi ileride devreye girebilir).
- `photo_path` kalıcı olarak saklanıyor (denetim/geri bildirim için) — KVKK/veri saklama politikası F6/F9 kapsamında ele alınacak (PLAN.md §8 madde 10).
