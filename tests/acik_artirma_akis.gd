extends SceneTree
## 7. aşama gerçek pencere testi: liman → açık artırma → sonuç, klavye + fare,
## çift Enter koruması, otomatik satış, vazgeçme, sayaç, akışlar, glifler, FPS.

var OUT := _cikti_klasoru() + ""

var scene: Node
var ship
var ui: Node
var gm: Node
var am: Node
var sounds: Array = []
var fails := 0
var steps: Array = []
var step_i := 0
var step_t := 0.0
var data := {}


func _initialize() -> void:
	scene = (load("res://scenes/sea_level.tscn") as PackedScene).instantiate()
	root.add_child(scene)
	current_scene = scene
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	_build_steps()


func _bind() -> void:
	scene = current_scene
	ship = scene.get_node("Gemi")
	ui = scene.get_node("Arayuz")


func _process(delta: float) -> bool:
	if gm == null:
		gm = root.get_node("GameManager")
		am = root.get_node("AudioManager")
		am.sfx_requested.connect(func(n): sounds.append(n))
		_bind()
	step_t += delta
	if step_i >= steps.size():
		print("SONUÇ: hata sayısı = ", fails)
		return true
	if steps[step_i].call():
		step_i += 1
		step_t = 0.0
	return false


func _auction(): return ui.get_node("AcikArtirma")
func _result(): return ui.get_node("GorevSonucu")


func _win_steps(outcomes: Array) -> Array:
	return [
		func(): return _wait(0.3, func():
			for a in [&"compass", &"crown", &"sapphire"]:
				gm.collect_artifact(a)
			ship.reset_to(Transform3D(Basis(Vector3.UP, deg_to_rad(90)), Vector3(-14, 0, 15)))),
		func(): return _wait(0.3, func(): Input.action_press(&"ship_forward")),
		func(): return _until(func(): return gm.state == gm.State.AUCTION, 6.0, func():
			Input.action_release(&"ship_forward")
			data["t_won"] = gm.time_left
			_auction().session.forced_outcomes.assign(outcomes)
			_check("üç eserle limana varış → açık artırma ekranı açıldı (giriş: '%s')" % _auction()._message.text, _auction().visible and _auction()._message.text.begins_with("Limana vardın"))),
	]


