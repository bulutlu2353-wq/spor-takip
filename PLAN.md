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
| F5+ | — | Görsel tasarım yenileme + oyunlaştırma (seviye, kazanılan unvanlar); kapsamı F5 sonrası ayrıca belirlenecek |
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
| 2026-09-26 | **F3 (antrenman programlama) tamamlandı** (`f3-programlama` dalı, 14 görev): 876 hareketlik kütüphane (free-exercise-db, sabit commit), 9 hazır program (yüzdelik 5/3/1 BBB, 5/3/1 Beginners, nSuns dahil), program kopyalama/özelleştirme/boştan oluşturma düzenleyicisi, hareket seçici (filtreler, detay, kendi hareketi), 1RM paneli, haftanın günleri ve rotasyon modları, ana ekranda "Bugün" kartı. 0004–0007 migration'ları SQL Editor ile uygulandı; `0005` (~810 KB) Editor'a tek parça yapıştırılınca bozulduğu için `--chunks 8` ile 8 parçada yüklendi. `checks/f3_rls_checks.sql` kullanıcıları kendisi seçen tek bir DO bloğuna çevrildi; sonuçlar: kopya 68 blok, hazır program değiştirilemiyor/silinemiyor, B kullanıcısı A'nın programlarını göremiyor ve `save_program` ile yazma RLS tarafından engelleniyor. Release web build'de 8 maddelik manuel kontrol listesinin tamamı geçti. Otomatik: 124 Flutter + 39 Deno testi geçiyor, `flutter analyze` temiz. Uygulama sırasında düzeltilenler: editör kaydında/detay aksiyonlarında yutulan hatalar loglanıp kullanıcıya gösteriliyor, özel hareket hataları seçicide gösteriliyor, "Tamamladım" hatası snackbar ile bildiriliyor. |
| 2026-10-01 | **F4a (antrenman oturumu ve set kaydı) tamamlandı** (`f4a-set-kaydi` dalı, 12 görev): tam ekran antrenman oturumu, set kaydı (kilo değişikliği alttaki setlere yayılıyor), dinlenme sayacı (+30 sn / Atla), yarım kalan oturumu sürdürme, oturuma hareket ekleme/çıkarma, bitiş özeti (süre, set, hacim), otomatik ilerleme (+deload) ve AMRAP'a dayalı 1RM önerileri, antrenman geçmişi. `0008_create_workout_sessions.sql` SQL Editor ile uygulandı; `checks/f4a_rls_checks.sql` beklenen tüm değerleri döndürdü. Release web build'de 11 maddelik manuel kontrol listesi F4b'ninkiyle birlikte yapıldı, kullanıcı sorun bildirmedi. Uygulama sırasındaki sapmalar: dinlenme sayacı etiketi taşma yüzünden kısaltılıyor ve Atla ikon butonu oldu; bir plan testi beklentisi düzeltildi (geçmiş setler kendi hedeflerine göre değerlendiriliyor). |
| 2026-10-01 | **F4b (ilerleme takibi) tamamlandı** (`f4b-ilerleme` dalı, 12 görev): ana sayfada haftalık özet (bu hafta Pzt–Paz ve geçen haftayla karşılaştırma), vücut ağırlığı, güç ilerlemesi (hareket başına tahmini 1RM) ve beden ölçüleri kartları ile bunların `fl_chart` grafikli ekranları. Kilo kaydı profil kilosunu ve TDEE/kalori hedefini güncelliyor, onboarding'deki kilo ilk kayıt oluyor. `0009` migration'ı (`body_weight_logs`, `body_measurements`, `log_body_weight` RPC, profillerden geri doldurma) uygulandı; `checks/f4b_rls_checks.sql` beklenen değerlerin tamamını döndürdü (geri doldurma, B kullanıcısı A'nın kayıtlarını göremiyor, en yeni kayıt silinince profil kilosu geri alınıyor, son kilo kaydı silinemiyor). 8 maddelik manuel kontrol listesinde kullanıcı sorun bildirmedi. Otomatik: 277 Flutter testi geçiyor, `flutter analyze` temiz. |
| 2026-10-03 | **F5 (AI antrenör sohbeti) kodu tamamlandı, sekme kilitli** (`f5-ai-antrenor` dalı, 13 görev): `coach-chat` Edge Function (Gemini, sağlayıcıdan bağımsız `LlmClient`, araç çağrıları + doğrulama), sohbet geçmişi, onay kartları (kilo, profil, amaç, öğün, set, program) ile Onayla/Vazgeç/Geri al, günlük mesaj limiti. `0010_create_coach_chat.sql` uygulandı; `checks/f5_rls_checks.sql` (bir parantez hatası düzeltildikten sonra) beklenen tüm değerleri döndürdü; `coach-chat` ve `analyze-meal-photo` CLI ile deploy edildi. Kullanıcı kararıyla 12 maddelik manuel liste **yapılmadı**: Antrenör sekmesi görünür ama `coachEnabledProvider = false` ile yalnız "Geliştirme aşamasında" tanıtım ekranı (yapabilecekleri listesi) gösteriliyor, model çağrılmıyor. Açmadan önce manuel liste yapılmalı. Otomatik: Flutter testleri + 85 Deno testi geçiyor, `flutter analyze` temiz. |
| 2026-10-04 | **F5+ R1 (tasarım temeli + ana sayfa) tamamlandı** (`r1-tasarim-temeli` dalı, 8 görev). F5+ üç ayrı projeye bölündü: görsel tasarım (R1–R4), kas haritası, oyunlaştırma. R1: yalnız koyu tema + neon yeşil (#C6FF00), gömülü Montserrat (başlık) / Inter (metin), ortak bileşenler (SectionHeader, StatTile, RingProgress, MacroBar), grafik renkleri temadan. Ana sayfa: tarih + saate göre selam, bugünkü kalori halkası ve makrolar, bugünkü antrenman, 2×2 özet kutuları (kilo, bu hafta, güç, ölçü → detay ekranları); eski hedef/kilo/güç/ölçü kartları kaldırıldı (ekleme butonları detay ekranlarında). Spec'ten sapmalar: buton metinleri büyük harf değil (Türkçe i/İ); kilo değişim rengi kullanıcının amacına göre; yazı tipleri ≈1,5 MB. Test uygulamasında Riverpod otomatik yeniden denemesi kapatıldı (hata durumları hemen görünsün). Otomatik: 351 Flutter testi geçiyor (kullanıcının terminalinde `-j 1`; bu makinede arka plan koşusu bellek yüzünden durduruldu), `flutter analyze` temiz. Manuel: release web build'de ilk açılışta tarayıcı önbelleğindeki eski çeviri dosyası yüzünden yeni metinler anahtar olarak göründü; önbellek temizlenince kullanıcı sorun bildirmedi. Sıradaki: R2 (beslenme ekranları). |
| 2026-10-04 | **F5+ R2 (beslenme ekranları) tamamlandı** (`r2-beslenme` dalı, 6 görev). Beslenme ekranı "kalan odaklı" düzende: tarih, KALAN/AŞIM/YENEN kartı (bar + protein/karb./yağ kutuları), öğün tipi başına ara toplamlı kartlar; boş günde kart kalır. Öğün ekleme: seçimde iki büyük kutu, düzeltmede fotoğraf önizleme, açılır yemek satırları, sabit toplam + Kaydet. Davranış düzeltmeleri: gram değişince kcal/makrolar orantılı güncellenir (gram başı oran istemcide tutulur, gram 0'a inse de kaybolmaz); "kontrol gerekli" yemekte ilk rakamda alanların kaybolması giderildi. `dayLabel` ortak yardımcıya çıkarıldı, `SectionHeader`'a `trailing` eklendi. Otomatik: 379 Flutter testi geçiyor (kullanıcının terminalinde `-j 1`), `flutter analyze` temiz. Manuel: release web build'de 9 maddelik kontrol listesinin tamamı geçti, kullanıcı sorun bildirmedi. Sıradaki: R3 (antrenman ekranları). |
| 2026-10-05 | **F5+ R3 (antrenman ekranları) tamamlandı** (`r3-antrenman` dalı, 7 görev). Antrenman oturumu: süre/set/hacim kutuları + ilerleme çubuğu, sütun başlıklı set tablosu, setleri biten hareket tek satıra katlanır (dokununca açılır), neon dinlenme şeridi. Özet: "Antrenman tamamlandı" başlığı, rakam kutuları, 1RM önerileri kart olarak, sabit Kaydet. Programlar: aktif program neon çerçeve + AKTİF etiketi, neon filtre çipleri; program detayında "Aktif yap" ana buton. Geçmiş: haftalık "bu hafta / geçen hafta" tablosu ana sayfadan buraya taşındı (antrenman/set/hacim artışı neon), oturum kartlarında tarih · süre · hacim (yıl yalnız farklıysa); geçmiş detayında tarih · program satırı ve rakam kutuları. Yeni ortak bileşenler: `StatBox`/`StatBoxRow`, `AccentChip`. Otomatik: 389 Flutter testi geçiyor (kullanıcının terminalinde `-j 1`), `flutter analyze` temiz. Manuel: web release derlemesinde 9 maddelik kontrol listesi sorunsuz. Sıradaki: R4 (ilerleme ekranları, antrenör, giriş/kayıt/onboarding). |
| 2026-10-05 | **F5+ R4a (ilerleme ekranları) tamamlandı** (`r4a-ilerleme` dalı, 5 görev). R4 ikiye bölündü (R4a ilerleme, R4b antrenör + giriş/kayıt/onboarding). Kilo, güç ve ölçüler ekranları "büyük sayı üstte" düzeninde: güncel değer + seçili aralıktaki değişim (kiloda renk hedefe göre, güçte artış neon, ölçüde gri), "TREND" kartında 1A/3A/1Y/Tümü çipleri, "KAYITLAR" kartında satır başına fark ve "4 Ekim" biçiminde tarih. Yeni bileşenler: `ProgressHero`, `ChartCard`; `RangeSelector` kaldırıldı; kısa tarih `lib/shared/date_label.dart`'a taşındı. Otomatik: 398 Flutter testi geçiyor (kullanıcının terminalinde `-j 1`), `flutter analyze` temiz. Manuel: web release derlemesinde 8 maddelik kontrol listesi sorunsuz. Sıradaki: R4b (antrenör, giriş/kayıt/onboarding). |
| 2026-10-07 | **F5+ R4b (giriş/kayıt, onboarding, antrenör) tamamlandı — F5+ görsel yenileme bitti** (`r4b-giris-koc` dalı, 4 görev). Giriş/kayıt ortalanmış logo düzeninde (`AuthHeader`: neon "S", "SPOR TAKİP", slogan; "veya" ayracı). Onboarding: parçalı neon adım çubuğu, "ADIM x/y", ikonlu seçim kartları, büyük ortalı sayı + birim (kg/cm/gün). Antrenör tanıtımı: neon rozet, 3 satırlık başlık, 2×3 özellik kutuları; sohbet: neon kullanıcı balonu, kart AI balonu, neon gönder butonu (sekme hâlâ kilitli). Davranış değişmedi; `auth.login_title`/`register_title` kaldırıldı. Otomatik: 404 Flutter testi geçiyor (kullanıcının terminalinde `-j 1`), `flutter analyze` temiz. Manuel: web release derlemesinde 8 maddelik kontrol listesi sorunsuz. Kullanıcı notu: hedeflerde "kilo almak" yok ve aynı anda birden fazla hedef (ör. kas + kilo verme) seçilebilmeli — ayrı tasarım olarak ele alınacak. Sıradaki: hedefler tasarımı, ardından F5+ 2. alt proje (kas haritası). |
| 2026-10-07 | **G1 (hedef çekirdeği) tamamlandı** (`g1-hedefler` dalı, 5 görev). Tek `goal` alanı iki eksene ayrıldı: kilo yönü (ver / koru / al) + hız (yavaş / dengeli / hızlı, korumada yok) ve çoklu odak (kas, güç, dayanıklılık, genel sağlık). Kalori artık hıza göre: günlük fark = kilo × haftalık oran × 7700 / 7 (ver %0.5/0.75/1, al %0.25/0.35/0.5), taban erkek 1500 / diğer 1200 ama hedef TDEE'yi aşmaz; protein kilo verirken 2.2, kas/güç odağında 2.0, diğerlerinde 1.6 g/kg. Migration `0011` mevcut kayıtları taşıdı (kilo verenlere dengeli açık), `goal` sütunu kaldırıldı; koç `set_goal` hedefin tamamını taşıyor, G1 öncesi koç önerileri uygulanamıyor/geri alınamıyor. Onboarding'e yön → hız (≈kg/hafta alt yazısı) → odak (çoklu seçim) adımları eklendi. Otomatik: 417 Flutter testi (kullanıcının terminalinde `-j 1`), 56 Deno testi, SQL kontrolleri geçiyor, `flutter analyze` temiz; `coach-chat` yeniden deploy edildi. Manuel: web release derlemesinde 8 maddelik kontrol listesi sorunsuz. Sıradaki: G2 (Profil/Ayarlar ekranı: profil alanları + hedef düzenleme, çıkış butonu oraya), sonra adaptif kalori (tartı trendine göre düzeltme) ayrı faz. |
| 2026-10-07 | **G2 (profil/ayarlar + LevelUp Fit) tamamlandı** (`g2-ayarlar` dalı, 6 görev). Ana ekrandaki çıkış butonu yerine dişli → Profil ve ayarlar ekranı: hedef kartı (yön · hız, odaklar, haftalık tahmin, kcal/protein), profil satırları (kilo → kilo ekranı; boy, doğum yılı, cinsiyet, aktivite, spor, sağlık notları alt sayfalarda), dil seçimi (TR/EN, kalıcı), hesap (e-posta, onaylı çıkış). Hedeflerim ekranı yön/hız/odak düzenler; alt sayfalar ve Hedeflerim yeni hedefi canlı önizler. Yalnız değişen sütunlar yazılır; hedefler sadece hedefi etkileyen bir alan değişince yeniden hesaplanır, kilo ayarlardan yazılmaz. Seçim kartı ve büyük sayı girişi onboarding ile ortak widget oldu. Uygulama "LevelUp Fit" oldu: rütbe şeridi logosu (`AppLogo`), "LEVELUP FIT" yazısı, web/Android/iOS adları ve `tool/generate_icons.py` ile üretilen ikonlar. Migration/deploy yok. Otomatik: 438 Flutter testi (kullanıcının terminalinde `-j 1`), `flutter analyze` temiz. Manuel: web release derlemesinde 10 maddelik kontrol listesi sorunsuz. Sıradaki: adaptif kalori (tartı trendine göre düzeltme) ya da F5+ kas haritası. |
| 2026-10-08 | **G3 (uyarlanabilir kalori hedefi) tamamlandı** (`g3-uyarlanabilir-kalori` dalı, 7 görev). Beslenme ekranında Kalan kartının üstüne onaylı öneri kartı: son 21 günün kilo trendi (doğrusal regresyon) ve öğün kayıtlarından gerçek TDEE tahmini — günlerin ≥%70'i ≥800 kcal kayıtlıysa enerji dengesi (ortalama alım − eğim × 7700), değilse kilo trendi (gerçek hız − hedef hız). En az 6 kilo kaydı/14 gün ve son hedef değişikliğinden 14 gün gerekir; fark <100 kcal ise öneri yok, öneri başına en çok ±250 kcal, cinsiyet tabanı korunur. Uygula → düzeltme profilde pay olarak (`calorie_adjustment_kcal`) saklanır ve tartı/ayar/koç hesaplarında korunur, aktivite değişince sıfırlanır; Şimdi değil → 7 gün gizler. Ayarlar hedef kartında "Uyarlandı" satırı, Hedeflerim'de onaylı "Uyarlamayı sıfırla"; koç bağlamı payı görür. Migration `0012` (4 sütun + koç uygulama/geri alma) uygulandı, `coach-chat` yeniden deploy edildi. Otomatik: 475 Flutter testi (kullanıcının terminalinde `-j 1`), 57 Deno testi, `g3_checks` ve `f5_rls_checks` SQL kontrolleri geçiyor, `flutter analyze` temiz. Manuel: web release derlemesinde örnek veriyle 8 maddelik kontrol listesi sorunsuz. Sıradaki: F5+ kas haritası ya da oyunlaştırma. |
| 2026-10-09 | **F5+ K1 (kas haritası) tamamlandı** (`f5p-kas-haritasi` dalı, 7 görev). Antrenman sekmesinde figür ikonu → Kas haritası ekranı: 2D ön/arka erkek figürü (ÖN/ARKA geçişi, seçim korunur), kasa dokununca o kası birincil çalıştıran hareketler (başlık + sayı), "İkincil dahil" ile genişletme, satırdan detay sayfası. Hareket seçicide "Haritadan seç" alt sayfası listeyi seçilen kasa süzer. Yollar MIT lisanslı react-native-body-highlighter verisinden `tool/generate_muscle_paths.py` ile üretildi (ön 88, arka 69 bölge); lisans `LICENSES/body-highlighter.txt` olarak Flutter lisans kaydına eklendi. Plandan sapma yok. Migration/deploy yok. Otomatik: 500 Flutter testi (kullanıcının terminalinde `-j 1`), `flutter analyze` temiz. Manuel: web release derlemesinde 8 maddelik kontrol listesi sorunsuz. Sıradaki: K2 (kadın figürü, ısı haritası, programdan haritaya, Stitch ile yerleşim) ya da oyunlaştırma. |
| 2026-10-09 | **F5+ K2 (kas haritası: kadın figürü + yerleşim) tamamlandı** (`f5p-kas-haritasi-k2` dalı, 6 görev). Kadın figürü eklendi (react-native-body-highlighter, aynı üretici); profil cinsiyetine göre varsayılan figür, ♂/♀ geçişi oturum boyunca korunur ve ekrandan alt sayfaya taşınır. Kas haritası ekranı, "Haritadan seç" alt sayfası ve hareket seçici Stitch taslaklarına göre yeniden düzenlendi (figür kartı + parlama, başlık/kapatma, arama temizleme, sonuç sayısı, ekipman ikonları, ÖZEL rozeti). Manuel kontrolde figür çok koyu bulundu; kas/süs/kontur renkleri `onSurfaceVariant` tabanlı açıldı. Sapmalar: tek provider yerine seçim + varsayılan provider ikilisi; seçici listesi tembel ListView, satır başına kart; "Haritadan seç" `ActionChip`; ÖN/ARKA ile ♂/♀ satırında taşma için `Flexible`+`FittedBox`. Migration/deploy yok. Otomatik: 519 Flutter testi (kullanıcının terminalinde `-j 1`), `flutter analyze` temiz. Manuel: web release derlemesinde 8 maddelik kontrol listesi sorunsuz. Sıradaki: ısı haritası / programdan haritaya ya da oyunlaştırma. |
| 2026-10-09 | **F5+ K3 (kas haritası: ısı haritası + programdan haritaya) tamamlandı** (`f5p-kas-haritasi-k3` dalı, 6 görev). Kas haritası ekranına KEŞFET / ISI geçişi: ISI modunda son 7 / 30 günün tamamlanmış setleri kaslara dağıtılır (birincil 1, ikincil 0,5), haftalık yük mutlak eşiklerle (4 / 10 / 20) dört lime tonuna boyanır; lejant, kas başına set özeti ve yapılan hareketlerin set sayılı listesi. Program detayında "ÇALIŞAN KASLAR" mini kartı (ön + arka figür, planlı set ısısı); dokununca harita program modunda (`/workout/muscles?program=<id>`) açılır, kasa dokununca program hareketleri planlı setleriyle listelenir. Veri mevcut geçmiş (son 100 oturum) ve program sağlayıcılarından; yeni sorgu yok. Sapmalar: `ExerciseLoad.sets` int; mini kart programı doğrudan kullanır; `formatSets` domain'de; mini karttaki lejant taşmasın diye `FittedBox`. Migration/deploy yok. Otomatik: 544 Flutter testi (kullanıcının terminalinde `-j 1`), `flutter analyze` temiz. Manuel: web release derlemesinde 8 maddelik kontrol listesi sorunsuz. Sıradaki: oyunlaştırma ya da yeni özellik. |
