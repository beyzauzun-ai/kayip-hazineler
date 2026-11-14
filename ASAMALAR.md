# Kayıp Hazineler: Son 120 Saniye — Aşama kaydı

Godot 4.7.2, Compatibility (gl_compatibility) renderer. Hedef donanım: AMD Radeon
Vega 8, HUD açıkken ≥100 FPS. Her aşama kullanıcı onayıyla kapatılır.

Bu kayıt proje dosyalarına ve aşama raporlarına dayanır; ayrıntılı ses kaynakları
için `assets/audio/KAYNAKLAR.md` dosyasına bakınız.

| Aşama | Konu | Durum |
|---|---|---|
| 1 | Proje kurulumu | Tamamlandı |
| 2 | Deniz dünyası | Tamamlandı |
| 3 | Gemi kontrolü | Tamamlandı |
| 4 | Batıklar ve hazine çıkarma | Tamamlandı |
| 5 | Süre, liman, kazanma/kaybetme | Tamamlandı |
| 6 | Menü, HUD, harita, duraklatma | Tamamlandı |
| 7 | Açık artırma ve rütbeler | Tamamlandı |
| 8 | Görsel cila (2 bölüm) | Tamamlandı |
| 9 | Ses | Tamamlandı (2026-11-04) |
| 10 | Son cila, performans, teslim | **Devam ediyor – hazırlık** |

## 1. Proje kurulumu
- `kayip-hazineler` klasöründe bağımsız Godot projesi, Compatibility renderer.
- Referans görseller `reference/` klasöründe (`konsept.webp`, `hud.webp`).
- Yazı tipi: Baloo 2 (Türkçe karakter desteği). Fredoka dosyası korunuyor, kullanılmıyor.

## 2. Deniz dünyası
- Sabit, ortografik kamera; pastel masalsı stil.
- Su, köpük ve şelale shader'ları; toon aydınlatma shader'ı.
- Prosedürel adalar, kayalıklar, mercanlar ve liman (`scripts/world/`); çizim
  çağrılarını azaltmak için mesh birleştirme (`mesh_batcher.gd`).

## 3. Gemi kontrolü
- WASD / ok tuşları; S önce frenler, sonra geri gider (`scripts/ship/ship.gd`).
- Kayalık ve kıyı çarpışmaları.

## 4. Batıklar ve hazine çıkarma
- Üç batık: Mercan Koyu / Kayıp Pusula, Sisli Geçit / Kraliyet Tacı,
  Derin Mavi / Okyanus Safiri (`scenes/wreck.tscn`).
- Durmuş gemiyle E 3 sn basılı tutulunca eser çıkarılır; çıkarma çubuğu.

## 5. Süre, liman, kazanma/kaybetme
- 120 sn sayaç; yalnızca duraklatmada durur, buluntular süre eklemez.
- 3/3 eserle limana dönüş görevi kazandırır; süre dolarsa "Süre doldu".

## 6. Menü, HUD, harita, duraklatma
- Ana menü, HUD, M ile hazine haritası (sayaç akmaya devam eder), Esc ile duraklatma.
- Ortak arayüz teması (`scripts/ui/ui_theme.gd`).

## 7. Açık artırma ve rütbeler
- Taban teklifler 100 / 180 / 300; bekleme ×1,5 ve ×2,2, 5'in katlarına yuvarlanır.
- Her bekleme %70 yükselme / %30 alıcılar çekilir; en fazla 2 bekleme, ikinci başarılı
  beklemede otomatik satış (`scripts/auction/auction_session.gd`).
- Rütbeler: Acemi Korsan 0–649, Usta Hazine Avcısı 650–999, Denizlerin Efsanesi 1000+.

## 8. Görsel cila
- 1. bölüm: adaların yüksekliği ve katmanları, kayaların gölgelenmesi, bitki örtüsü,
  çimen rengi.
- 2. bölüm: liman detayı, batık ahşap rengi, çıkarma çubuğunun gemiyi kapatmaması,
  açık artırmada "alıcılar çekildi" görünümü; glow yerine sahte parlama halesi.

## 9. Ses
- 24 ses: 23'ü bu proje için kodla üretildi, deniz dalgası CC0 gerçek kayıt.
- Müzik / Efekt / Ortam kanalları, kırpılmayı önleyen sınırlayıcı, üst üste binmeyi
  önleyen bekleme süreleri, menüden ses ayarları.
- Onaylı denge: sentetik rüzgâr çalınmaz, gemi suyu −15 dB (ayrıntı `KAYNAKLAR.md`).
- Son testler: ses testi 46/46; FPS HUD 108,7, harita 91,7, açık artırma 106,3.

