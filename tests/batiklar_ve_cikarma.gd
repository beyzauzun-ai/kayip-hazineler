extends SceneTree
## 4. aşama testi (gerçek pencere): keşif, başarısız çıkarma türleri, ipuçları,
## başarılı çıkarma, tekrar ödül verilmemesi, ses istekleri, FPS ve ekran görüntüleri.

var OUT := _cikti_klasoru() + "s8reg_"

var scene: Node3D
var ship
var cam: Camera3D
var wrecks := {}
var sounds: Array[StringName] = []
var events: Array[String] = []
var fails := 0
var steps: Array = []
var step_i := 0
var step_t := 0.0
var data := {}
var gm: Node
var am: Node


func _initialize() -> void:
	scene = (load("res://scenes/sea_level.tscn") as PackedScene).instantiate()
	root.add_child(scene)
	scene.call_deferred("start_game")
	ship = scene.get_node("Gemi")
	cam = scene.get_node("Kamera")
	for w in scene.get_node("Batiklar").get_children():
		wrecks[w.name] = w
		w.discovered.connect(func(x): events.append("discovered:" + x.name))
		w.extraction_failed.connect(func(x, r): events.append("failed:%s:%s" % [x.name, r]))
		w.extracted.connect(func(x): events.append("extracted:" + x.name))
		w.hint.connect(func(x, h): events.append("hint:%s:%s" % [x.name, h]))

	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	_build_steps()


func _process(delta: float) -> bool:
	if gm == null:
		gm = root.get_node("GameManager")
		am = root.get_node("AudioManager")
		am.sfx_requested.connect(func(n): sounds.append(n))
	gm.time_left = 999.0
	step_t += delta
	if step_i >= steps.size():
		print("SONUÇ: hata sayısı = ", fails)
		return true
	var done: bool = steps[step_i].call()
	if done:
		step_i += 1
		step_t = 0.0
	return false