func _build_steps() -> void:
	steps = [func(): return _wait(1.0, func(): _act(&"ui_accept"))]
	steps.append_array(_win_steps([true, true, false]))
	steps.append_array([
		# --- 1. eser: klavye ile kabul, çift Enter ---
		func(): return _until(func(): return _auction().session.phase == AuctionSession.Phase.OFFER, 3.0, func():
			var a = _auction()
			_check("ilk eser: %s, teklif '%s', '%s'" % [a._name_label.text, a._offer_label.text, a._waits_label.text], a._name_label.text == "Kayıp Pusula" and a._offer_label.text == "100 altın" and a._waits_label.text == "Kullanılan bekleme hakkı: 0/2")
			_check("risk bilgisi görünüyor: '%s'" % a._risk_label.text.replace("\n", " / "), a._risk_label.text.contains("%70") and a._risk_label.text.contains("150 altın") and a._risk_label.text.contains("%30") and a._risk_label.text.contains("0 altın"))
			_check("açık artırmada HUD gizli", not ui.get_node("HUD").visible)
			_check("odak 'Teklifi Kabul Et (100)'", _focused() == "Teklifi Kabul Et (100)")
			_shot("stage7_offer")),
		func(): return _wait(0.5, func():
			_check("açık artırmada sayaç durdu (%.3f → %.3f)" % [data["t_won"], gm.time_left], gm.time_left == data["t_won"])
			data["snd"] = sounds.size()
			_act(&"ui_accept")
			_act(&"ui_accept")),
		func(): return _wait(0.3, func():
			_check("çift Enter → tek satış, altın 100 (satış: %s)" % str(gm.sales), gm.gold == 100 and gm.sales.size() == 1 and sounds.slice(data["snd"]).count(&"auction_sold") == 1)
			_check("bildirim: '%s'" % _auction()._message.text, _auction()._message.text == "Satıldı! +100 altın")
			_check("toplam paneli: '%s'" % _auction()._total_label.text, _auction()._total_label.text == "Toplam: 100 altın")
			_shot("stage7_sold")),
		# --- 2. eser: iki başarılı bekleme → otomatik satış ---
		func(): return _until(func(): return _auction().session.index == 1 and _auction().session.phase == AuctionSession.Phase.OFFER, 3.0, func(): _act(&"ui_right")),
		func(): return _wait(0.2, func():
			_check("→ ile odak 'Daha Yüksek Teklif Bekle'", _focused() == "Daha Yüksek Teklif Bekle")
			_act(&"ui_accept")),
		func(): return _wait(0.3, func():
			var a = _auction()
			_check("bekleniyor: '%s', düğmeler kilitli" % a._message.text, a._message.text == "Teklifler bekleniyor..." and a._accept.disabled and a._wait.disabled)
			data["f0"] = Engine.get_process_frames()
			data["ms"] = Time.get_ticks_msec()
			_shot("stage7_waiting")),
		func(): return _wait(1.1, func():
			var fps: float = (Engine.get_process_frames() - data["f0"]) / ((Time.get_ticks_msec() - data["ms"]) / 1000.0)
			print("FPS (açık artırma ekranı, vsync kapalı): %.1f" % fps)
			var a = _auction()
			_check("1. bekleme başarılı: teklif '%s', '%s'" % [a._offer_label.text, a._waits_label.text], a._offer_label.text == "270 altın" and a._waits_label.text == "Kullanılan bekleme hakkı: 1/2")
			_check("yeni risk bilgisi 395 altını gösteriyor", a._risk_label.text.contains("395 altın"))
			_check("bekleme düğmesi yeniden açık, odak Kabul Et", not a._wait.disabled and _focused() == "Teklifi Kabul Et (270)")
			_shot("stage7_raised")
			_act(&"ui_right")),
		func(): return _wait(0.2, func(): _act(&"ui_accept")),
		func(): return _wait(1.5, func():
			var a = _auction()
			_check("2. bekleme başarılı → otomatik satış 395: '%s'" % a._message.text, gm.sales.get(&"crown") == 395 and a._message.text == "Son teklif otomatik kabul edildi! +395 altın")
			_check("otomatik satıştan sonra iki düğme de kapalı", a._wait.disabled and a._accept.disabled)
			_check("bekleme hakkı 2/2", a._waits_label.text == "Kullanılan bekleme hakkı: 2/2")
			_check("kapalı düğme odakta kalmadı (açık gibi görünmüyor)", not a._wait.has_focus() and not a._accept.has_focus())
			_shot("stage7_auto")
			_act(&"ui_accept")),
		func(): return _wait(0.25, func():
			_check("otomatik satıştan sonra Enter etkisiz, bekleme düğmesi hâlâ kapalı (altın %d)" % gm.gold, gm.gold == 495 and _auction()._wait.disabled)),
		# --- 3. eser: fare ile bekle → alıcılar çekildi ---
		func(): return _until(func(): return _auction().session.index == 2 and _auction().session.phase == AuctionSession.Phase.OFFER, 3.0, func():
			_check("üçüncü eser Okyanus Safiri, teklif 300", _auction()._name_label.text == "Okyanus Safiri" and _auction()._offer_label.text == "300 altın")
			_check("yeni eserde kayıp görünümü yok", not _auction().is_showing_lost())
			_click(_auction()._wait)),
		func(): return _wait(1.5, func():
			var a = _auction()
			_check("fare tıklamasıyla beklendi → alıcılar çekildi: '%s'" % a._message.text, a._message.text == "Alıcılar çekildi! Bu eserden 0 altın." and gm.sales.get(&"sapphire") == 0)
			_check("durum şeridi: Pusula '%s', Taç '%s', Safir '%s'" % [a._strip[&"compass"].text, a._strip[&"crown"].text, a._strip[&"sapphire"].text], a._strip[&"sapphire"].text == "Satılamadı" and a._strip[&"crown"].text == "Satıldı: 395")
			_check("alıcılar çekildi görünümü: mühür + üstü çizili teklif + kayıp satırı ('%s', '%s')" % [a._offer_label.text, a._lost_label.text], a.is_showing_lost() and a._offer_label.text == "300 altın" and a._lost_label.text == "0 altın kazanıldı · 300 altınlık teklif kaybedildi")
			_shot("stage7_buyers_left")),
		# --- Sonuç ve rütbe ---
		func(): return _until(func(): return _result().visible, 3.0, func():
			var r = _result()
			_check("sonuç: '%s', '%s', '%s'" % [r._title.text, r._body.text, r._rank.text], r._title.text == "Açık Artırma Tamamlandı!" and r._body.text == "Toplam: 495 altın" and r._rank.text == "Rütbe: Acemi Korsan")
			_check("3 satış satırı", r._rows.get_child_count() == 3)
			_check("açık artırma ekranı kapandı, durum RESULT, HUD gizli", not _auction().visible and gm.state == gm.State.RESULT and not ui.get_node("HUD").visible)
			_check("toplam altın = satışların toplamı (%d)" % gm.gold, gm.gold == 100 + 395 + 0)
			_check("açık artırma boyunca sayaç hiç değişmedi", gm.time_left == data["t_won"])
			_check("ses istekleri: satış 2, vazgeçme 1, yeni teklif 2, rütbe 1", sounds.count(&"auction_sold") == 2 and sounds.count(&"auction_buyers_left") == 1 and sounds.count(&"auction_new_offer") == 2 and sounds.count(&"auction_rank") == 1)
			_act(&"pause")),
		func(): return _wait(0.6, func():
			_check("sonuç ekranında Esc duraklatmıyor", not paused)
			_shot("stage7_results")
			_glyph_check()
			_act(&"ui_right")),
		func(): return _wait(0.2, func(): _act(&"ui_accept")),
		func(): return _wait(0.8, func():
			_bind()
			_check("sonuç → Ana Menü (altın sıfırlandı)", ui.get_node("AnaMenu").visible and gm.state == gm.State.MENU and gm.gold == 0)
			_act(&"ui_accept")),
		# --- Başarısız görev: açık artırma yok ---
		func(): return _wait(0.5, func():
			gm.collect_artifact(&"compass")
			gm.collect_artifact(&"crown")
			gm.time_left = 0.3),
		func(): return _wait(2.5, func():
			_check("süre doldu → açık artırma AÇILMADI, 'Süre doldu!' ekranı", not _auction().visible and _result().visible and _result()._title.text == "Süre doldu!" and gm.state == gm.State.RESULT and gm.gold == 0)
			_act(&"ui_accept")),
		# --- Yeniden Başlat + hepsini ilk teklifte sat ---
		func(): return _wait(0.8, func(): _bind(); _check("Yeniden Başlat: yeni görev", gm.is_sailing())),
	])
	steps.append_array(_win_steps([]))
	for i in 3:
		steps.append(func(): return _until(func(): return _auction().session.index == i and _auction().session.phase == AuctionSession.Phase.OFFER, 4.0, func(): _act(&"ui_accept")))
	steps.append_array([
		func(): return _until(func(): return _result().visible, 4.0, func():
			_check("hepsi ilk teklifte → 580 altın, Acemi Korsan", gm.gold == 580 and _result()._rank.text == "Rütbe: Acemi Korsan")
			_act(&"ui_accept")),
		func(): return _wait(0.8, func():
			_bind()
			_check("sonuç → Yeniden Başlat: yeni görev, altın 0, satış yok", gm.is_sailing() and gm.gold == 0 and gm.sales.is_empty())),
	])


