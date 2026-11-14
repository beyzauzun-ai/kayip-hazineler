extends SceneTree
## 7. aşama mantık testi (başsız): AuctionSession + GameManager, kontrollü sonuçlarla.

var gm: Node
var Session: GDScript
var fails := 0
var frame := 0


func _process(_d: float) -> bool:
	frame += 1
	if frame < 2:
		return false
	gm = root.get_node("GameManager")
	Session = load("res://scripts/auction/auction_session.gd")
	_run()
	print("SONUÇ: hata sayısı = ", fails)
	return true


## Görevi başarıyla bitirip AUCTION durumuna getirir.
func _won() -> void:
	gm.start_mission()
	for a in [&"compass", &"crown", &"sapphire"]:
		gm.collect_artifact(a)
	gm.time_left = 50.0
	gm.try_finish_at_port()


func _session(outcomes: Array = []) -> RefCounted:
	var s = Session.new(gm, 1234)
	s.forced_outcomes.assign(outcomes)
	return s


func _run() -> void:
	print("— Teklif tablosu ve yuvarlama —")
	var table := []
	for a in gm.ARTIFACTS:
		table.append([gm.get_offer(a.id, 0), gm.get_offer(a.id, 1), gm.get_offer(a.id, 2)])
	_check("tablo %s" % [table], table == [[100, 150, 220], [180, 270, 395], [300, 450, 660]])
	_check("180 × 2,2 = 396 → en yakın 5'in katı 395 (|396−395|=1 < |400−396|=4)", 180 * 220 / 100 == 396 and gm.get_offer(&"crown", 2) == 395)
	var all_mult5 := true
	for row in table:
		for v in row:
			all_mult5 = all_mult5 and v % 5 == 0
	_check("tüm teklifler 5'in katı", all_mult5)

	print("— Başlatma koşulları —")
	gm.start_mission()
	_check("görev sürerken açık artırma başlamaz", not _session().start())
	gm.time_left = 0.0
	gm._process(0.0)
	_check("kaybedilen görevden açık artırma başlamaz (durum RESULT)", gm.state == gm.State.RESULT and not _session().start())
	_check("kaybedilen görevde record_sale reddedilir", not gm.record_sale(&"compass", 100) and gm.gold == 0)

	print("— Hemen kabul (3 eser) —")
	_won()
	var s = _session()
	_check("üç eserle zamanında dönüş → başlar", s.start())
	_check("ikinci start() reddedilir", not s.start())
	_check("ilk teklif 100, bekleme 0/2", s.offer == 100 and s.waits_used == 0 and s.can_wait())
	_check("next_item satıştan önce reddedilir", not s.next_item())
	_check("kabul → satıldı", s.accept())
	_check("aynı esere ikinci kabul reddedilir", not s.accept() and gm.gold == 100)
	_check("satılmış esere bekleme reddedilir", not s.wait() and s.waits_used == 0)
	s.next_item(); s.accept(); s.next_item(); s.accept()
	var fin := [-1]
	s.finished.connect(func(t): fin[0] = t)
	s.next_item()
	_check("hepsi ilk teklifte: toplam 580, finished(580)", gm.gold == 580 and fin[0] == 580 and s.phase == s.Phase.FINISHED)
	_check("bittikten sonra kabul/bekle/ilerle reddedilir", not s.accept() and not s.wait() and not s.next_item())
	_check("rütbe 580 → Acemi Korsan", gm.get_title() == "Acemi Korsan")

	print("— Bekleme senaryoları —")
	_won()
	s = _session([true, false, true, true])
	s.start()
	_check("bekle (başarılı) → teklif 150, hak 1/2, yeni teklif bilgisi 220", s.wait() and s.offer == 150 and s.waits_used == 1 and s.next_offer() == 220)
	_check("başarılı beklemeden sonra kabul → +150", s.accept() and gm.gold == 150)
	s.next_item()
	var left := [false]
	s.buyers_left.connect(func(_id): left[0] = true)
	_check("Taç: bekle (başarısız) → alıcılar çekildi, 0 altın", s.wait() and left[0] and gm.gold == 150 and gm.sales[&"crown"] == 0)
	_check("vazgeçilen esere kabul reddedilir", not s.accept() and gm.gold == 150)
	s.next_item()
	var auto := [false]
	s.sold.connect(func(_id, _amt, a): auto[0] = a)
	s.wait()
	_check("Safir: 1. bekleme başarılı → 450", s.offer == 450 and s.can_wait())
	s.wait()
	_check("2. bekleme başarılı → 660 OTOMATİK satıldı", auto[0] and gm.sales[&"sapphire"] == 660 and s.phase == s.Phase.ITEM_DONE)
	_check("otomatik satıştan sonra bekleme/kabul kapalı, hak 2/2'de kaldı", not s.can_wait() and not s.wait() and not s.accept() and s.waits_used == 2)
	_check("toplam = 150 + 0 + 660 = 810 = GameManager.gold", gm.gold == 810 and s.total_gold() == 810)
	var sum := 0
	for r in s.results:
		sum += r.amount
	_check("sonuç kayıtlarının toplamı da 810 (%s)" % [s.results], sum == 810 and s.results.size() == 3)
	_check("rütbe 810 → Usta Hazine Avcısı", gm.get_title() == "Usta Hazine Avcısı")

	print("— Başarılı + başarısız, üçüncü bekleme —")
	_won()
	s = _session([true, false])
	s.start()
	s.wait()
	_check("başarılı sonra başarısız → 0 altın", s.wait() and gm.sales[&"compass"] == 0 and gm.gold == 0)
	_check("üçüncü bekleme isteği reddedilir (hak 2/2)", not s.wait() and s.waits_used == 2)

	print("— Tek kaynak / çift kayıt —")
	_won()
	_check("record_sale ilk kayıt kabul", gm.record_sale(&"compass", 100))
	_check("aynı eser ikinci kez kaydedilemez, altın tek kez eklendi", not gm.record_sale(&"compass", 100) and gm.gold == 100)
	_check("toplanmamış/bilinmeyen eser kaydedilemez", not gm.record_sale(&"bilinmeyen", 50) and gm.gold == 100)
	s = _session()
	s.start()
	_check("önceden kaydedilmiş esere oturum satışı da reddedilir (altın değişmez)", not s.accept() and gm.gold == 100)

	print("— Efsane ve rütbe eşikleri —")
	_won()
	s = _session([true, true, true, true, true, true])
	s.start()
	for i in 3:
		s.wait(); s.wait(); s.next_item()
	_check("hepsi iki başarılı bekleme → 1275, Denizlerin Efsanesi", gm.gold == 1275 and gm.get_title() == "Denizlerin Efsanesi")
	for pair in [[0, "Acemi Korsan"], [649, "Acemi Korsan"], [650, "Usta Hazine Avcısı"], [999, "Usta Hazine Avcısı"], [1000, "Denizlerin Efsanesi"]]:
		gm.gold = pair[0]
		_check("rütbe %d → %s" % pair, gm.get_title() == pair[1])

	print("— Olasılıklar (tohumlu RNG) —")
	var r = Session.new(gm, 2026)
	var n := 20000
	var ups := 0
	for i in n:
		if r._roll():
			ups += 1
	var p1 := float(ups) / n
	_check("tek bekleme yükselme oranı %.4f ≈ 0,70 (±0,015)" % p1, absf(p1 - 0.7) < 0.015)
	var both := 0
	for i in n:
		if r._roll() and r._roll():
			both += 1
	var p2 := float(both) / n
	_check("iki başarılı bekleme oranı %.4f ≈ 0,49 (±0,015)" % p2, absf(p2 - 0.49) < 0.015)
	var a = Session.new(gm, 77)
	var b = Session.new(gm, 77)
	var same := true
	for i in 50:
		same = same and a._roll() == b._roll()
	_check("aynı tohum → aynı sonuç dizisi", same)


func _check(label: String, ok: bool) -> void:
	if not ok:
		fails += 1
	print(("  [OK]   " if ok else "  [HATA] ") + label)
