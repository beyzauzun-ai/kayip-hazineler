extends SceneTree
## Uçtan uca oynanış testi (10. aşama son kontrol). Oyun gerçek bir oyuncu gibi
## klavye girdileriyle oynanır: menüde "Oyna" (ui_accept), WASD ile otopilot
## rotası, batıkta durup E'yi basılı tutma, M ile harita, Esc ile duraklatma,
## açık artırma ve sonuç ekranında düğmelere odaklanıp ui_accept. Sayaç
## uzatılmaz, gemi ışınlanmaz, eser eklenmez, oyun durumu değiştirilmez.
## Tek istisna: açık artırmanın rastgele sonuçları test tarafında
## `session.forced_outcomes` ile belirlenir (oyun kodu değişmez).
##
## Kullanım: ... -s tests/uctan_uca.gd -- mod=kazanma | kaybetme | sinir | uzun [tur=10]
##   kazanma : menü → 3 hazine (yolda harita) → liman → açık artırma (kabul /
##             1 bekleme / 2 bekleme otomatik satış) → sonuç → Yeniden Başlat →
##             Esc → Ana Menü
##   kaybetme: 2 hazine → limanda "3/3 gerekli" uyarısı → süre dolar → "Süre doldu"
##   sinir   : çıkarma sırasında duraklatma ve devam; çıkarma sırasında harita;
##             erken bırakma ve yeniden deneme; hepsini kabul ederek bitirme
##   uzun    : kazanma turu art arda N kez (sonuç ekranından Yeniden Başlat);
##             bellek, düğüm, ses oynatıcı ve kare süresi izlenir

const ACTIONS := [&"ship_forward", &"ship_back", &"ship_left", &"ship_right"]
## Otopilot rotası (x, z, durak/batık mı?) — rota_ve_gemi.gd ile aynı.
const ROUTE := [
	Vector3(-40, -3, 1), Vector3(-30, 10, 0), Vector3(-5, 9.5, 0), Vector3(11, -3, 1),
	Vector3(8, -20, 0), Vector3(16, -29, 0), Vector3(30, -30, 0), Vector3(46, -27.5, 1),
	Vector3(46, -18, 0), Vector3(45, 6, 0), Vector3(20, 10, 0), Vector3(-8, 12, 0), Vector3(-29, 15, 0),
]
## Kaybetme senaryosu: iki batık, sonra limana.
const ROUTE_TWO := [
	Vector3(-40, -3, 1), Vector3(-30, 10, 0), Vector3(-5, 9.5, 0), Vector3(11, -3, 1),
	Vector3(-5, 9.5, 0), Vector3(-8, 12, 0), Vector3(-29, 15, 0),
]
const STATE_MENU := 0
const STATE_SAILING := 1
const STATE_AUCTION := 2
const STATE_RESULT := 3

var mode := "kazanma"
var rounds := 10
var OUT := _cikti_klasoru()

var scene: Node
var gm: Node
var am: Node
var ship
var errors := 0
var review := 0
var sounds: Array = []
var frame := 0
var t := 0.0
## Adım makinesi: her adım bir Callable; true döndürünce sıradakine geçilir.
var steps: Array[Callable] = []
var step_i := 0
var step_t := 0.0
var data := {}
var last_delta := 0.0

# Otopilot
var route: Array = []
var wp := 0
var wp_time := 0.0
var stop_state := ""
var stop_t := 0.0
var on_stop: Callable
var extracted_count := 0
var failed_count := 0

# Ölçümler
var fps_bins := {}
var max_frame := {}
var round_rows := []
## 50 ms'den uzun kareler: [zaman, ekran, süre].
var long_frames := []


func _initialize() -> void:
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("mod="):
			mode = arg.substr(4)
		elif arg.begins_with("tur="):
			rounds = int(arg.substr(4))
	var packed := load("res://scenes/sea_level.tscn") as PackedScene
	scene = packed.instantiate()
	root.add_child(scene)
	current_scene = scene
	print("Uçtan uca test, mod: %s%s" % [mode, (" (%d tur)" % rounds) if mode == "uzun" else ""])


func _check(label: String, ok: bool) -> void:
	if not ok:
		errors += 1
	print(("  [OK]     " if ok else "  [HATA]   ") + label)