func _build_steps() -> void:
	var mercan = wrecks["MercanKoyu"]
	var sisli = wrecks["SisliGecit"]
	var deep = wrecks["DerinMavi"]
	steps = [
		func(): return _wait(1.0, func(): _shot("stage4_overview", false)),
		# --- Keşif ---
		func(): return _place(Vector3(-30, 0, -14), 0.0),
		func(): return _wait(1.5, func():
			data["far_reveal"] = mercan.reveal
			_check("15 birimde henüz keşfedilmedi", not mercan.is_discovered())),
		func(): return _place(Vector3(-34, 0, -9), 0.0),
		func(): return _wait(1.5, func():
			_check("8,5 birimde keşfedildi ve GameManager'a işlendi (%s)" % str(gm.discovered), &"coral_cove" in gm.discovered)
			_check("keşif sinyali bir kez yayınlandı", events.count("discovered:MercanKoyu") == 1)
			_check("keşif çanı istendi", &"discovery_bell" in sounds)
			_check("göstergeler belirginleşti (reveal %.2f → %.2f)" % [data["far_reveal"], mercan.reveal], mercan.reveal > data["far_reveal"] + 0.2)),
		# --- Başarısız: erken bırakma ---
		func(): return _place(Vector3(-37, 0, -3), 0.0),
		func(): return _wait(0.6, func(): _mark(); Input.action_press(&"extract")),
		func(): return _wait(1.5, func(): data["mid_progress"] = mercan.progress; Input.action_release(&"extract")),
		func(): return _wait(0.3, func():
			_check("E basılıyken ilerleme arttı (%.2f sn)" % data["mid_progress"], data["mid_progress"] > 1.2)
			_expect_fail(mercan, "E erken bırakıldı")),
		# --- Başarısız: gemi hareket etti ---
		func(): return _wait(0.3, func(): _mark(); Input.action_press(&"extract")),
		func(): return _wait(1.0, func(): Input.action_press(&"ship_forward")),
		func(): return _wait(0.6, func():
			Input.action_release(&"ship_forward")
			Input.action_release(&"extract")
			_expect_fail(mercan, "gemi hareket etti")),
		# --- Başarısız: uzaklaştı ---
		func(): return _place(Vector3(-37, 0, -3), 0.0),
		func(): return _wait(0.5, func(): _mark(); Input.action_press(&"extract")),
		func(): return _wait(1.0, func(): ship.reset_to(Transform3D(Basis.IDENTITY, Vector3(-31, 0, -3)))),
		func(): return _wait(0.3, func():
			Input.action_release(&"extract")
			_expect_fail(mercan, "batıktan uzaklaştın")),
		# --- İpucu: hareket halindeyken E ---
		func(): return _place(Vector3(-37, 0, -3), deg_to_rad(90)),
		func(): return _wait(0.3, func(): Input.action_press(&"ship_forward")),
		func(): return _wait(0.5, func(): _mark(); Input.action_press(&"extract")),
		func(): return _wait(0.4, func():
			Input.action_release(&"extract")
			Input.action_release(&"ship_forward")
			_check("hareket halindeyken E: '%s'" % _last_hint(), _last_hint() == "Önce gemiyi durdur!")
			_check("hareket halindeyken çıkarma başlamadı", mercan.progress == 0.0 and not (&"extract_loop" in _new_sounds()))),
		# --- İpucu: uzaktan E ---
		func(): return _place(Vector3(-32, 0, -3), 0.0),
		func(): return _wait(0.4, func(): _mark(); Input.action_press(&"extract")),
		func(): return _wait(0.3, func():
			Input.action_release(&"extract")
			_check("uzaktan E: '%s'" % _last_hint(), _last_hint() == "Batığa daha çok yaklaş!")),
		# --- Başarılı: Mercan Koyu ---
		func(): return _place(Vector3(-36.5, 0, -1.5), deg_to_rad(30)),
		func(): return _wait(1.2, func(): _shot("stage4_mercan", true); _mark(); data["t0"] = Time.get_ticks_msec(); Input.action_press(&"extract")),
		func(): return _until(func(): return mercan.is_looted(), 5.0, func():
			data["dur"] = (Time.get_ticks_msec() - data["t0"]) / 1000.0
			Input.action_release(&"extract")
			_expect_success(mercan, &"compass", 1)),
		# --- Tekrar ödül yok ---
		func(): return _wait(0.5, func(): _mark(); Input.action_press(&"extract")),
		func(): return _wait(3.6, func():
			Input.action_release(&"extract")
			_check("aynı batık ikinci kez ödül vermedi (eser sayısı %d)" % gm.collected.size(), gm.collected.size() == 1)
			_check("ikinci denemede başarı sesi yok", not (&"treasure_success" in _new_sounds()))
			_check("ikinci denemede ipucu: '%s'" % _last_hint(), _last_hint() == "Bu batığın hazinesi zaten alındı.")),
		# --- Başarılı: Sisli Geçit (referanstaki konum) ---
		func(): return _place(Vector3(7.5, 0, -1.5), deg_to_rad(-60)),
		func(): return _wait(1.5, func(): _mark(); data["t0"] = Time.get_ticks_msec(); Input.action_press(&"extract")),
		func(): return _wait(1.8, func(): _shot("stage4_sisli_progress", true)),
		func(): return _wait(0.7, func(): _check("2,5 sn basılıyken eser henüz verilmedi (ilerleme %.2f sn)" % sisli.progress, not sisli.is_looted() and sisli.progress > 2.3)),
		func(): return _until(func(): return sisli.is_looted(), 3.0, func():
			Input.action_release(&"extract")
			_expect_success(sisli, &"crown", 2)),
		func(): return _wait(0.25, func(): _shot("stage4_sisli_success", true)),
		# --- Başarılı: Derin Mavi ---
		func(): return _place(Vector3(42.5, 0, -25.5), deg_to_rad(-90)),
		func(): return _wait(1.5, func(): _shot("stage4_deep", true); _mark(); data["t0"] = Time.get_ticks_msec(); Input.action_press(&"extract")),
		func(): return _until(func(): return deep.is_looted(), 5.0, func():
			Input.action_release(&"extract")
			_expect_success(deep, &"sapphire", 3)),
		# --- Özet ve FPS ---
		func(): return _place(Vector3(4, 0, 2), deg_to_rad(-60)),
		func(): return _wait(0.5, func(): data["f0"] = Engine.get_process_frames(); data["ft"] = Time.get_ticks_msec()),
		func(): return _wait(3.0, func():
			var fps: float = (Engine.get_process_frames() - data["f0"]) / ((Time.get_ticks_msec() - data["ft"]) / 1000.0)
			print("Ortalama FPS (3 batık + efektler, vsync kapalı): %.1f" % fps)
			print("Çizim çağrısı/kare: ", RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME))
			_check("toplam başarı sesi = 3, başarısızlık sesi = 3", sounds.count(&"treasure_success") == 3 and sounds.count(&"extract_fail") == 3)
			_check("GameManager: 3/3 eser, 3 keşif", gm.has_all_artifacts() and gm.discovered.size() == 3)),
	]


