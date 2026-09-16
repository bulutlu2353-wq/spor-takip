# F0 — Repo & Ortam Kurulumu — Tasarım Spec'i

> Kapsam: Sadece PLAN.md'deki F0 fazı ("Repo, Flutter + Supabase kurulumu, CI (analyze/test), temel mimari"). Gerçek özellikler (onboarding, beslenme takibi, antrenman, chat) bu spec'in dışındadır ve F1'den itibaren ayrı spec'lerle ele alınacaktır.

## 1. Bağlam

`PLAN.md` projenin genel vizyonunu, epic'lerini (E1-E9) ve faz planını (F0-F7) tanımlıyor. Bu doküman F0 fazının uygulama tasarımını detaylandırır.

Proje daha önce `opencode` CLI aracıyla başlatılmış: PLAN.md o oturumda onaylanan kararlarla yazıldı (bkz. Değişiklik Günlüğü altındaki karar özeti aşağıda). OpenCode F0'ya başlamış ama Flutter SDK indirmesi ortasında kesintiye uğramıştı.

### Onaylanan kararlar (OpenCode oturumundan, ilk onay)
- Fotoğrafla kalori/protein takibi: **bulut AI API** (GPT-4o Vision / Gemini gibi)
- Backend: **Supabase**
- Chat: **hem AI antrenör önerisi hem de veri düzenleme** ("her ikisi de")
- Proje kapsamı: **yayınlanacak bir ürün** (store'a çıkacak, sadece öğrenme projesi değil)

### Bu spec sürecinde onaylanan ek kararlar
- Mobil teknoloji: **Flutter/Dart** (kesinleştirildi)
- Supabase projesi: **henüz yok, birlikte kurulacak**
- Hedef platform: **Android + iOS** baştan (iOS gerçek build/test'i için ileride Mac/Codemagic gerekecek)
- Klasör mimarisi: **feature-first**
- F0 iş bölüşümü: **OpenCode = ağır SDK kurulumu (arka plan), Claude Code = proje iskeleti**

## 2. Ortam Durumu (tespit edilen)

- **Flutter/Dart:** kurulu değil
- **Git:** kurulu (2.55.0)
- **Java:** 1.8.0_51 (eski; Android Gradle build'leri için JDK 17 gerekiyor)
- **Android SDK:** kurulu değil
- **Disk:** C: sürücüsünde sadece ~800MB boş alan var (kritik kısıt) — D: sürücüde ~110GB boş. **Tüm SDK kurulumları (Flutter, Android SDK, JDK) D: sürücüsüne yapılacak** (örn. `D:\flutter`, `D:\android-sdk`).
- OpenCode'un daha önce başlattığı Flutter indirmesi (`%TEMP%\flutter_stable.zip`) yarım kalmış (11.6MB / ~1GB) — geçersiz, yeniden indirilmesi gerekiyor.

## 3. Görev Bölüşümü ve Mimari

### 3.1 OpenCode CLI (arka planda, `opencode run`)
Sorumluluğu: geliştirme ortamının SDK katmanı.
1. Flutter SDK'yı `D:\flutter`'a indir/kur, PATH'e ekle, doğrula (`flutter doctor`).
2. Android command-line tools + platform-tools + gerekli platform/build-tools'u `D:\android-sdk`'ya kur.
3. JDK 17'yi kur (Android Gradle build'leri için).
4. `flutter doctor` çıktısını raporla.

Bu iş uzun sürebilir (büyük indirmeler) ve tekrar denemeye açık olduğu için arka planda, ana konuşmayı bloklamadan çalışacak.

### 3.2 Claude Code (bu oturum)
Sorumluluğu: proje iskeleti ve mimari, SDK hazır olduktan sonra.
1. `flutter create` ile proje oluştur (Android+iOS target'larıyla).
2. Feature-first klasör yapısını kur:
   ```
   lib/
     core/       (tema, router, supabase client, utils)
     features/
       onboarding/
       nutrition/
       workout/
       chat/
       progress/
       settings/
     shared/     (ortak widget'lar)
   ```
   Her feature klasörü kendi `presentation/`, `application/` (Riverpod provider'ları), `domain/`, `data/` alt klasörlerine sahip olacak — ama F0'da bunlar sadece iskelet (placeholder dosyalar), gerçek kod F1+'da gelecek.
3. Bağımlılıkları ekle: `flutter_riverpod`, `supabase_flutter`, `go_router` (routing), `flutter_dotenv` (env yönetimi).
4. `.env` dosyası (gitignore'lu) + `.env.example` — Supabase URL/anon key için.
5. Git: bu proje deposu zaten başlatıldı (bu spec sürecinde); Flutter projesi oluşunca uygun `.gitignore` (Flutter şablonu) eklenip ilk anlamlı commit yapılacak.
6. CI: `.github/workflows/ci.yml` — push/PR üzerinde `flutter analyze` + `flutter test` çalıştıracak.
7. Doğrulama: `flutter analyze` hatasız, `flutter test` (varsayılan widget testiyle) geçmeli.

### 3.3 Supabase kurulumu (kullanıcı + Claude Code birlikte)
1. Kullanıcı tarayıcıdan yeni Supabase projesi oluşturur.
2. Proje URL + anon key kullanıcıdan alınır, `.env`'e yazılır (asla commit edilmez, asla koda gömülmez).
3. Claude Code `supabase_flutter` init kodunu (`core/supabase_client.dart` gibi) yazar.
4. Gerçek tablo şemaları/migration'lar F1 kapsamında — F0'da sadece bağlantı kurulur, boş proje yeterlidir.

## 4. Kapsam Dışı (F0'da yapılmayacak)

- Onboarding formu, TDEE hesaplama (F1)
- Fotoğraf/AI entegrasyonu (F2)
- Antrenman programları, set takibi (F3-F4)
- AI chat (F5)
- Supabase tablo şemaları / RLS politikaları (F1'den itibaren, ihtiyaç doğdukça)
- iOS gerçek build/test (Mac/Codemagic olmadan mümkün değil; kod iki platformu da hedefleyecek şekilde yazılır ama F0'da yalnızca Android üzerinde `flutter run`/`flutter test` doğrulanır)

## 5. Test Stratejisi (F0)

- `flutter analyze`: sıfır hata/uyarı hedefi.
- `flutter test`: varsayılan/placeholder widget testi CI'da yeşil.
- Gerçek özellik testleri, ilgili özellik F1+'da geliştirildiğinde yazılacak (TDD).

## 6. Riskler

| Risk | Azaltma |
|------|---------|
| C: sürücüsü dolması | Tüm SDK/araçlar D:'ye kurulur; C:'ye yazma öncesi boş alan kontrol edilir |
| OpenCode indirmesi tekrar kesilir | Arka planda, yeniden başlatılabilir; Claude Code ilerlemeyi kontrol eder |
| Android SDK lisans onayları interaktif kilitlenme | `sdkmanager --licenses` otomasyonu / batch onay kullanılacak |
| Flutter+Android SDK kurulumu uzun sürer, iskelet işini bloklar | İki iş paralel: iskelet klasör/CI dosyaları SDK'ya ihtiyaç duymadan hazırlanabilir; sadece `flutter create`/`flutter analyze` SDK bekler |