## Bilgi amaçlı gözlem: karşılanmazsa "[İNCELE]" (hata sayısına girmez).
func _note(label: String, ok: bool) -> void:
	if not ok:
		review += 1
	print(("  [OK]     " if ok else "  [İNCELE] ") + label)


func _process(delta: float) -> bool:
	frame += 1
	t += delta
	last_delta = delta
	if frame == 3:
		_bind_scene()
		gm = root.get_node("GameManager")
		am = root.get_node("AudioManager")
		am.sfx_requested.connect(func(n): sounds.append(n))
		match mode:
			"kazanma":
				_build_win(true)
			"kaybetme":
				_build_lose()
			"sinir":
				_build_edge()
			"uzun":
				_build_long()
		steps.append(func(): return _finish())
	if frame <= 3:
		return false
	_measure(delta)
	if step_i >= steps.size():
		return true
	step_t += delta
	if steps[step_i].call():
		step_i += 1
		step_t = 0.0
	return false


func _finish() -> bool:
	print("FPS ve kare süresi (ekrana göre):")
	for k in fps_bins:
		var b: Array = fps_bins[k]
		print("  %-22s FPS %.1f, ortalama kare %.2f ms, en uzun kare %.1f ms (%d kare)" % [k, b[1] / b[0], 1000.0 * b[0] / b[1], max_frame[k] * 1000.0, b[1]])
	print("50 ms'den uzun kareler (takılma): %d" % long_frames.size())
	for f in long_frames.slice(0, 12):
		print("  t = %6.1f sn, %-16s %.0f ms" % [f[0], f[1], f[2] * 1000.0])
	_note("oyun sırasında (geçişler dışında) 50 ms'den uzun kare yok", long_frames.filter(func(f): return f[1] != "geçiş").size() == 0)
	print("SONUÇ: hata sayısı = %d; incelenecek = %d" % [errors, review])
	quit()
	return false


# --- Yardımcılar ----------------------------------------------------------------

func _bind_scene() -> void:
	scene = current_scene
	ship = scene.get_node("Gemi")


func _ui(action: StringName) -> void:
	for pressed in [true, false]:
		var ev := InputEventAction.new()
		ev.action = action
		ev.pressed = pressed
		Input.parse_input_event(ev)


## Düğmeyi klavyeyle seçer: odak verip ui_accept.
func _click(button: Button) -> void:
	button.grab_focus()
	_ui(&"ui_accept")


func _button(root_node: Node, text: String) -> Button:
	for b in root_node.find_children("*", "Button", true, false):
		if b.text == text:
			return b
	return null


func _release_all() -> void:
	for a in ACTIONS:
		Input.action_release(a)
	Input.action_release(&"extract")


func _shot(name: String) -> void:
	root.get_texture().get_image().save_png(OUT + "uctan_uca_%s.png" % name)


func _screen_name() -> String:
	if gm == null or scene == null or not is_instance_valid(scene):
		return "geçiş"
	match gm.state:
		STATE_MENU:
			return "ana menü"
		STATE_AUCTION:
			return "açık artırma"
		STATE_RESULT:
			return "sonuç ekranı"
	if scene.get_node("Arayuz/HazineHaritasi").visible:
		return "deniz + harita"
	return "deniz (HUD)"


func _measure(delta: float) -> void:
	if t < 1.0:
		return
	var k := _screen_name()
	if not fps_bins.has(k):
		fps_bins[k] = [0.0, 0]
		max_frame[k] = 0.0
	fps_bins[k][0] += delta
	fps_bins[k][1] += 1
	max_frame[k] = maxf(max_frame[k], delta)
	if delta > 0.05:
		long_frames.append([t, k, delta])


func _music_players() -> int:
	var n := 0
	for p in am.get_children():
		if p is AudioStreamPlayer and p.playing and p.bus == &"Music":
			n += 1
	return n


func _wreck(name: String) -> Node:
	return scene.get_node("Batiklar/" + name)


# --- Otopilot -------------------------------------------------------------------

## Rotayı başlatır; her durakta `stop_handler(wreck_index)` çağrılır ve true
## döndürünce rota sürer.
func _route_step(points: Array, stop_handler: Callable) -> Callable:
	return func():
		# Her rota adımı ilk çağrıldığında rota baştan başlar (uzun oturumda aynı
		# rota her turda yeniden kullanılır).
		if data.get("route_step", -1) != step_i:
			data["route_step"] = step_i
			route = points
			wp = 0
			wp_time = 0.0
			stop_state = ""
			on_stop = stop_handler
		return _autopilot(last_delta)


