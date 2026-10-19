# O2 cila — Canavar görsellerine durum, kadraj ve vuruş animasyonu

Tarih: 2026-10-19 · Dal: `o2-cila` (master `d21f9e8`'den) · Önceki: O2a (canavar savaşı çekirdeği)

## 1. Amaç

O2a'da 16 foto-gerçekçi canavar portresi eklendi (`assets/monsters/<id>.jpg`, 512×512). Portreler her yerde aynı görünüyor; yolda yalnızca satır opaklığı değişiyor ve antrenman sonrası hiçbir geri bildirim yok. Bu iş:

1. portreleri canavarın durumuna göre gösterir (yenildi / sisli / canı az),
2. her portreyi daire içinde doğru kadrajlar, vinyet ve aşama halkası ekler,
3. ana sayfa kartında görülmemiş vuruşlar için vuruş ve yenilme animasyonu oynatır,
4. küçük portreleri ekran boyutunda çözer.

Kapsam dışı: savaş ekranında animasyon, ses, karakterler/avatar (O2b), sunucu tarafı. Migration yok.

## 2. Portre bileşeni (`MonsterAvatar`)

`MonsterAvatar({required int index, double size = 64, MonsterLook look = MonsterLook.normal})`.

```dart
enum MonsterLook { normal, defeated, fogged, lowHp }
```

Katmanlar (alttan üste), hepsi `size` çaplı daire içinde:

1. **Görsel**: `Image.asset(imageAsset, cacheWidth: (size * devicePixelRatio).ceil())`, kadraj §3'e göre. Görsel yoksa O2a'daki yer tutucu (aşama simgesi + baş harf) aynen kalır.
2. **Duruma göre filtre**:
   - `defeated`: gri tonlama (`ColorFilter.matrix`, luminans), %60 opaklık.
   - `fogged`: `ImageFiltered(blur σ = size × 0.08)` + %55 siyah örtü; ortada aşama renginde "?" (`size × 0.4` punto, kalın).
   - `normal`, `lowHp`: filtre yok.
3. **Vinyet**: `RadialGradient` (merkez saydam → kenar %70 siyah, durak 0.6 → 1.0). Her durumda.
4. **Mühür** (`defeated`): çapraz (−20°) kırmızı çerçeveli "YENİLDİ" etiketi (`gamification.battle.stamp`), genişlik `size × 0.9`. `size < 56` ise metin yerine kırmızı `Icons.close`.
5. **Halka**: aşama rengi (§4), kalınlık `max(2, size × 0.04)`, aynı renkte `BoxShadow` parıltısı (blur `size × 0.12`). `defeated`'da halka gri, parıltısız. `lowHp`'de halka kırmızıdır (`colorScheme.error`) ve 1,2 sn'lik ileri-geri `AnimationController` ile parıltı 0 ↔ `size × 0.2` atar (nabız). `MediaQuery.disableAnimations` açıksa nabız durur, kırmızı halka kalır.

Anahtar: `monster_avatar_<id>` (O2a ile aynı). Durum testleri için ek anahtarlar: `monster_stamp`, `monster_fog`, `monster_pulse`.

## 3. Kadraj

`Monster`'a iki alan eklenir: `focus` (`Alignment`, varsayılan `Alignment.center`) ve `zoom` (`double`, varsayılan `1.0`). Görsel `Transform.scale(scale: zoom, alignment: focus)` ile büyütülüp daireye kırpılır; `zoom < 1` desteklenmez (görselin kenarı görünür), en az 1.0.

Değerler uygulama sırasında görsellere bakılarak belirlenir; amaç yüzün ve gözlerin dairenin ortasına yakın, 44 px'te seçilebilir olması. Geniş kompozisyonlar (hidra, ejderha, behemot) 1.0'da kalır; büst portreler (goblin, ork, lich, titan, kiklop) yüze doğru 1.15–1.3 yakınlaştırılır.

## 4. Aşama renkleri

O2a'daki yer tutucu renkleri (yeşil/mavi/mor/kırmızı) yerine metal tonları, hem halka hem yer tutucu için:

| Aşama | Rütbeler | Renk |
|---|---|---|
| 1 | bekçi 0–3 | bronz `#CD7F32` |
| 2 | bekçi 4–7 | gümüş `#C0C7D0` |
| 3 | bekçi 8–11 | mor `#9C4DFF` |
| 4 | bekçi 12–14 + sonsuz boss | altın `#FFC83D` |

## 5. Durumun seçimi

- **Ana sayfa kartı ve savaş ekranı başlığı**: aktif canavar; `hpLeft / hp < 0.3` ise `lowHp`, değilse `normal`.
- **Canavar yolu** (`active = guardiansBeaten`):
  - `i < active` → `defeated`; ad görünür. Satır opaklığı kaldırılır (görsel zaten soluk).
  - `i == active` → `normal` ya da `lowHp` (yukarıdaki kural).
  - `i == active + 1` → `fogged`; **ad görünür**.
  - `i > active + 1` → `fogged`; ad yerine `???` (`gamification.battle.unknown`).
  - Rütbe alt satırı ve kilit/tik simgeleri O2a'daki gibi kalır.
- Yol satırı anahtarları (`battle_path_done_/active_/locked_<id>`) değişmez.

Saf yardımcılar (`battle_widgets.dart`): `MonsterLook activeLook(BattleState)` ve `bool pathNameVisible(int i, int active)`.

## 6. Vuruş animasyonu (yalnız ana sayfa kartı)

### 6.1 Görülen vuruş

Cihazda `gamification.battle_seen_hit` anahtarıyla en son görülen vuruşun tarihi (ISO 8601) saklanır (`activeTitleKey` ile aynı desen: `SharedPreferences`, hata yutulur). Hesap cihaz düzeyindedir; aynı cihazda hesap değişirse en kötü ihtimalle bir animasyon atlanır ya da bir kez oynar.

Saf fonksiyon (`domain/battle.dart`):

```dart
/// [seen]'den sonraki vuruşlar, eskiden yeniye. [seen] null → boş (ilk açılış).
List<BattleHit> unseenHits(BattleState state, DateTime? seen);
```

`state.recent` yeniden eskiye ve en çok 10 vuruş olduğu için, 10'dan fazla görülmemiş vuruş varsa yalnız son 10'u hesaba katılır (kabul edilen sınır).

### 6.2 Oynatma

`HomeBattleCard` `ConsumerStatefulWidget` olur. Savaş durumu her geldiğinde:

1. Görülen tarih okunur. Değer yoksa (ilk açılış) en yeni vuruş tarihi yazılır, animasyon oynamaz.
2. `unseenHits` boşsa bir şey olmaz.
3. Doluysa en yeni vuruşun tarihi hemen yazılır (animasyon yarıda kalsa da tekrar oynamaz), sonra animasyon başlar. `MediaQuery.disableAnimations` açıksa yalnız yazılır, animasyon oynamaz.

Toplam hasar `Σ damage`; herhangi birinde `critShare > 0` ise kritik.

**Yenilme yoksa** (hiçbir görülmemiş vuruşta `defeated` dolu değil), ~1,2 sn:
- Portre 400 ms sarsılır (yatay `sin` ofseti, genlik 6 px, sönümlü) ve üstünde kırmızı örtü %50 → 0 söner.
- Portrenin üstünden "−340" (kritikse "−340 · KRİTİK!", `gamification.battle.hit_crit`) yukarı kayarak (40 px) ve sönerek uçar; kırmızı, kalın.
- Can çubuğu `(damage − Σ) / hp`'ten (alt sınır 0) güncel değere 800 ms'de kayar.

**Yenilme varsa**, ~2,4 sn:
- Önce kart içeriği yerine yenilme anı: yenilen son bekçinin portresi (`size 72`) sarsılır, ardından `defeated` görünümüne geçer (mühür 300 ms'de ölçek 1.6 → 1.0 ile "vurulur"), yanında "{ad} yenildi!" (`gamification.battle.defeated`, O2a'da var).
- 1,2 sn sonra yeni aktif canavar 400 ms'de soluklaşarak (fade + ölçek 0.8 → 1.0) belirir; can çubuğu tamdan güncel değere kayar, hasar sayısı uçmaz.
- Görülmemiş vuruşlarda birden çok canavar yenildiyse yalnız sonuncusu gösterilir.

Animasyon sırasında karta dokunmak savaş ekranını açar (animasyon iptal olur). Kart ağaçtan çıkarsa kontrolcüler atılır.

## 7. Metinler

Yeni anahtarlar (`tr` / `en`):

| Anahtar | tr | en |
|---|---|---|
| `gamification.battle.stamp` | YENİLDİ | DEFEATED |
| `gamification.battle.unknown` | ??? | ??? |
| `gamification.battle.hit_crit` | −{n} · KRİTİK! | −{n} · CRIT! |

## 8. Hata durumları

- Görsel yüklenemezse yer tutucu; durum filtreleri ve halka yer tutucuya da uygulanır.
- `SharedPreferences` okunamaz/yazılamazsa animasyon oynamaz (ilk açılış gibi davranır), kart normal görünür.
- Savaş verisi yokken kart O2a'daki gibi görünmez; animasyon durumu sıfırlanır.

## 9. Testler

- `monsters_test`: her canavarın `zoom ≥ 1`, `focus` −1…1 aralığında.
- `battle_test`: `unseenHits` — null → boş; tarih eşit → boş; daha yeni iki vuruş eskiden yeniye döner.
- `battle_widgets_test`: her `look` için anahtarlar (`monster_stamp` yalnız `defeated`, `monster_fog` yalnız `fogged`, `monster_pulse` yalnız `lowHp`); `activeLook` %30 sınırı; `pathNameVisible` (active, active+1 açık; active+2 gizli); `cacheWidth` verilir.
- `battle_screen_test`: yolda yenilenler mühürlü, sıradaki adlı ve sisli, ötesi `???`.
- `home_battle_card_test` (mock `SharedPreferences`): ilk açılış → animasyon yok, tarih yazılır; görülmemiş vuruş → uçan hasar metni görünür, sonra kaybolur; yenilme → "yenildi!" metni görünür, sonra yeni canavar; `disableAnimations` → animasyon yok.

Elle kontrol (web release): yolda sis/mühür/ad gizleme, kartta canı az nabzı, antrenman sonrası ana sayfaya dönünce vuruş animasyonu, bir bekçi yenilince yenilme anı, 44 px'te yüzlerin seçilebilirliği, İngilizce metinler.