# --- Yardımcılar --------------------------------------------------------------------

func _place(pos: Vector3, yaw: float) -> bool:
	for a in [&"ship_forward", &"ship_back", &"ship_left", &"ship_right", &"extract"]:
		Input.action_release(a)
	ship.reset_to(Transform3D(Basis(Vector3.UP, yaw), pos))
	return true


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


func _mark() -> void:
	data["sound_mark"] = sounds.size()
	data["event_mark"] = events.size()


func _new_sounds() -> Array:
	return sounds.slice(data.get("sound_mark", 0))


func _new_events() -> Array:
	return events.slice(data.get("event_mark", 0))


func _last_hint() -> String:
	for i in range(events.size() - 1, data.get("event_mark", 0) - 1, -1):
		if events[i].begins_with("hint:"):
			return events[i].get_slice(":", 2)
	return ""


func _expect_fail(w, reason: String) -> void:
	var ev := _new_events()
	var snd := _new_sounds()
	_check("başarısız (%s): olay %s" % [reason, ev], ("failed:%s:%s" % [w.name, reason]) in ev)
	_check("başarısız (%s): ilerleme sıfırlandı (%.2f)" % [reason, w.progress], w.progress == 0.0)
	_check("başarısız (%s): hata sesi var, başarı sesi YOK %s" % [reason, snd], &"extract_fail" in snd and not (&"treasure_success" in snd))
	_check("başarısız (%s): eser verilmedi" % reason, not w.is_looted())


func _expect_success(w, artifact: StringName, count: int) -> void:
	var snd := _new_sounds()
	_check("%s: eser alındı (%s, %d/3)" % [w.name, artifact, gm.collected.size()], artifact in gm.collected and gm.collected.size() == count)
	_check("%s: başarı sesi tam 1 kez, hata sesi yok %s" % [w.name, snd], snd.count(&"treasure_success") == 1 and not (&"extract_fail" in snd))
	if data.has("t0"):
		var dur: float = (Time.get_ticks_msec() - data["t0"]) / 1000.0
		_check("%s: çıkarma süresi %.2f sn (≈3; duvar saati, ekran görüntüsü kaydı dahil)" % [w.name, dur], dur > 2.8 and dur < 3.35)
		data.erase("t0")


func _shot(file: String, zoom: bool) -> void:
	var img := root.get_texture().get_image()
	img.save_png(OUT + file + ".png")
	if not zoom:
		return
	var p := cam.unproject_position(ship.global_position) * (Vector2(img.get_size()) / root.get_visible_rect().size)
	var w := int(img.get_width() * 0.36)
	var h := int(img.get_height() * 0.36)
	var rect := Rect2i(clampi(int(p.x) - w / 2, 0, img.get_width() - w), clampi(int(p.y) - h * 2 / 3, 0, img.get_height() - h), w, h)
	var crop := img.get_region(rect)
	crop.resize(w * 2, h * 2, Image.INTERPOLATE_LANCZOS)
	crop.save_png(OUT + file + "_zoom.png")


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