func _autopilot(delta: float) -> bool:
	# Liman alanına girince görev biter ve gemi kilitlenir; rota tamamdır.
	if gm.state != STATE_SAILING:
		_release_all()
		return true
	if wp >= route.size():
		_release_all()
		return true
	wp_time += delta
	if wp_time > 30.0:
		_check("otopilot %d. noktada takıldı (konum %s)" % [wp, ship.global_position], false)
		_shot("takildi")
		_release_all()
		wp = route.size()
		return true
	var target: Vector3 = route[wp]
	if stop_state != "":
		for a in ACTIONS:
			Input.action_release(a)
		if absf(ship.speed) > 0.3 and stop_state == "fren":
			Input.action_press(&"ship_back")
			return false
		stop_state = "durdu"
		stop_t += delta
		if on_stop.call(wp):
			stop_state = ""
			_advance()
		return false
	var to: Vector3 = Vector3(target.x, 0, target.y) - ship.global_position
	to.y = 0
	var dist: float = to.length()
	var arrive := 2.5 if target.z > 0.5 else 4.0
	if dist < arrive:
		if target.z > 0.5:
			stop_state = "fren"
			stop_t = 0.0
		else:
			_advance()
		return false
	var forward: Vector3 = -ship.global_basis.z
	var err: float = atan2(forward.cross(to.normalized()).y, forward.dot(to.normalized()))
	for a in ACTIONS:
		Input.action_release(a)
	if err > 0.05:
		Input.action_press(&"ship_left", clampf(err * 1.5, 0.2, 1.0))
	elif err < -0.05:
		Input.action_press(&"ship_right", clampf(-err * 1.5, 0.2, 1.0))
	var throttle: float = 1.0 if absf(err) < 0.9 else 0.35
	if target.z > 0.5 and dist < 9.0:
		throttle = minf(throttle, 0.45)
	Input.action_press(&"ship_forward", throttle)
	return false


func _advance() -> void:
	wp += 1
	wp_time = 0.0


## Durakta E'yi basılı tutup hazineyi çıkarır (en fazla 5 sn).
func _extract_at_stop(_index: int) -> bool:
	if not data.has("e_t0"):
		data["e_t0"] = stop_t
		data["e_before"] = extracted_count
		data["e_game0"] = gm.time_left
		Input.action_press(&"extract")
	if extracted_count > data["e_before"]:
		var game_dt: float = data["e_game0"] - gm.time_left
		data["extract_times"] = data.get("extract_times", []) + [game_dt]
		Input.action_release(&"extract")
		data.erase("e_t0")
		return true
	if stop_t - data["e_t0"] > 5.0:
		_check("durakta hazine çıkarılamadı (konum %s)" % ship.global_position, false)
		Input.action_release(&"extract")
		data.erase("e_t0")
		return true
	return false


func _connect_wrecks() -> void:
	for w in scene.get_node("Batiklar").get_children():
		w.extracted.connect(func(_w): extracted_count += 1)
		w.extraction_failed.connect(func(_w, _r): failed_count += 1)


# --- Senaryolar -----------------------------------------------------------------

func _menu_checks() -> void:
	steps.append(func():
		if step_t < 1.5:
			return false
		_connect_wrecks()
		var menu: Control = scene.get_node("Arayuz/AnaMenu")
		_check("ana menü açık, durum MENU, sayaç 120", menu.visible and gm.state == STATE_MENU and gm.time_left == 120.0)
		_check("menüde müzik (music_main) ve deniz dalgası çalıyor", am.current_music() == &"music_main" and am.is_loop_playing(&"amb_waves_beach"))
		_check("menüde HUD gizli", not scene.get_node("Arayuz/HUD").visible)
		_shot("1_menu")
		data["menu_pos"] = ship.global_position
		Input.action_press(&"ship_forward")
		return true)
	steps.append(func():
		if step_t < 1.0:
			return false
		Input.action_release(&"ship_forward")
		_check("menüdeyken gemi W ile hareket etmiyor, sayaç akmıyor", ship.global_position.distance_to(data["menu_pos"]) < 0.05 and gm.time_left == 120.0)
		_ui(&"ui_accept")
		return true)
	steps.append(func():
		if step_t < 0.3:
			return false
		_check("Oyna (ui_accept): görev başladı, HUD '%s'" % scene.get_node("Arayuz/HUD")._time_label.text, gm.state == STATE_SAILING and scene.get_node("Arayuz/HUD")._time_label.text in ["02:00", "01:59"])
		_check("Oyna tıklama sesi çaldı", &"ui_click" in sounds)
		return true)


