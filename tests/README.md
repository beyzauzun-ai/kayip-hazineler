# Testler

Godot'nun `-s` kipiyle, gerçek oyun penceresinde çalışan test betikleri. Klasördeki
`.gdignore` dosyası bu klasörü editörden ve dışa aktarmadan gizler; testler oyuna
dahil edilmez.

Proje klasöründe çalıştırma (Godot konsol sürümüyle):

```
Godot_v4.7.2-stable_win64_console.exe --path . -s tests/ses.gd
Godot_v4.7.2-stable_win64_console.exe --path . -s tests/uctan_uca.gd -- mod=kazanma
```

`acik_artirma_mantik.gd` pencere gerektirmez (`--headless` ile de çalışır). Ekran
görüntüsü alan testler çıktıyı `TEST_CIKTI` ortam değişkenindeki klasöre, yoksa
`user://test_ciktilari` klasörüne yazar. Her test sonunda `SONUÇ: hata sayısı = N`
yazdırır. Örtme testleri iki ayrı sonuç verir: `REGRESYON` (önceki sürüme göre
kötüleşme var mı; hata sayısına girer) ve `KATI HEDEF` (hiç örtme olmaması;
karşılanmazsa `[İNCELE]` yazılır ve SONUÇ satırında "incelenecek" olarak ayrıca
sayılır).

| Test | Denetlediği |
|---|---|
| `rota_ve_gemi.gd` | Gemi kontrolü, üç batık ve limana dönüş rotası, kayalık çarpması, kıyı |
| `batiklar_ve_cikarma.gd` | Batık keşfi, E ile 3 sn çıkarma, yarıda kalma |
| `cikarma_suresi.gd` | Çıkarma süresi: oyun zamanlayıcısı ve gerçek saat ayrı ayrı |
| `gorsel_ortulme.gd` | Örtme testlerinin işaretlediği noktalarda geminin piksel olarak görünen oranı |
| `cubuk_ve_ortulme.gd` | Çıkarma çubuğunun yerleşimi, bitki örtüsünün gemiyi/batıkları örtmesi |
| `kaya_ortulme.gd` | Kayaların gemiyi örtmesi, kayalık çarpışma şekilleri |
| `hud_cakisma.gd` | Kamera kadrajı, geminin üst HUD panellerine girmemesi |
| `acik_artirma_mantik.gd` | Teklif, bekleme, olasılık ve rütbe kuralları |
| `acik_artirma_akis.gd` | Açık artırma ekranı akışı ve sonuç ekranı |
| `ses.gd` | Ses dosyaları, döngüler, ses dengesi, duraklatma, yeniden başlatma |
| `harita_dogrulama.gd` | Hazine haritası: eski çizimle piksel karşılaştırma (başlangıç, keşif, hazine); gemi oku 21 pozda 2× çözünürlükte (3840×2160, sonuç 1920 tabanında): konum ≤ 1 px, sivri uç ≤ 2 px; M tuşu, süre, çizim çağrısı |
| `sure_geri_sayim.gd` | Normal oyunun 120 sn geri sayımı gerçek zamanlı (≈ 2 dk): 02:00 başlangıç, ara noktalar, son 20 sn uyarısı, 00:00'da sonuç ekranı |
| `eski_harita_referans.gd` | Test değil: `harita_dogrulama.gd`'nin karşılaştırdığı, 10. aşama öncesi harita çizimi |
| `uctan_uca.gd` | Baştan sona oynanış (yalnızca klavye girdisi; sayaç, konum, eser ve durum değiştirilmez). `-- mod=kazanma` (≈ 1,5 dk), `kaybetme` (≈ 2 dk), `sinir` (≈ 1,5 dk), `uzun tur=10` (≈ 13 dk). Açık artırma sonuçları yalnızca test tarafında `forced_outcomes` ile belirlenir |
| `harita_fps.gd` | Harita açıkken 5 × 15 sn FPS; ölçüm başına FPS, ortalama ve en uzun kare; 100 FPS altı "[HEDEF ALTI]" |
| `fps.gd` | HUD, harita ve açık artırma ekranlarında FPS (bilgisayar prize takılıyken ölçün) |

Not: `batiklar_ve_cikarma.gd` çıkarma süresini duvar saatiyle ölçer; bilgisayar
pildeyken FPS düştüğü için 3,35 sn sınırını aşabilir.