## 10. Son cila, performans, teslim — Devam ediyor (hazırlık)
- Hazırlık: proje yedeği alındı
  (`../kayip-hazineler_asama9_tamam_yedek_2026-11-04.zip`, 217 dosya, doğrulandı).
- HUD çakışması (seçenek A, onaylandı): kamera kadrajı genişletildi (genişlik
  120 → 133,8, konum (0; 80,81; 59), açı aynı); gemi hiçbir konumda üst HUD
  panellerinin arkasına girmiyor. Sahne ~%10 küçük görünür.
- Kayalar (Tasarım 1 "Yontulmuş", onaylandı): az parçalı, düz yüzlü, tepesi
  kesik kaya mesh'i (`PropLibrary.rock`); konum, boyut, renk ve çarpışma
  şekilleri aynı.
- Testler artık proje içinde `tests/` klasöründe (bkz. `tests/README.md`).
- Liman çatıları ve ışıltı (R1 + L1, onaylandı): dik, iki tonlu
  turuncu beşik çatı (yükseklik duvarın %90'ı), mahya ve saçak kirişleri, sade
  kiremit sıraları, duvar renginde alınlık; fener/pencere haleleri %30 büyük +
  parlak çekirdek, yoğunluk 1,3 → 1,6 (`port.gd`, `glow_halo.gdshader`). Gerçek
  ışık veya glow yok. Çizim çağrısı değişmedi (153).
- Hazine haritası performansı (seçenek B "birleştirilmiş çizim", onaylandı): ada/kayalık şekilleri tek mesh, kesikli daireler tek çizgi
  komutu. Harita açıkken çizim çağrısı 295 → 169; görünüm eskisiyle piksel olarak
  aynı (ortalama fark 0,004/255). Ek bellek ≈ 125 KB.

### Test durumu (2026-11-12, bilgisayar prizde)

| Test | Sonuç |
|---|---|
| `cikarma_suresi.gd` | Geçti — oyun zamanlayıcısı 3,003–3,014 sn, gerçek saat 2,989–3,016 sn (6 ölçüm) |
| `rota_ve_gemi.gd` | Geçti — rota 61,5 sn, kayalık/kıyı çarpması 0 |
| `batiklar_ve_cikarma.gd` | Geçti |
| `hud_cakisma.gd` | Geçti — üst panellere 0 temas; tuş ipucu çubuğu güney kıyısında 22 örnekte en fazla %13 (bilgi) |
| `acik_artirma_mantik.gd`, `acik_artirma_akis.gd` | Geçti |
| `ses.gd` | Geçti |
| `cubuk_ve_ortulme.gd` | Regresyon: geçti (10/130, önceki 10). **Katı hedef: karşılanmadı — incelenecek** (kuzey geçidinde 10 örnek) |
| `kaya_ortulme.gd` | Regresyon: geçti (32, önceki 32; eski kayalarla 40, 32'si de eski 40'ın içinde). **Katı hedef: karşılanmadı — incelenecek** |
| `gorsel_ortulme.gd` | Piksel ölçümü: hiçbir ölçümde gemi yarıdan fazla örtülü değil. Bitki örtüsündeki 10 noktadan 9'u gerçekte açıkta (kutu testinin yanlış pozitifi), 1'i kısmen örtülü (%80 görünür). Kaya bölgesinde 16 ölçümün 7–9'u kısmen örtülü (%65–86 görünür; çoğunlukla palmiyeler). **Katı hedef: karşılanmadı — incelenecek** |
| `harita_dogrulama.gd` | Geçti — görünüm 7 durumda eskisiyle aynı; M ile aç/kapa, harita açıkken süre akıyor, görev bitince kapanıyor, ok ≤ 0,1 sn'de güncelleniyor. Gemi oku 21 pozda, 3840×2160 (2×) ölçümle, 1920 tabanında: konum (ağırlık merkezi) en fazla 0,05 px (≤ 1); rasterleştirme (sivri uç) en fazla 1,11 px (≤ 2). (1:1 ölçümde uç 2,22 px çıkıyordu; fark ölçüm çözünürlüğünden, tolerans değişmedi.) |
| `sure_geri_sayim.gd` | Geçti — normal oyun (sayaca dokunulmadan) 02:00 → 00:00 gerçek saatle 120,02 sn; 60/20/10/1 sn noktaları ±0,02 sn; son 20 sn uyarı sesi 1 kez ve HUD uyarı rengi; son 10 sn'de 10 tık; süre dolunca sonuç ekranı, gemi kontrolü kapalı |
| `fps.gd` (harita optimizasyonu sonrası, 4 ölçüm) | HUD 102,9–105,2, açık artırma 104,0–105,7; **hazine haritası 99,5 / 99,6 / 100,2 / 100,6 — önceki 89,7'den yükseldi; 100 hedefinin tam sınırında (4 ölçümün 2'si altında)** |
| Liman çevresi gemi görünürlüğü (geçici karşılaştırma, 5 poz × 2) | Eski / yeni: poz 1 %99/%98–99, poz 2 %98/%98–99, poz 3 %97–92/%92, poz 4 %85–83/%85, **poz 5 %91–90/%86 (yeni çatı 4–5 puan daha fazla örtüyor)** |
| `fps.gd` (çatı + ışık sonrası, 2 ölçüm) | HUD 105,1 / 104,9, açık artırma 103,6 / 104,2; **hazine haritası 100,7 / 99,2 — 100 hedefinin sınırında (1 ölçüm altında)** |

