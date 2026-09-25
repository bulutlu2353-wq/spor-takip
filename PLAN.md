# Spor & Beslenme Takip Uygulaması — Geliştirme Planı

> Bu doküman projenin ana planıdır. Diğer yapay zekalar ve geliştiriciler için yol haritası olarak kullanılır. Değişiklikler bu dosyada işlenir ve tarihlendirilir.

---

## 1. Vizyon

"Mobil spor ve beslenme asistanı":

- Kullanıcı yemeğinin fotoğrafını çeker → AI kalori/protein/makro hesabı yapar.
- Fitness programlarını takip eder (ağırlık, set, tekrar, süre).
- Hazır ya da tamamen özelleştirilebilir antrenman programları oluşturur.
- Tümüyle konuşarak yönetilebilen bir **AI antrenör chat'i** vardır; sohbet hem öneri/öğüt verir hem de kişisel verileri ve planları düzenler.

## 2. Kullanıcı Akışı

```
Kayıt / Giriş
   → Onboarding anketi (profil verileri)
      → Ana ekran (Dashboard)
         → Fotoğrafla besin takibi
         → Antrenman programları & set takibi
         → İlerleme takibi
         → AI Antrenör Chat (öneri + düzenleme)
```

### Onboarding Soruları
1. Kilo (kg)
2. Boy (cm)
3. Doğum yılı
4. Cinsiyet
5. Aktivite düzeyi (hareketsiz / hafif / orta / yoğun / çok yoğun)
6. Spor yapıyor mu?
7. Hangi sporu yapıyor? (fitness, koşu, yüzme, bisiklet, futbol…)
8. Haftada kaç gün spor yapıyor? (0–7)
9. Hedef: kilo verme / kas kazanma / formda kalma
10. Mevcut sağlık durumu (opsiyonel, not alanı)

Bu verilerle günlük kalori ve protein hedefi (TDEE formülüne dayalı) otomatik hesaplanır.

## 3. Temel Özellikler (Epic'ler)

| # | Epic | Detay |
|---|------|-------|
| E1 | Onboarding & Profil | Anket, hedef belirleme, günlük kalori/protein hedefi hesabı (TDEE) |
| E2 | Fotoğraflı Besin Takibi | Fotoğraf → AI yemek/porsiyon tahmini → makro düzenleme → günlük toplamlar |
| E3 | Besin Veritabanı | Sık kullanılanlar, arama, özel yemek ekleme, manuel hızlı giriş |
| E4 | Antrenman Programları | Hazır programlar + boştan ve mevcut programdan özelleştirilebilir programlar |
| E5 | Ağırlık & Set Takibi | Egzersiz bazında ağırlık/tekrar/set/süre kaydı, günlük antrenman |
| E6 | İlerleme Takibi | Kilo, beden ölçüleri, ağırlık artışı grafikleri, haftalık özet |
| E7 | AI Antrenör Chat | Veriye erişen, plan öneren/düzenleyen, soruları yanıtlayan sohbet |
| E8 | Bildirimler & Alışkanlık | Yemek/antrenman hatırlatmaları, makroların günlük kapanışı |
| E9 | Ayarlar & Store Yayını | Dil (TR/EN), koyu tema, hesap silme, üyelik modeli |

## 4. Teknoloji Yığını (öneri)

| Katman | Seçenek | Not |
|--------|---------|-----|
| Mobil | **Flutter** | Tek kod tabanıyla Android + iOS. Güçlü UI, hızlı geliştirme. |
| Backend/Veri | **Supabase** | PostgreSQL, Auth (email/Google), Storage (fotoğraflar), Edge Functions. |
| Fotoğraf AI | **Bulut Vision API** | GPT-4o Vision / Google Gemini. Edge Function üzerinden proxy → API anahtarı cihazda tutulmaz. |
| Chat AI | **LLM (GPT/Claude/Gemini)** | Supabase Edge Function + **pgvector** (kullanıcı verisi bağlamı). |
| Analitik | **PostHog** | Kendi kendine barındırılabilir, ucuz, gizlilik dostu. |
| State (Flutter) | **Riverpod** | Modern, test edilebilir. |
| Yerel önbellek | **Drift/SQLite** | Offline-first yaklaşım. |
| CI/CD | **GitHub Actions** | analyze + test → otomatik build (App Distribution / TestFlight). |