func _build_win(first: bool) -> void:
	if first:
		_menu_checks()
	steps.append(func():
		data["t_start"] = t
		data["sail_start"] = gm.time_left
		data.erase("map_done")
		return true)
	# Rota: 1. batıktan sonraki ilk ayakta, gemi seyrederken haritayı 3 sn aç.
	var leg := _route_step(ROUTE, func(i): return _extract_at_stop(i))
	steps.append(func():
		var done: bool = leg.call()
		if first and wp == 1 and not data.has("map_done"):
			_map_while_sailing()
		return done)
	steps.append(func():
		_check("üç hazine de çıkarıldı (%d), HUD '%s'" % [gm.collected.size(), scene.get_node("Arayuz/HUD")._artifact_label.text], gm.collected.size() == 3)
		var times: Array = data.get("extract_times", [])
		_check("her çıkarma oyun saatiyle ≈ 3 sn sürdü (%s)" % [times.map(func(x): return snappedf(x, 0.01))], times.size() == 3 and times.all(func(x): return x >= 2.95 and x <= 3.6))
		_check("üç keşif sesi ve üç başarı sesi", sounds.count(&"discovery_bell") >= 3 and sounds.count(&"treasure_success") >= 3)
		return true)
	steps.append(func():
		# Liman alanına varış: görev kazanılır ve açık artırma açılır.
		if gm.state == STATE_SAILING and step_t < 8.0:
			return false
		var used: float = data["sail_start"] - gm.time_left
		print("  Görev süresi (oyun saati): %.1f sn, kalan %.1f sn" % [used, gm.time_left])
		_check("üç eserle limana varış: açık artırma açıldı", gm.state == STATE_AUCTION and scene.get_node("Arayuz/AcikArtirma").visible)
		_check("görev kazanma sesi ve açık artırma müziği", &"mission_win" in sounds and am.current_music() == &"music_auction")
		return true)
	_auction_steps([[], [true], [true, true]], 1030, "Denizlerin Efsanesi")
	if first:
		_restart_and_menu_steps()


func _map_while_sailing() -> void:
	var map: Control = scene.get_node("Arayuz/HazineHaritasi")
	if not data.has("map_t0"):
		data["map_t0"] = t
		data["map_time"] = gm.time_left
		data["map_pos"] = ship.global_position
		_ui(&"toggle_map")
	elif t - data["map_t0"] > 3.0:
		_check("seyrederken M: harita açık, gemi ilerledi (%.1f birim), süre aktı (%.2f sn)" % [ship.global_position.distance_to(data["map_pos"]), data["map_time"] - gm.time_left], map.visible and ship.global_position.distance_to(data["map_pos"]) > 2.0 and data["map_time"] - gm.time_left > 2.5)
		_check("haritada Mercan Koyu keşfedilmiş işaretli", &"coral_cove" in map.marked_wreck_ids())
		_shot("2_harita_seyir")
		_ui(&"toggle_map")
		data["map_done"] = true