### Baştan sona son kontrol (2026-11-12, prizde)

| Kontrol | Sonuç |
|---|---|
| `uctan_uca.gd -- mod=kazanma` | Geçti — menü, Oyna, 3 hazine (her biri oyun saatiyle 3,02 sn), seyirde harita, limanda açık artırma (kabul / 1 bekleme + kabul / 2 bekleme otomatik satış) → 1030 altın, Denizlerin Efsanesi; Yeniden Başlat (sesler birikmiyor), Esc duraklatma, Ana Menü |
| `uctan_uca.gd -- mod=kaybetme` | Geçti — 2/3 eserle limanda uyarı, görev sürüyor; süre dolunca "Süre doldu", altın 0, uyarı/tık/kayıp sesleri; kayıptan Yeniden Başlat |
| `uctan_uca.gd -- mod=sinir` | Geçti (0 hata) — çıkarma sırasında duraklatma (ilerleme ve sayaç durur, eser verilmez), çıkarma sırasında harita, erken bırakma ve yeniden deneme; 580 altın, Acemi Korsan. **İncelenecek: duraklatmadan devam edince E basılı olsa da çıkarma sesi (extract_loop) yeniden çalmıyor** |
| `uctan_uca.gd -- mod=uzun tur=10` | Geçti — 10 turda bellek 68,0 → 68,0 MB, düğüm 306 → 306, nesne 2317 → 2317, her turda 2 ses döngüsü ve 1 müzik oynatıcı; tur süresi 67,4 sn |
| Takılma (50 ms'den uzun kare) | **İncelenecek** — ilk açılışlarda ~140 ms'lik tek kareler: menü açılışı, ilk keşif/harita, açık artırma ve sonuç ekranı açılışı, sahne yeniden yükleme. Aynı oturumda tekrarlarda görülmüyor (olası neden: ilk kullanımda malzeme/gölgelendirici hazırlığı) |
| `harita_fps.gd` (5 × 15 sn) | 99,1 / 98,6 / 95,6 / 100,8 / 99,9 FPS; ortalama 98,8, en düşük 95,6; ortalama kare ≈ 10,1 ms, en uzun 21,8 ms. **5 ölçümün 4'ü 100 hedefinin altında** |
| Sonuç ekranı FPS | 100,4 (ayrı 8 sn ölçüm; uçtan uca testteki düşük değer yalnızca sahne geçişi karelerinden) |
| `sure_geri_sayim.gd` (son tekrar) | **Geçersiz** — çalışırken test penceresine dışarıdan klavye girdisi geldi (gemi W/A/E ile sürülüp eserler toplandı). Aynı gün önceki iki çalıştırmada geçmişti; yeniden çalıştırılması gerekiyor |
| Diğer tüm testler | Geçti; görünürlük katı hedefleri "[İNCELE]" (bitki 10/130, kaya 32, piksel 9/26) |

- Açık takip maddeleri (çözülmüş sayılmaz):
  - Limanda 5 numaralı pozda (evlerin kuzeyi) gemi görünürlüğü %90–91'den %86'ya
    düştü (yeni çatı).
  - Hazine haritası FPS'i 100 hedefinin sınırında / altında (son 5 ölçüm ortalaması 98,8).
  - Duraklatmadan devamda çıkarma sesi yeniden başlamıyor (incelenecek).
  - İlk açılışlarda ~140 ms'lik tek kare takılmaları (incelenecek).
- Bekleyen konular (henüz uygulanmadı):
  - Hazine haritası açıkken FPS 100 hedefinin sınırında (99,5–100,6); kullanıcı
    şimdilik B yöntemini korumaya karar verdi (A2'ye geçilmedi).
  - Ada kuzey kıyılarına çok yaklaşan gemi öndeki palmiye/kayaların arkasında
    kısmen kalabiliyor (incelenecek).
  - Oyuncu ipuçları, zorluk değerlendirmesi, son testler ve Windows teslim paketi.