### Teknoloji kararı (gelecekte)
- **Flutter önerilen** seçenektir; karar verilmeden önce ekibin JavaScript bilgisi (React Native alternatifi) ve hedef platformlar gözden geçirilecek.

## 5. Veri Modeli (ana tablolar)

| Tablo | Açıklama |
|-------|----------|
| `profiles` | Onboarding cevapları, hedefler, TDEE sonuçları |
| `foods` | Besin veritabanı (yemek, porsiyon başına makrolar) |
| `meals` | Günlük öğünler |
| `meal_items` | Öğün içindeki besinler |
| `programs` | Hazır/özel antrenman programları |
| `workouts` | Haftalık antrenman planları |
| `exercises` | Egzersiz tanımları (kas grubu, tip) |
| `set_logs` | Yapılan setler (ağırlık, tekrar, süre) |
| `body_measurements` | Kilo ve beden ölçüm geçmişi |
| `chat_messages` | Chat mesajları |
| `chat_events` | Chat'ten yapılan düzenlemelerin kaydı (geri alınabilirlik) |

Tüm tablolarda **Supabase RLS (Row Level Security)** aktif — herkes yalnızca kendi verisini görür. Chat'in veri düzenlemesi de RLS kurallarına uyar.

## 6. AI Entegrasyonu — Kritik Tasarım

### Fotoğraf Tanıma

**Sağlayıcı kararı (2026-09-22 araştırması):** **Gemini 2.5 Flash-Lite** — kalıcı ücretsiz katman (1000 istek/gün, 15 RPM, kredi kartı gerekmez), kredi/deneme süresi olan NVIDIA NIM'e tercih edildi. Gemini 3.x Flash serisi API üzerinden ücretsiz değil (yalnızca AI Studio arayüzünde), bu yüzden 2.5 Flash-Lite seçildi. **Güncelleme (2026-09-24):** Google `gemini-2.5-flash-lite`'ı yeni kullanıcılara kapattı (404); yerine önerilen **`gemini-3.5-flash-lite`**'a geçildi — bu model de API'de ücretsiz katmana sahip (ücretli: $0,30 girdi / $2,50 çıktı, 1M token başına).

