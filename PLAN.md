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
1. Fotoğraf çekilir → Supabase Storage'a yüklenir.
2. Edge Function → Vision modeli → `{yemek, porsiyon, makro önerisi}` döner.
3. Kullanıcı tahmini düzenler / onaylar.
4. Kaydedilir; yanlış tahminler yeni örnek olarak token etiketlenir (ileride ince ayar için).

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