## outcomes: her eser için bekleme sonuçları ([] = hemen kabul).
func _auction_steps(outcomes: Array, gold: int, rank: String) -> void:
	for i in 3:
		var waits: Array = outcomes[i]
		steps.append(func():
			var a = scene.get_node("Arayuz/AcikArtirma")
			if a._busy or a.session.index != i or a.session.phase != 1:
				return step_t > 15.0 and _fail_auction(i)
			if i == 0 and not data.has("auction_shot"):
				data["auction_shot"] = true
				_shot("4_acik_artirma")
			a.session.forced_outcomes.assign(waits)
			data["auction_waits_" + str(i)] = waits.size()
			if waits.is_empty():
				_click(a._accept)
			else:
				_click(a._wait)
			return true)
		for w in range(1, waits.size()):
			steps.append(func():
				var a = scene.get_node("Arayuz/AcikArtirma")
				if a._busy or a.session.phase != 1:
					return step_t > 15.0 and _fail_auction(i)
				_click(a._wait)
				return true)
		# Tek başarılı beklemeden sonra yükselen teklif kabul edilir (iki başarılı
		# beklemede satış otomatiktir, alıcılar çekilirse eser kapanır).
		if waits.size() == 1 and waits[0]:
			steps.append(func():
				var a = scene.get_node("Arayuz/AcikArtirma")
				if a._busy or a.session.phase != 1:
					return step_t > 15.0 and _fail_auction(i)
				_click(a._accept)
				return true)
	steps.append(func():
		if gm.state != STATE_RESULT:
			return step_t > 20.0 and _fail_auction(9)
		var overlay = scene.get_node("Arayuz/GorevSonucu")
		if step_t < 1.0:
			return false
		_check("sonuç ekranı açık: toplam %d altın (beklenen %d), rütbe '%s'" % [gm.gold, gold, overlay._rank.text], overlay.visible and gm.gold == gold and rank in overlay._rank.text)
		_check("açık artırma sesleri: satış, bekleme, rütbe", &"auction_sold" in sounds and &"auction_rank" in sounds and (gold == 580 or &"auction_waiting" in sounds))
		_shot("5_sonuc")
		return true)


func _fail_auction(i: int) -> bool:
	_check("açık artırma %d. adımda ilerlemedi" % i, false)
	return true


func _restart_and_menu_steps() -> void:
	steps.append(func():
		var overlay = scene.get_node("Arayuz/GorevSonucu")
		_click(overlay._first_button)
		return true)
	steps.append(func():
		# Müzik geçişi 1,2 sn sürer (iki oynatıcı çapraz geçişte); sonrasında sayılır.
		if step_t < 2.0:
			return false
		_bind_scene()
		_check("Yeniden Başlat: görev menüsüz başladı, sayaç %.1f, eser %d, altın %d" % [gm.time_left, gm.collected.size(), gm.gold], gm.state == STATE_SAILING and gm.time_left > 118.0 and gm.collected.is_empty() and gm.gold == 0)
		_check("yeniden başlatmada sesler birikmedi (döngü %d, müzik oynatıcı %d, efekt %d)" % [am._loops.size(), _music_players(), am.active_sfx_count()], am._loops.size() == 2 and _music_players() == 1 and am.active_sfx_count() <= 1)
		_check("deniz müziğine dönüldü", am.current_music() == &"music_main")
		_ui(&"pause")
		data["pause_time"] = gm.time_left
		return true)
	steps.append(func():
		if step_t < 1.0:
			return false
		var pm = scene.get_node("Arayuz/DuraklatmaMenusu")
		_check("Esc: duraklatma menüsü açık, oyun durdu, sayaç akmadı (%.2f → %.2f)" % [data["pause_time"], gm.time_left], pm.visible and paused and absf(gm.time_left - data["pause_time"]) < 0.05)
		_shot("6_duraklatma")
		_click(_button(pm, "Ana Menü"))
		return true)
	steps.append(func():
		if step_t < 1.0:
			return false
		_bind_scene()
		_check("Ana Menü: menü açık, durum MENU, sayaç 120, oyun duraklatılmamış", scene.get_node("Arayuz/AnaMenu").visible and gm.state == STATE_MENU and gm.time_left == 120.0 and not paused)
		return true)


func _build_lose() -> void:
	_menu_checks()
	steps.append(func(): data["sail_start"] = gm.time_left; return true)
	steps.append(_route_step(ROUTE_TWO, func(i): return _extract_at_stop(i)))
	steps.append(func():
		if step_t < 1.0:
			return false
		_check("iki hazine çıkarıldı (%d)" % gm.collected.size(), gm.collected.size() == 2)
		_check("2/3 eserle limanda: görev bitmedi, uyarı sesi çaldı", gm.state == STATE_SAILING and &"ui_denied" in sounds)
		var hud = scene.get_node("Arayuz/HUD")
		_check("limanda '3/3 eser gerekli' bildirimi: '%s'" % hud._toast_label.text, "3/3" in hud._toast_label.text)
		_shot("2_liman_eksik")
		return true)
	steps.append(func():
		# Süre gerçek zamanlı dolana kadar beklenir (sayaca dokunulmaz).
		if gm.state == STATE_SAILING:
			return false
		return true)
	steps.append(func():
		if step_t < 1.0:
			return false
		var overlay = scene.get_node("Arayuz/GorevSonucu")
		var hud = scene.get_node("Arayuz/HUD")
		_check("süre doldu: sonuç durumu, 'Süre doldu' ekranı, HUD '%s'" % hud._time_label.text, gm.state == STATE_RESULT and overlay.visible and hud._time_label.text == "00:00")
		_check("kaybetme: açık artırma açılmadı, altın 0", not scene.get_node("Arayuz/AcikArtirma").visible and gm.gold == 0)
		_check("20 sn uyarısı, son 10 sn tıkları ve kayıp sesi", sounds.count(&"timer_warning") == 1 and sounds.count(&"timer_tick") == 10 and &"mission_lose" in sounds)
		_shot("3_sure_doldu")
		_click(overlay._first_button)
		return true)
	steps.append(func():
		if step_t < 1.0:
			return false
		_bind_scene()
		_check("kayıptan Yeniden Başlat: yeni görev, sayaç %.1f" % gm.time_left, gm.state == STATE_SAILING and gm.time_left > 118.0 and gm.collected.is_empty())
		return true)