**Mimari (macroscanner açık kaynak projesinden öğrenilen iki aşamalı yaklaşım):**
1. Fotoğraf çekilir → Supabase Storage'a yüklenir.
2. Edge Function → **Gemini 3.5 Flash-Lite** → yalnızca `{yemek_adı, tahmini_porsiyon_g}` JSON listesi döner (LLM'e ham makro hesaplattırılmaz).
3. Edge Function bu isimleri **USDA FoodData Central** (ücretsiz API) üzerinden aratır, gerçek makro değerlerini (kalori/protein/karbonhidrat/yağ, 100g başına) oradan çeker ve porsiyonla çarpar.
4. Kullanıcı tahmini düzenler / onaylar.
5. Kaydedilir; yanlış tahminler yeni örnek olarak token etiketlenir (ileride ince ayar için).

Bu yaklaşım hem doğruluğu artırıyor (LLM sayısal beslenme hesabı yapmak yerine sadece tanıma yapıyor) hem de maliyeti düşürüyor. Benzer bir projede (macroscanner, GPT-4o + doğrudan LLM makro tahmini) fotoğraf başına 20-30 cent maliyet oluşmuş; iki aşamalı yaklaşım bunu önlüyor.

### Chat (AI Antrenör)
- Mesajlara kullanıcının güncel verisi eklenir: hedef, son antrenmanlar, günlük makrolar.
- **Tool calling** ile işlemler: `update_profile`, `edit_program`, `log_set`, `set_goal`, `create_meal`.
- Her düzenleme öncesi kullanıcıya özet gösterilir, onay istenir.
- Chat'te yapılan değişiklikler token edilir ve **geri alınabilir**.

## 7. Geliştirme Fazları (Yol Haritası)

| Faz | Süre* | Kapsam |
|-----|-------|--------|
| F0 | 1 hafta | Repo, Flutter + Supabase kurulumu, CI (analyze/test), temel mimari |
| F1 | 2 hafta | Auth + onboarding anketi + profil + TDEE hedef hesabı |
| F2 | 3 hafta | Fotoğraf takibi: kamera + storage + Vision API, düzenleme, günlük makro ekranı |
| F3 | 3 hafta | Programlama: hazır + özel programlar, haftalık plan |
| F4 | 3 hafta | Antrenman & set takibi, ilerleme grafikleri |
| F5 | 4 hafta | AI Chat antrenör + tool calling + geri alma |
| F6 | 2 hafta | Bildirimler, dil desteği, koyu tema, son testler |
| F7 | 1–2 hafta | Store yayını (Play Console / App Store başvuruları) |

\* Yarı zamanlı tek geliştirici varsayımıyla; tam zamanlıda ~%40 daha kısa.

## 8. Geliştirme Tavsiyeleri

1. **Önce çalışan bir çekirdek:** Onboarding + beslenme takibi önce, chat sonra. İlk sürüm zaten değerli olmalı.
2. **Offline-first:** Kamera/veri girişi internetsiz de çalışmalı; senkron kuyruğu kur.
3. **AI maliyet kontrolü:** Vision isteklerinde rate-limit (kullanıcı günlük X sorgu), fotoğraf önbelleği (aynı fotoğraf yeniden tanınmasın), işe göre model seçimi.
4. **API anahtarları yalnızca Edge Function'da** — asla cihaza gömme.
5. **RLS'yi ilk günden yaz** — güvenliği sona bırakma.
6. **Test stratejisi:** Widget testi (onboarding akışı), Edge Function birim testi (AI çıktı şeması), E2E (Flutter Integration Test).
7. **CI/CD:** GitHub Actions → `flutter analyze` + test → otomatik build (Firebase App Distribution / TestFlight).
8. **Veri şeması sürümleme:** Supabase migration'larla DB değişiklikleri git'e bağlansın.
9. **İnce ayar verisi biriktir:** Kullanıcının düzelttiği fotoğraf tahminleri anonim örnek olarak toplanır (KVKK aydınlatma metni zorunlu).
10. **KVKK/GDPR:** Hesap silme, veri dışa aktarma, onay metinleri — Türkiye'de yayınlanacağı için kritik.

## 9. Riskler ve Azaltma

| Risk | Azaltma |
|------|---------|
| Vision API yemek tahmini yanlış olabilir | Porsiyon düzeltme UI'ı, çift yönlü düzenleme, örnek birikimi |
| AI maliyetleri tırmanabilir | Aylık kullanıcı kotası, düşük maliyetli model, önbellek |
| "Yayınlanan ürün" kapsamı büyük | Fazlı yaklaşım; her faz sonunda test edilebilir sürüm |
| Tek geliştirici yarı zamanlı, süre uzar | Kapsam kesimi (nice-to-have işaretleme) |

## 10. Değişiklik Günlüğü

| Tarih | Değişiklik |
|-------|------------|
| (ilk plan) | Plan oluşturuldu. |
| 2026-09-20 | F0 tamamlandı: Flutter+Supabase ortamı (kod iskeleti), feature-first klasör yapısı, bağımlılıklar, .env config, CI kuruldu. Gerçek Supabase proje bağlantısı (Task 8) kullanıcının proje oluşturup kimlik bilgilerini paylaşmasını bekliyor — ayrı olarak tamamlanacak. |
| 2026-09-20 | F1 (email/şifre bölümü) tamamlandı: kayıt/giriş/şifre sıfırlama, 10 soruluk onboarding sihirbazı, Mifflin-St Jeor TDEE + protein hedefi hesabı, auth/profil durumuna göre otomatik yönlendirme, TR/EN i18n altyapısı. Google Sign-In (F1'in bir parçası) ayrı bir görev olarak kullanıcının Google Cloud Console kurulumunu bekliyor. Gerçek Supabase projesi bağlantısı (F0 Task 8) hâlâ açık — uçtan uca manuel doğrulama bunu bekliyor. |
| 2026-09-21 | F1 uçtan uca manuel doğrulama tamamlandı: gerçek Supabase projesine bağlanıp kayıt, onboarding anketi, ana ekranda hedef gösterimi ve Google Sign-In tarayıcıda test edildi, hata görülmedi. Profil düzenleme ekranı F1 kapsamı dışında bırakıldı, F2+ için değerlendirilecek. |
| 2026-09-22 | F2 Vision API sağlayıcı kararı verildi: **Gemini 2.5 Flash-Lite** (kalıcı ücretsiz katman) + **USDA FoodData Central** ile iki aşamalı mimari (LLM sadece tanıma yapar, makro değerleri veritabanından çekilir). NVIDIA NIM (deneme kredili, kalıcı ücretsiz değil) ve Gemini 3.x Flash (API'de ücretsiz değil) elendi. Karar, açık kaynak `macroscanner` projesinin mimari dersleri ve akademik bir vision-LLM beslenme tahmini benchmark'ı ışığında verildi. |
| 2026-09-24 | **F2 (fotoğrafla besin takibi) tamamlandı ve master'a alındı.** 17 görev subagent-driven-development ile uygulandı: domain modelleri, `meals`/`meal_items` migration'ları + `meal-photos` storage bucket RLS, `MealRepository` + Riverpod state machine, kamera/galeri çekim + düzenleme ekranı, günlük öğün listesi (hedefe karşı kalori/protein/karbonhidrat/yağ), alt navigasyon, ve Gemini+USDA'yı orkestre eden 3 dosyalık Deno Edge Function. Her görev kendi spec+quality review'undan geçti (3 görev fix turu gerektirdi: i18n hardcode'ları, `analyzeMealPhoto`'nun eksik hata yakalama). Final whole-branch review 1 Critical (Gemini'nin Türkçe çıktısı USDA'nın İngilizce eşleştirmesiyle hiç örtüşmüyordu — özellik sessizce tama manuel girişe düşüyordu) + 10 Important bulgu buldu (state sızıntısı, kararsız widget key'leri, kcal/kJ karışıklığı, UTC olmayan zaman damgaları, Storage'da sahiplik kontrolü eksikliği, CORS eksikliği, eksik karbonhidrat/yağ gösterimi, vb.) — hepsi tek bir fix dalgasında düzeltildi; re-review'da path traversal ile atlatılabilen bir sahiplik kontrolü bulundu ve ayrıca kapatıldı. Son durum: 64/64 Flutter testi + 26/26 Deno testi yeşil, `flutter analyze` temiz. Gemini/USDA API anahtarları ve gerçek Edge Function deploy'u hâlâ kullanıcıyı bekliyor — uçtan uca manuel doğrulama (spor_takip/docs/superpowers/plans/2026-09-23-f2-meal-photo-tracking.md dosyasının sonundaki liste) o zaman yapılacak. Manuel giriş/arama (E3 epic'i) bilinçli olarak bu fazın dışında bırakıldı. |
| 2026-09-24 | F2 canlıya alındı: Gemini/USDA secret'ları ayarlandı, `analyze-meal-photo` deploy edildi, 0002/0003 migration'ları SQL Editor ile uygulandı. Uçtan uca testte birim testlerinin yakalayamadığı 3 üretim hatası bulunup düzeltildi: (1) Edge Function'ın Storage indirmesi `apikey` header'ı olmadan yeni `sb_secret_` anahtarını service_role olarak tanıtamıyordu ("Bucket not found"); (2) `gemini-2.5-flash-lite` yeni kullanıcılara kapatılmıştı → `gemini-3.5-flash-lite`; (3) USDA `/food/{id}` yanıtı iç içe `nutrient.name`/`amount` formatındaydı, kod arama endpoint'inin düz formatını okuyordu → tüm makrolar 0 geliyordu (test fixture'ı gerçek formata çevrildi). Sessizce yutulan hatalar artık Edge Function loglarına yazılıyor. Mutlu yol (fotoğraf → tanıma → USDA makroları → kaydet → günlük toplamlar) web'de doğrulandı. |
| 2026-09-25 | F2 uçtan uca manuel doğrulaması tamamlandı: `needs_review` ("Yiyecek ekle") ve çevrimdışı yükleme hatası akışları sorunsuz. İki hata bulunup düzeltildi: (1) EasyLocalization'da `startLocale` olmadığı için İngilizce tarayıcıda arayüz İngilizce açılıyordu → varsayılan Türkçe; (2) domates 0 kcal geliyordu: USDA araması besin değeri olmayan markalı bir kaydı seçiyordu ve Foundation kayıtlarında kalori yalnızca `Energy (Atwater ...)` adıyla bulunuyordu → arama POST ile markasız veri tiplerine (Foundation, SR Legacy, Survey (FNDDS)) sınırlandı, Atwater yedeği eklendi, tekil/çoğul eşleştirme eklendi ve Gemini sorguya çiğ/pişmiş bilgisini ekliyor ("tomato" artık "Tomato powder"a değil "Tomatoes, raw"a eşleşiyor). Domates yeniden test edildi, gerçekçi kalori geldi. **F2 kapandı; sıradaki faz F3.** |
