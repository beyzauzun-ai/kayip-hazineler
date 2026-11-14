# Ses kaynakları ve lisans — Kayıp Hazineler: Son 120 Saniye

## Özet

Bu klasördeki seslerin **biri dışında tamamı bu proje için özgün olarak, kodla
üretilmiştir.** Tek istisna, oyunda çalan deniz dalgası sesi `amb_waves_beach.wav`
dosyasıdır: Freesound'daki CC0 (kamu malı) lisanslı gerçek bir kıyı kaydından
hazırlanmıştır (ayrıntılar aşağıda). Lisansı belirsiz ses yoktur.

## Üçüncü taraf kayıt: deniz dalgası (`amb_waves_beach.wav`)

- Ses: **Gentle Waves - Quiet Beach**
- Yükleyen: **amholma** (Freesound kullanıcı adı)
- Kaynak: https://freesound.org/people/amholma/sounds/376795/
- Lisans: **Creative Commons 0 (CC0 1.0)** — https://creativecommons.org/publicdomain/zero/1.0/
  (lisans 2026-11-03, 2026-11-04 ve 2026-11-14'te ses sayfasından doğrulandı)
- Kayıt yeri: Destin, Florida (ses sayfasındaki açıklamadan); yükleme tarihi: 15 Ocak 2017
- Orijinal dosya: `376795__amholma__gentle-waves-quiet-beach.wav` — 48 kHz, 24 bit,
  stereo, 1:40,7 (SHA256 `4D48AC0A2B039F77858CA15AF2D9A57EB1921BCBAD1F10ADA445FCD5497E1124`).
  Orijinal dosya projeye eklenmemiştir.
- Kullanılan bölüm: orijinal kaydın yaklaşık **26–71. saniyeleri** (45 sn, döngü
  geçişi için 71–74. saniyeler de kullanıldı).
- Uygulanan işlemler:
  - Frekans temizliği: ~110 Hz altı (derin uğultu) azaltıldı, ~9 kHz üstü (tiz
    hışırtı) yumuşatıldı.
  - Dinamik dengeleme: yavaş bir sıkıştırıcıyla ani dalga çarpmaları kısıldı;
    ortalama seviye ~−30 dBFS, tepe ~−8 dBFS.
  - Yumuşak döngü geçişi: sondaki 3 sn başa eşit güçle bindirildi (kesintisiz döngü).
- Sonuç dosyası: `amb_waves_beach.wav` — 45 sn, 48 kHz, 16 bit, stereo.
- CC0 atıf zorunluluğu getirmez; yükleyen ses sayfasında atıf rica ettiği için ve
  şeffaflık amacıyla kaynak burada belirtilmiştir.

## Projeye özgü sesler (kodla üretilen)

Aşağıdaki bilgiler deniz dalgası dışındaki tüm sesler ve müzikler içindir.

Önceki sentetik dalga sesi `amb_waves.wav` artık oyunda çalınmaz; dosya silinmeden
korunmaktadır.

- Üretim yöntemi: prosedürel sentez (sinüs/üçgen/kare dalgalar, ses zarfı,
  filtrelenmiş gürültü, harmonik olmayan çan kısmileri, basit Schroeder yankısı).
- Araç: yalnızca Python standart kütüphanesi (`math`, `random`, `wave`, `struct`).
- Script'ler:
  - `tools/onayli_ses_ornekleri.py` — kullanıcının dinleyip onayladığı üç örneğin
    değiştirilmemiş üretim kodu.
  - `tools/generate_audio.py` — kalan seslerin üretimi ve onaylı seslerin birebir
    doğrulaması (`--dogrula`).
- Her ses sabit bir tohumla (9101–9215) üretilir; script tekrar çalıştırıldığında
  aynı dosyalar oluşur.
- Format: WAV, mono, 16 bit. Müzik ve döngüler 32 kHz, efektler 44,1 kHz.
- Hak sahibi: © 2026 Beyza Uzun, tüm hakları saklıdır. Bu sesler ve müzikler MIT
  lisansı kapsamında değildir.
- Bu sesleri üreten `tools/` altındaki Python betikleri kaynak koddur ve deponun
  MIT lisansı kapsamındadır (bkz. `LICENSE`).

## Dosyalar

| Dosya | Tür | Süre | Üretim | Oyundaki olay |
|---|---|---|---|---|
| `music_main.wav` | müzik, döngü | 19,2 sn | onaylı örnek (`ornek_korsan_muzigi`) | Ana menü ve deniz görevi |
| `music_auction.wav` | müzik, döngü | 18,7 sn | generate_audio | Açık artırma ve sonuç ekranı |
| `amb_waves_beach.wav` | ortam, döngü | 45 sn | CC0 gerçek kayıt (amholma, yukarıya bkz.) | Sürekli deniz dalgaları (menü, deniz görevi, açık artırma) |
| `amb_waves.wav` | ortam, döngü | 24 sn | ilk onaylı örnek (`ornek_deniz_dalgalari`) | Kullanılmıyor (yerini `amb_waves_beach` aldı); korunuyor |
| `amb_wind.wav` | ortam, döngü | 20 sn | generate_audio | Kullanılmıyor (gerçek dalganın üstüne yapay hışırtı ekliyordu); korunuyor |
| `ship_water.wav` | döngü | 4 sn | generate_audio | Pruva suyu: durgunken sessiz, hızla hafifçe yükselir (−15 dB) |
| `ship_creak.wav` | efekt | 0,7 sn | generate_audio | Kalkış ve sert dönüşte ahşap gıcırtısı |
| `rock_hit.wav` | efekt | 0,6 sn | generate_audio | Kayalığa çarpma |
| `discovery_bell.wav` | efekt | 1,8 sn | generate_audio | Batık keşfi |
| `extract_loop.wav` | efekt | 3,1 sn | generate_audio | E basılıyken çıkarma (bırakılınca kesilir) |
| `extract_fail.wav` | efekt | 0,75 sn | generate_audio | Çıkarma yarıda kaldı |
| `treasure_success.wav` | efekt | 2,6 sn | onaylı örnek (`ornek_hazine_bulma`) | Eser bulundu |
| `ui_denied.wav` | efekt | 0,3 sn | generate_audio | İpuçları ("Önce gemiyi durdur!", "3/3 eser gerekli" vb.) |
| `timer_warning.wav` | efekt | 1,4 sn | generate_audio | 20 saniye kaldı |
| `timer_tick.wav` | efekt | 0,12 sn | generate_audio | Son 10 saniyede her saniye |
| `mission_win.wav` | efekt | 2,4 sn | generate_audio | Üç eserle limana varış |
| `mission_lose.wav` | efekt | 2,4 sn | generate_audio | Süre doldu |
| `auction_waiting.wav` | efekt | 1,25 sn | generate_audio | "Daha Yüksek Teklif Bekle" |
| `auction_new_offer.wav` | efekt | 0,9 sn | generate_audio | Teklif yükseldi |
| `auction_sold.wav` | efekt | 1,3 sn | generate_audio | Satıldı (elle ya da otomatik) |
| `auction_buyers_left.wav` | efekt | 1,3 sn | generate_audio | Alıcılar çekildi |
| `auction_rank.wav` | efekt | 2,8 sn | generate_audio | Rütbe / sonuç ekranı |
| `ui_click.wav` | efekt | 0,08 sn | generate_audio | Düğmeye basma, ses aç/kapat |
| `ui_move.wav` | efekt | 0,06 sn | generate_audio | Düğmeler arası gezinme, kaydırıcı önizlemesi |

## Onaylı ses dengesi (9. aşama, 2026-11-04)

Kullanıcı oyunda dinleyerek onayladı; bu değerler `scripts/autoload/audio_manager.gd`
içindeki `GAIN_DB` tablosundadır ve değiştirilmeden korunmalıdır.

- Menüde ve denizde yalnızca `music_main` ile gerçek dalga `amb_waves_beach` (−4 dB,
  Ambient) çalar; `amb_wind` çalınmaz.
- `ship_water` −15 dB (SFX): gemi durgunken sessiz, tam hızda gerçek dalganın
  yaklaşık 3 dB altında kalır.
- Müzik, ortam sesinden ortalama ~11 dB yüksek; Master'da −0,5 dBFS sınırlayıcı,
  oyun boyunca kırpılma yok.

## Yeniden üretme

```
python -X utf8 tools/generate_audio.py --dogrula   # onaylı 3 ses birebir aynı mı
python -X utf8 tools/generate_audio.py             # kalan 20 sesi assets/audio'ya yazar
```