func _build_edge() -> void:
	_menu_checks()
	steps.append(_route_step(ROUTE, func(i):
		match i:
			0:
				return _pause_during_extract()
			3:
				return _map_during_extract()
			7:
				return _early_release_then_extract()
		return true))
	steps.append(func():
		if gm.state == STATE_SAILING and step_t < 8.0:
			return false
		_check("sınır senaryoları sonrası üç eser ve açık artırma", gm.collected.size() == 3 and gm.state == STATE_AUCTION)
		return true)
	_auction_steps([[], [], []], 580, "Acemi Korsan")


func _pause_during_extract() -> bool:
	var w = _wreck("MercanKoyu")
	match data.get("pz", 0):
		0:
			Input.action_press(&"extract")
			data["pz"] = 1
			data["pz_t"] = stop_t
		1:
			if stop_t - data["pz_t"] < 1.2:
				return false
			data["pz_progress"] = w.progress
			data["pz_time"] = gm.time_left
			_ui(&"pause")
			data["pz"] = 2
			data["pz_real"] = Time.get_ticks_msec()
		2:
			if Time.get_ticks_msec() - data["pz_real"] < 1500:
				return false
			_check("çıkarma sırasında Esc: oyun durdu, ilerleme (%.2f → %.2f) ve sayaç akmadı" % [data["pz_progress"], w.progress], paused and absf(w.progress - data["pz_progress"]) < 0.02 and absf(gm.time_left - data["pz_time"]) < 0.05)
			_check("duraklatınca çıkarma sesi durdu", not am.is_sfx_playing(&"extract_loop"))
			_check("duraklatmada eser verilmedi", not w.is_looted())
			_click(scene.get_node("Arayuz/DuraklatmaMenusu")._resume)
			data["pz"] = 3
			data["pz_resume"] = stop_t
		3:
			if stop_t - data["pz_resume"] < 0.4:
				return false
			print("  devam sonrası: E hâlâ basılı, ilerleme %.2f, çıkarma sesi çalıyor mu: %s, yarıda kalma sayısı %d" % [w.progress, am.is_sfx_playing(&"extract_loop"), failed_count])
			_note("devamdan sonra çıkarma sesi yeniden çalıyor", am.is_sfx_playing(&"extract_loop"))
			data["pz"] = 4
		4:
			if w.is_looted() or stop_t - data["pz_resume"] > 5.0:
				Input.action_release(&"extract")
				_check("devamdan sonra hazine alındı, başarı sesi tam 1 kez", w.is_looted() and sounds.count(&"treasure_success") == 1)
				return true
	return false


