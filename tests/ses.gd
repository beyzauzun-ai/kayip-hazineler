extends SceneTree
## 9. aşama ses testi (gerçek pencere, gerçek ses sürücüsü).

const EXPECTED := {
	"music_main": 19.2, "music_auction": 18.72, "amb_waves": 24.0, "amb_waves_beach": 45.0, "amb_wind": 20.0, "ship_water": 4.0,
	"ship_creak": 0.7, "rock_hit": 0.6, "discovery_bell": 1.8, "extract_loop": 3.1, "extract_fail": 0.75,
	"treasure_success": 2.6, "ui_denied": 0.3, "timer_warning": 1.4, "timer_tick": 0.12, "mission_win": 2.4,
	"mission_lose": 2.4, "auction_waiting": 1.25, "auction_new_offer": 0.9, "auction_sold": 1.3,
	"auction_buyers_left": 1.3, "auction_rank": 2.8, "ui_click": 0.08, "ui_move": 0.06,
}

var scene: Node
var ship
var gm: Node
var am: Node
var played: Array = []
var requested: Array = []
var fails := 0
var steps: Array = []
var step_i := 0
var step_t := 0.0
var data := {}
var saved_settings := []
var peaks := {}


func _initialize() -> void:
	scene = (load("res://scenes/sea_level.tscn") as PackedScene).instantiate()
	root.add_child(scene)
	current_scene = scene
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	_build_steps()


func _bind() -> void:
	scene = current_scene
	ship = scene.get_node("Gemi")


func _process(delta: float) -> bool:
	if gm == null:
		gm = root.get_node("GameManager")
		am = root.get_node("AudioManager")
		am.sfx_played.connect(func(n): played.append(n))
		am.sfx_requested.connect(func(n): requested.append(n))
		saved_settings = [am.sound_enabled, am.music_volume, am.sfx_volume]
		_bind()
	_track_peaks()
	step_t += delta
	if step_i >= steps.size():
		am.sound_enabled = saved_settings[0]
		am.music_volume = saved_settings[1]
		am.sfx_volume = saved_settings[2]
		am.save_settings()
		print("Gözlenen en yüksek bus tepeleri (dBFS): ", peaks)
		print("SONUÇ: hata sayısı = ", fails)
		return true
	if steps[step_i].call():
		step_i += 1
		step_t = 0.0
	return false


func _track_peaks() -> void:
	for bus in ["Master", "Music", "SFX", "Ambient"]:
		var i := AudioServer.get_bus_index(bus)
		var p := maxf(AudioServer.get_bus_peak_volume_left_db(i, 0), AudioServer.get_bus_peak_volume_right_db(i, 0))
		peaks[bus] = maxf(peaks.get(bus, -200.0), p)


func _peak(bus: String) -> float:
	var i := AudioServer.get_bus_index(bus)
	return maxf(AudioServer.get_bus_peak_volume_left_db(i, 0), AudioServer.get_bus_peak_volume_right_db(i, 0))