func _glyph_check() -> void:
	var font: FontFile = load("res://assets/fonts/Baloo2-Variable.ttf")
	var texts: Array[String] = []
	_collect(ui, texts)
	texts.append_array(["Limana vardın! Açık artırma başlıyor...", "Teklifler bekleniyor...", "Son teklif otomatik kabul edildi! +395 altın", "Alıcılar çekildi! Bu eserden 0 altın.", "Bekleme hakkı kalmadı.", "Rütbe: Usta Hazine Avcısı", "Rütbe: Denizlerin Efsanesi", "Kraliyet Tacı — Alıcılar çekildi: 0 altın (1 bekleme)", "Orta · Eser 2/3"])
	var missing := {}
	for t in texts:
		for ch in t:
			if ch != " " and ch != "\n" and not font.has_char(ch.unicode_at(0)):
				missing[ch] = true
	_check("açık artırma/sonuç metinlerinde (%d metin) eksik glif yok %s" % [texts.size(), missing.keys()], missing.is_empty())


func _collect(node: Node, out: Array[String]) -> void:
	if (node is Label or node is Button) and node.text != "":
		out.append(node.text)
	for c in node.get_children():
		_collect(c, out)


func _focused() -> String:
	var f := root.gui_get_focus_owner()
	return f.text if f is Button else ""


func _click(control: Control) -> void:
	var pos: Vector2 = root.get_final_transform() * control.get_global_rect().get_center()
	for pressed in [true, false]:
		var ev := InputEventMouseButton.new()
		ev.button_index = MOUSE_BUTTON_LEFT
		ev.pressed = pressed
		ev.position = pos
		ev.global_position = pos
		Input.parse_input_event(ev)


func _act(action: StringName) -> void:
	for pressed in [true, false]:
		var ev := InputEventAction.new()
		ev.action = action
		ev.pressed = pressed
		Input.parse_input_event(ev)


func _wait(seconds: float, then: Callable) -> bool:
	if step_t < seconds:
		return false
	then.call()
	return true


func _until(cond: Callable, timeout: float, then: Callable) -> bool:
	if not cond.call() and step_t < timeout:
		return false
	then.call()
	return true


func _shot(file: String) -> void:
	root.get_texture().get_image().save_png(OUT + file + ".png")


func _check(label: String, ok: bool) -> void:
	if not ok:
		fails += 1
	print(("  [OK]   " if ok else "  [HATA] ") + label)


## Ekran görüntüleri: TEST_CIKTI ortam değişkeni ya da user://test_ciktilari.
static func _cikti_klasoru() -> String:
	var d := OS.get_environment("TEST_CIKTI")
	if d.is_empty():
		d = OS.get_user_data_dir().path_join("test_ciktilari")
	DirAccess.make_dir_recursive_absolute(d)
	return d + "/"