func _map_during_extract() -> bool:
	var w = _wreck("SisliGecit")
	var map: Control = scene.get_node("Arayuz/HazineHaritasi")
	match data.get("mp", 0):
		0:
			Input.action_press(&"extract")
			data["mp"] = 1
			data["mp_t"] = stop_t
		1:
			if stop_t - data["mp_t"] < 0.8:
				return false
			_ui(&"toggle_map")
			data["mp_time"] = gm.time_left
			data["mp"] = 2
		2:
			if stop_t - data["mp_t"] < 1.6:
				return false
			_check("çıkarma sırasında M: harita açıldı, süre akıyor, çıkarma sürüyor (%.2f)" % w.progress, map.visible and gm.time_left < data["mp_time"] - 0.5 and w.progress > 1.0)
			_check("haritada keşfedilen batıklar işaretli (%s)" % [map.marked_wreck_ids()], &"misty_pass" in map.marked_wreck_ids() and &"coral_cove" in map.marked_wreck_ids())
			_shot("2_harita_cikarma")
			data["mp"] = 3
		3:
			if w.is_looted() or stop_t - data["mp_t"] > 5.0:
				Input.action_release(&"extract")
				_check("harita açıkken çıkarma tamamlandı", w.is_looted())
				_ui(&"toggle_map")
				data["mp"] = 4
				return false
		4:
			_check("M ile harita kapandı", not map.visible)
			return true
	return false


func _early_release_then_extract() -> bool:
	var w = _wreck("DerinMavi")
	match data.get("er", 0):
		0:
			Input.action_press(&"extract")
			data["er"] = 1
			data["er_t"] = stop_t
			data["er_fail0"] = failed_count
		1:
			if stop_t - data["er_t"] < 1.5:
				return false
			Input.action_release(&"extract")
			data["er"] = 2
			data["er_t"] = stop_t
		2:
			if stop_t - data["er_t"] < 0.3:
				return false
			_check("E erken bırakıldı: çıkarma yarıda kaldı, eser yok, hata sesi", failed_count == data["er_fail0"] + 1 and not w.is_looted() and &"extract_fail" in sounds)
			Input.action_press(&"extract")
			data["er"] = 3
			data["er_t"] = stop_t
		3:
			if w.is_looted() or stop_t - data["er_t"] > 5.0:
				Input.action_release(&"extract")
				_check("yeniden deneme: hazine alındı", w.is_looted())
				return true
	return false


func _build_long() -> void:
	_menu_checks()
	for r in rounds:
		steps.append(func():
			data["round_t0"] = t
			data["round_fps"] = [0.0, 0, 0.0]
			data.erase("extract_times")
			sounds.clear()
			return true)
		steps.append(_route_step(ROUTE, func(i): return _extract_at_stop(i)))
		steps.append(func():
			if gm.state == STATE_SAILING and step_t < 8.0:
				return false
			_check("tur %d: üç eser, açık artırma" % (r + 1), gm.collected.size() == 3 and gm.state == STATE_AUCTION)
			return true)
		_auction_steps([[], [], []], 580, "Acemi Korsan")
		steps.append(func():
			var mem := OS.get_static_memory_usage() / 1048576.0
			var nodes := int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT))
			var objs := int(Performance.get_monitor(Performance.OBJECT_COUNT))
			var vmem := Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED) / 1048576.0
			round_rows.append([r + 1, t - data["round_t0"], mem, nodes, objs, vmem, am._loops.size(), _music_players(), am.active_sfx_count()])
			print("  tur %2d: %.1f sn, bellek %.1f MB, düğüm %d, nesne %d, video %.1f MB, döngü %d, müzik oynatıcı %d, efekt %d" % round_rows[-1])
			_click(scene.get_node("Arayuz/GorevSonucu")._first_button)
			return true)
		steps.append(func():
			if step_t < 1.0:
				return false
			_bind_scene()
			_connect_wrecks()
			extracted_count = 0
			return true)
	steps.append(func():
		var first: Array = round_rows[0]
		var last: Array = round_rows[-1]
		_check("bellek artışı 1. → %d. tur: %.1f → %.1f MB (≤ %%5)" % [rounds, first[2], last[2]], last[2] <= first[2] * 1.05)
		_check("düğüm sayısı sabit: %d → %d" % [first[3], last[3]], absi(last[3] - first[3]) <= 5)
		_check("nesne sayısı artmadı: %d → %d (≤ %%2)" % [first[4], last[4]], last[4] <= first[4] * 1.02)
		_check("ses: her turda 2 döngü ve 1 müzik oynatıcı", round_rows.all(func(row): return row[6] == 2 and row[7] == 1))
		return true)


## Ekran görüntüleri: TEST_CIKTI ortam değişkeni ya da user://test_ciktilari.
static func _cikti_klasoru() -> String:
	var d := OS.get_environment("TEST_CIKTI")
	if d.is_empty():
		d = OS.get_user_data_dir().path_join("test_ciktilari")
	DirAccess.make_dir_recursive_absolute(d)
	return d + "/"