func _build_steps() -> void:
	steps = [
		# --- Dosyalar ve döngüler ---
		func(): return _wait(0.5, func():
			var bad := []
			for name in EXPECTED:
				var s = am._get_stream(StringName(name))
				if s == null or absf(s.get_length() - EXPECTED[name]) > 0.06:
					bad.append(name)
			_check("%d ses dosyası yükleniyor, süreler beklendiği gibi %s" % [EXPECTED.size(), bad], bad.is_empty())
			var loops_ok := true
			for name in am.LOOPS:
				var w: AudioStreamWAV = am._get_stream(name)
				loops_ok = loops_ok and w.loop_mode == AudioStreamWAV.LOOP_FORWARD and absi(w.loop_end - int(round(w.get_length() * w.mix_rate))) <= 1
			_check("%d döngü dosyasında döngü uçtan uca ayarlı" % am.LOOPS.size(), loops_ok)
			var beach: AudioStreamWAV = am._get_stream(&"amb_waves_beach")
			_check("yeni dalga sesi: %.1f sn, %d Hz, stereo=%s" % [beach.get_length(), beach.mix_rate, beach.stereo], absf(beach.get_length() - 45.0) < 0.05 and beach.mix_rate == 48000 and beach.stereo)),
		# --- Menü: müzik ve ortam gerçekten çalıyor ---
		func(): return _wait(1.2, func():
			_check("menüde ana müzik çalıyor (%s)" % am.current_music(), am.current_music() == &"music_main")
			_check("menüde yeni gerçek dalga sesi çalıyor", am.is_loop_playing(&"amb_waves_beach"))
			_check("sentetik rüzgâr çalmıyor", not am.is_loop_playing(&"amb_wind"))
			_check("eski sentetik dalga sesi çalmıyor", not am.is_loop_playing(&"amb_waves"))
			_check("gemi durgun: su sesi sessiz (%.0f dB)" % am.loop_volume_db(&"ship_water"), am.loop_volume_db(&"ship_water") < -60.0)
			_check("Music bus'ında sinyal var (tepe %.1f dB)" % peaks["Music"], peaks["Music"] > -40.0)
			_check("Ambient bus'ında sinyal var (tepe %.1f dB)" % peaks["Ambient"], peaks["Ambient"] > -50.0)
			_act(&"ui_down")),
		func(): return _wait(0.2, func():
			_check("ok tuşuyla gezinme sesi (ui_move)", &"ui_move" in played)
			_act(&"ui_up")),
		# --- Ayarlar: aç/kapat ve seviyeler ---
		func(): return _wait(0.2, func():
			am.set_sound_enabled(false)
			data["mute_peaks"] = -200.0),
		func(): return _wait(0.6, func():
			var master := AudioServer.get_bus_index("Master")
			_check("Ses kapalı: Master susturuldu", AudioServer.is_bus_mute(master))
			am.set_sound_enabled(true)
			am.set_music_volume(0.5)
			am.set_sfx_volume(0.25)
			_check("Müzik %%50 → Music bus %.2f dB (beklenen −6,02)" % AudioServer.get_bus_volume_db(AudioServer.get_bus_index("Music")), absf(AudioServer.get_bus_volume_db(AudioServer.get_bus_index("Music")) + 6.02) < 0.05)
			_check("Efekt %%25 → SFX bus %.2f dB (beklenen −12,04)" % AudioServer.get_bus_volume_db(AudioServer.get_bus_index("SFX")), absf(AudioServer.get_bus_volume_db(AudioServer.get_bus_index("SFX")) + 12.04) < 0.05)
			am.set_music_volume(0.0)
			_check("Müzik %%0 → Music bus susturuldu", AudioServer.is_bus_mute(AudioServer.get_bus_index("Music")))
			am.set_music_volume(0.7)
			am.set_sfx_volume(0.8)
			_check("Ambient bus SFX'e bağlı (Efektler ayarına uyar)", AudioServer.get_bus_send(AudioServer.get_bus_index("Ambient")) == &"SFX")
			_act(&"ui_accept")),
		# --- Oyun: gemi sesleri ---
		func(): return _wait(0.6, func():
			_check("Oyna: tıklama sesi", &"ui_click" in played)
			played.clear()
			Input.action_press(&"ship_forward")),
		func(): return _wait(2.0, func():
			_check("hızlanınca pruva suyu yükseldi ama hafif kaldı (%.1f dB, beklenen yaklaşık −16)" % am.loop_volume_db(&"ship_water"), am.loop_volume_db(&"ship_water") > -18.0 and am.loop_volume_db(&"ship_water") < -14.0)
			_check("kalkışta gıcırtı (ship_creak)", &"ship_creak" in played)
			Input.action_release(&"ship_forward")
			ship.reset_to(Transform3D(Basis(Vector3.UP, deg_to_rad(-90)), Vector3(-17, 0, 19.6)))
			Input.action_press(&"ship_forward")),
		func(): return _until(func(): return &"rock_hit" in played, 4.0, func():
			Input.action_release(&"ship_forward")
			_check("kayalığa çarpınca rock_hit", &"rock_hit" in played)),
		# --- Batık: keşif, ipucu, başarısız ve başarılı çıkarma ---
		func(): return _place(Vector3(-34, 0, -9)),
		func(): return _wait(0.6, func():
			_check("keşifte discovery_bell çaldı", &"discovery_bell" in played)
			_check("SFX bus'ında sinyal var (tepe %.1f dB)" % peaks["SFX"], peaks["SFX"] > -40.0)),
		func(): return _place(Vector3(-32, 0, -3)),
		func(): return _wait(0.3, func(): played.clear(); _press_e()),
		func(): return _wait(0.3, func(): Input.action_release(&"extract"); _check("uzaktan E: ui_denied", &"ui_denied" in played)),
		func(): return _place(Vector3(-35.8, 0, -1.2)),
		func(): return _wait(0.3, func(): played.clear(); _press_e()),
		func(): return _wait(1.2, func():
			_check("E basılı: extract_loop çalıyor", am.is_sfx_playing(&"extract_loop"))
			Input.action_release(&"extract")),
		func(): return _wait(0.3, func():
			_check("erken bırakma: extract_loop durdu, extract_fail çaldı", not am.is_sfx_playing(&"extract_loop") and &"extract_fail" in played)
			_check("başarısız çıkarmada başarı sesi YOK", not (&"treasure_success" in played))
			played.clear()
			_press_e()),
		func(): return _until(func(): return &"compass" in gm.collected, 4.5, func():
			Input.action_release(&"extract")
			_check("başarılı çıkarma: treasure_success tam 1 kez, extract_fail yok", played.count(&"treasure_success") == 1 and not (&"extract_fail" in played))),
		# --- Duraklatma ---
		func(): return _wait(0.3, func():
			Input.action_press(&"ship_forward")),
		func(): return _wait(1.0, func():
			data["music_db"] = AudioServer.get_bus_volume_db(AudioServer.get_bus_index("Music"))
			_act(&"pause")),
		func(): return _wait(0.3, func():
			Input.action_release(&"ship_forward")
			_check("duraklatma: gemi suyu duraklatıldı", not am.is_loop_playing(&"ship_water"))
			var now := AudioServer.get_bus_volume_db(AudioServer.get_bus_index("Music"))
			_check("duraklatma: müzik kısıldı (%.1f → %.1f dB)" % [data["music_db"], now], now < data["music_db"] - 6.0)
			_check("duraklatma: Ambient (dalga) kısıldı (%.1f dB), dalga sürüyor" % AudioServer.get_bus_volume_db(AudioServer.get_bus_index("Ambient")), AudioServer.get_bus_volume_db(AudioServer.get_bus_index("Ambient")) < -6.0 and am.is_loop_playing(&"amb_waves_beach"))
			_act(&"ui_accept")),
		func(): return _wait(0.4, func():
			_check("devam: gemi suyu ve müzik geri geldi", am.is_loop_playing(&"ship_water") and absf(AudioServer.get_bus_volume_db(AudioServer.get_bus_index("Music")) - data["music_db"]) < 0.5)),
		# --- Süre uyarıları ve kaybetme ---
		func(): return _wait(0.0, func(): played.clear(); gm.time_left = 21.4),
		func(): return _wait(2.0, func():
			_check("20 sn kala timer_warning tam 1 kez", played.count(&"timer_warning") == 1)
			played.clear()
			gm.time_left = 10.6),
		func(): return _until(func(): return not gm.is_sailing(), 12.0, func(): pass),
		func(): return _wait(0.5, func():
			_check("son 10 saniyede tam 10 tık (%d)" % played.count(&"timer_tick"), played.count(&"timer_tick") == 10)
			_check("süre doldu: mission_lose çaldı, başarı sesi yok", &"mission_lose" in played and not (&"mission_win" in played))
			data["players_before"] = _music_players_playing()
			_act(&"ui_accept")),
		# --- Yeniden başlatma: birikme yok ---
		func(): return _wait(1.0, func():
			_bind()
			_check("yeniden başlatma: müzik kesilmedi, tek parça çalıyor (%d oynatıcı)" % _music_players_playing(), am.current_music() == &"music_main" and _music_players_playing() == 1)
			_check("yeniden başlatma: döngüler tekil (%d: %s)" % [am._loops.size(), am._loops.keys()], am._loops.size() == 2 and am.is_loop_playing(&"amb_waves_beach") and not am.is_loop_playing(&"amb_wind"))
			_check("yeniden başlatma: kalan efekt yok (%d)" % am.active_sfx_count(), am.active_sfx_count() <= 1)
			played.clear()
			for i in 20:
				am.play_sfx(&"ui_click")
				am.play_sfx(&"treasure_success")),
		func(): return _wait(0.05, func():
			_check("aynı karede 20× ui_click → bekleme süresi nedeniyle 1 kez çaldı", played.count(&"ui_click") == 1)
			var n := 0
			for p in am._sfx_players:
				if p.playing and p.stream == am._get_stream(&"treasure_success"):
					n += 1
			_check("20× treasure_success → aynı anda yalnızca 1 tanesi çalıyor (%d)" % n, n == 1)),
		func(): return _wait(0.8, func():
			_check("Master hiç kırpılmadı (en yüksek tepe %.2f dBFS ≤ −0,4)" % peaks["Master"], peaks["Master"] <= -0.4)),
		# --- Kazanma ve açık artırma ---
		func(): return _wait(0.0, func():
			played.clear()
			for a in [&"compass", &"crown", &"sapphire"]:
				gm.collect_artifact(a)
			ship.reset_to(Transform3D(Basis(Vector3.UP, deg_to_rad(90)), Vector3(-14, 0, 15)))),
		func(): return _wait(0.3, func(): Input.action_press(&"ship_forward")),
		func(): return _until(func(): return gm.state == gm.State.AUCTION, 6.0, func():
			Input.action_release(&"ship_forward")
			_check("limana varış: mission_win", &"mission_win" in played)
			scene.get_node("Arayuz/AcikArtirma").session.forced_outcomes.assign([true, false])),
		func(): return _wait(2.0, func():
			_check("açık artırmada müzik değişti (%s)" % am.current_music(), am.current_music() == &"music_auction")
			_act(&"ui_right")),
		func(): return _wait(0.2, func(): _act(&"ui_accept")),
		func(): return _wait(1.6, func():
			_check("bekle: auction_waiting ve auction_new_offer", &"auction_waiting" in played and &"auction_new_offer" in played)
			_act(&"ui_left")),
		func(): return _wait(0.2, func(): _act(&"ui_accept")),
		func(): return _wait(2.2, func():
			_check("kabul: auction_sold", &"auction_sold" in played)
			_act(&"ui_right")),
		func(): return _wait(0.2, func(): _act(&"ui_accept")),
		func(): return _wait(1.6, func():
			_check("bekle (başarısız): auction_buyers_left, yeni teklif sesi tek kez kaldı", &"auction_buyers_left" in played and played.count(&"auction_new_offer") == 1)),
		func(): return _wait(2.0, func(): _act(&"ui_accept")),
		func(): return _until(func(): return scene.get_node("Arayuz/GorevSonucu").visible, 6.0, func():
			_check("sonuç: auction_rank çaldı", &"auction_rank" in played)),
	]


func _music_players_playing() -> int:
	var n := 0
	for p in am._music_players:
		if p.playing:
			n += 1
	return n


func _place(pos: Vector3) -> bool:
	for a in [&"ship_forward", &"ship_back", &"ship_left", &"ship_right", &"extract"]:
		Input.action_release(a)
	ship.reset_to(Transform3D(Basis.IDENTITY, pos))
	return true


func _press_e() -> void:
	Input.action_press(&"extract")


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


func _check(label: String, ok: bool) -> void:
	if not ok:
		fails += 1
	print(("  [OK]   " if ok else "  [HATA] ") + label)
