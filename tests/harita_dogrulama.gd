extends SceneTree
## Hazine haritası doğrulaması (10. aşama, birleştirilmiş çizim):
## 1) Görünüm: oyundaki harita, birleştirmeden önceki çizim koduyla (aşağıdaki
##    eski_harita_referans.gd) başlangıç, her keşif ve her hazine durumunda piksel
##    piksel karşılaştırılır.
## 2) Gemi oku: 5 konum × 4 yön + 1 köşegen yönde. Ölçüm, oyundaki harita
##    betiğinin 3840×2160'lık bir SubViewport'a iki kat çözünürlükte (1920×1080
##    tabanı ×2) çizdirilmiş kopyasında yapılır; sonuçlar 1920 tabanına çevrilir.
##    İki ayrı sonuç: konum (ok çokgeninin alan ağırlık merkezi, ≤ 1 px) ve
##    rasterleştirme (sivri ucun boyanmayan kısmı, ≤ 2 px).
##    Gemi taşınınca okun 0,1 sn'lik yenilemeyle güncellendiği de denetlenir.
## 3) Davranış: M ile açılıp kapanma, harita açıkken sürenin akması, görev
##    bitince haritanın kapanması. Ayrıca harita açıkken çizim çağrısı sayısı.

const WORLD := Rect2(-60.0, -42.8, 120.0, 85.6)
const ARROW := Color("#B03A2E")
## Piksel karşılaştırma: kanal başına ortalama fark (0–255) ve belirgin fark oranı.
const MAX_MEAN_DIFF := 0.5
const MAX_BIG_DIFF_PCT := 0.05
## Gemi oku toleransları (1920 tabanında piksel) ve ölçüm çözünürlüğü çarpanı.
const ARROW_SCALE := 2
const ARROW_CENTER_TOL := 1.0
const ARROW_TIP_TOL := 2.0

var scene: Node
var gm: Node
var map: Control
var ref: Control
## Ok ölçümü için harita betiğinin ölçeksiz kopyası.
var exact_view: SubViewport
var exact_map: Control
var arrow_center_max := 0.0
var arrow_tip_max := 0.0
var ship: Node3D
var frame := 0
var errors := 0
var steps: Array[Callable] = []
var step_i := 0
var wait_frames := 0
var data := {}
var OUT := _cikti_klasoru()


func _initialize() -> void:
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	scene = (load("res://scenes/sea_level.tscn") as PackedScene).instantiate()
	root.add_child(scene)
	current_scene = scene


func _check(label: String, ok: bool) -> void:
	if not ok:
		errors += 1
	print(("  [OK]   " if ok else "  [HATA] ") + label)


func _process(_d: float) -> bool:
	frame += 1
	if frame == 4:
		gm = root.get_node("GameManager")
		map = scene.get_node("Arayuz/HazineHaritasi")
		ship = scene.get_node("Gemi")
		ref = Control.new()
		ref.set_script(load((get_script() as Script).resource_path.get_base_dir().path_join("eski_harita_referans.gd")))
		ref.name = "EskiHaritaReferans"
		scene.get_node("Arayuz").add_child(ref)
		ref.position = Vector2.ZERO
		ref.size = Vector2(1920, 1080)
		ref.setup(map._islands, map._rocks, map._port, ship, map._wrecks)
		ref.hide()
		exact_view = SubViewport.new()
		exact_view.size = Vector2i(1920, 1080) * ARROW_SCALE
		exact_view.size_2d_override = Vector2i(1920, 1080)
		exact_view.size_2d_override_stretch = true
		exact_view.disable_3d = true
		exact_view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
		scene.add_child(exact_view)
		exact_map = Control.new()
		exact_map.set_script(load("res://scripts/ui/treasure_map.gd"))
		exact_view.add_child(exact_map)
		exact_map.setup(map._islands, map._rocks, map._port, ship, map._wrecks)
		exact_map.position = Vector2.ZERO
		exact_map.size = Vector2(1920, 1080)
		exact_map.set_process_unhandled_input(false)
		exact_map.show()
		scene.start_game()
		ship.set_controls_enabled(false)
		_build_steps()
	if frame <= 4:
		return false
	if wait_frames > 0:
		wait_frames -= 1
		return false
	if step_i >= steps.size():
		print("SONUÇ: hata sayısı = %d" % errors)
		return true
	var next := steps[step_i]
	step_i += 1
	var w = next.call()
	wait_frames = w if w is int else 0
	return false


# --- Adımlar --------------------------------------------------------------------

func _build_steps() -> void:
	var wrecks: Array = map._wrecks
	steps.append(func(): gm.time_left = 999.0; ship.reset_to(Transform3D(Basis(Vector3.UP, 0.6), Vector3(-20, 0, 12))); return 2)
	_add_compare("baslangic")
	# Gemi oku (eser toplanmadan önce; üç eserle limana yaklaşmak görevi bitirir):
	# limandan uzak, açık denizde 5 konum × 4 yön.
	# Harita oku 0,1 sn'de bir yeniden çizdiği için her pozdan sonra 60 kare
	# (yüksek FPS'te de ≥ 0,25 sn) beklenir; aksi hâlde önceki pozun oku görülebilir. Beklenen yer, geminin o anki gerçek
	# konumu ve yönünden hesaplanır (harita da bunu göstermelidir).
	var poses := []
	for p in [Vector3(-10, 0, -20), Vector3(8, 0, -20), Vector3(45, 0, 6), Vector3(20, 0, 10), Vector3(-40, 0, -12)]:
		for deg in [0.0, 90.0, 180.0, 270.0]:
			poses.append([p, deg])
	poses.append([Vector3(12.3, 0, -7.7), 37.0])
	for pose in poses:
		steps.append(func(): ship.reset_to(Transform3D(Basis(Vector3.UP, deg_to_rad(pose[1])), pose[0])); map.show(); ref.hide(); return 60)
		steps.append(func(): _check_arrow(pose[0], pose[1]); return 0)
	steps.append(func():
		print("  Gemi oku (%d× ölçüm, 1920 tabanında) en büyük sapma: konum %.2f px (≤ %.0f), rasterleştirme/uç %.2f px (≤ %.0f)" % [ARROW_SCALE, arrow_center_max, ARROW_CENTER_TOL, arrow_tip_max, ARROW_TIP_TOL])
		return 0)
	# Yenileme: gemi taşınınca ok en geç ~0,1 sn içinde yeni yerinde.
	steps.append(func(): ship.reset_to(Transform3D(Basis(), Vector3(-20, 0, -25))); data["moved_ms"] = Time.get_ticks_msec(); return 0)
	steps.append(func(): return _wait_arrow(Vector3(-20, 0, -25)))
	for w in wrecks:
		steps.append(func(): gm.discover_wreck(w.wreck_id); return 2)
		_add_compare("kesif_" + String(w.wreck_id))
	for w in wrecks:
		steps.append(func(): gm.collect_artifact(w.artifact_id); return 2)
		_add_compare("hazine_" + String(w.artifact_id))
	steps.append(func(): _check("keşfedilen batık listesi 3 batığı içeriyor (%s)" % [map.marked_wreck_ids()], map.marked_wreck_ids().size() == 3); return 0)
	# Çizim çağrısı (bilgi + yeni < eski).
	steps.append(func(): map.show(); ref.hide(); return 10)
	steps.append(func(): data["calls_new"] = RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME); map.hide(); ref.show(); return 10)
	steps.append(func(): data["calls_old"] = RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME); ref.hide(); map.hide(); return 10)
	steps.append(func(): data["calls_none"] = RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME); return 0)
	steps.append(func():
		print("  Çizim çağrısı/kare: harita kapalı %d, eski harita %d (+%d), yeni harita %d (+%d)" % [data["calls_none"], data["calls_old"], data["calls_old"] - data["calls_none"], data["calls_new"], data["calls_new"] - data["calls_none"]])
		_check("yeni harita eskisinden daha az çizim çağrısı kullanıyor", data["calls_new"] < data["calls_old"])
		if map.get("_land_mesh") != null:
			var n: int = map._land_mesh.surface_get_array_len(0)
			# Köşe başına konum (2 × 4 bayt) + renk (4 × 4 bayt).
			print("  Birleşik kara/kayalık mesh'i: %d köşe, yaklaşık %.0f KB" % [n, n * 24 / 1024.0])
		return 0)
	# M tuşu ve süre.
	steps.append(func(): ship.set_controls_enabled(true); gm.time_left = 100.0; _press(&"toggle_map"); return 2)
	steps.append(func(): _check("M ile harita açıldı", map.visible); data["t_open"] = gm.time_left; data["ms_open"] = Time.get_ticks_msec(); return 60)
	steps.append(func():
		var real: float = (Time.get_ticks_msec() - data["ms_open"]) / 1000.0
		var spent: float = data["t_open"] - gm.time_left
		_check("harita açıkken süre akıyor (%.2f sn geçti, sayaç %.2f sn azaldı)" % [real, spent], spent > 0.0 and absf(spent - real) < 0.2)
		_press(&"toggle_map")
		return 2)
	steps.append(func(): _check("M ile harita kapandı", not map.visible); _press(&"toggle_map"); return 2)
	steps.append(func(): _check("M ile harita yeniden açıldı", map.visible); gm.time_left = 0.05; return 10)
	steps.append(func(): _check("görev bitince harita kapandı (durum %s)" % gm.state, not map.visible); return 0)


func _press(action: StringName) -> void:
	for pressed in [true, false]:
		var ev := InputEventAction.new()
		ev.action = action
		ev.pressed = pressed
		Input.parse_input_event(ev)


func _add_compare(label: String) -> void:
	steps.append(func(): map.show(); ref.hide(); map.queue_redraw(); return 4)
	steps.append(func(): data["new"] = root.get_texture().get_image(); map.hide(); ref.show(); ref.queue_redraw(); return 4)
	steps.append(func():
		var old := root.get_texture().get_image()
		ref.hide()
		var d := _diff(data["new"], old)
		_check("görünüm %s: yeni ↔ eski ortalama fark %.3f/255, belirgin fark %%%.3f" % [label, d[0], d[1]], d[0] <= MAX_MEAN_DIFF and d[1] <= MAX_BIG_DIFF_PCT)
		if label == "baslangic" or label.begins_with("hazine_sapphire"):
			data["new"].save_png(OUT + "harita_yeni_%s.png" % label)
			old.save_png(OUT + "harita_eski_%s.png" % label)
		return 0)


## Kâğıt bölgesinde (1920 tabanında (520,190)–(1400,890)) piksel farkı.
static func _diff(a: Image, b: Image) -> Array:
	var k := a.get_width() / 1920.0
	var r := Rect2i(Vector2i(Vector2(520, 190) * k), Vector2i(Vector2(880, 700) * k))
	var total := 0.0
	var big := 0
	var n := 0
	for y in range(r.position.y, r.end.y):
		for x in range(r.position.x, r.end.x):
			var ca := a.get_pixel(x, y)
			var cb := b.get_pixel(x, y)
			var dd := (absf(ca.r - cb.r) + absf(ca.g - cb.g) + absf(ca.b - cb.b)) / 3.0
			total += dd
			if dd > 0.1:
				big += 1
			n += 1
	return [total / n * 255.0, 100.0 * big / n]


func _expected(p: Vector3, basis: Basis, r: Rect2) -> Array:
	var pos := r.position + (Vector2(p.x, p.z) - WORLD.position) / WORLD.size * r.size
	var fwd3: Vector3 = -basis.z
	var fwd := Vector2(fwd3.x, fwd3.z).normalized()
	return [pos, fwd]


## Okun rengindeki pikseller (beklenen konumun 30 px çevresinde). `k` görüntü
## pikselinin 1920 tabanına oranıdır; piksel merkezi (+0,5) kullanılır.
func _arrow_pixels(img: Image, around: Vector2, k: float) -> Array:
	var pts := []
	for y in range(int((around.y - 30) * k), int((around.y + 30) * k)):
		for x in range(int((around.x - 30) * k), int((around.x + 30) * k)):
			var c := img.get_pixel(x, y)
			if absf(c.r - ARROW.r) + absf(c.g - ARROW.g) + absf(c.b - ARROW.b) < 0.05:
				pts.append((Vector2(x, y) + Vector2(0.5, 0.5)) / k)
	return pts


func _check_arrow(p: Vector3, deg: float) -> void:
	var e := _expected(ship.global_position, ship.global_basis, exact_map._map_rect)
	var pos: Vector2 = e[0]
	var fwd: Vector2 = e[1]
	var pts := _arrow_pixels(exact_view.get_texture().get_image(), pos, float(ARROW_SCALE))
	var label := "gemi oku (%.1f, %.1f) yön %d°" % [ship.global_position.x, ship.global_position.z, deg]
	if pts.size() < 10:
		_check(label + ": ok bulunamadı (%d piksel)" % pts.size(), false)
		return
	var c := Vector2.ZERO
	for q in pts:
		c += q
	c /= pts.size()
	# Ok çokgeni (ileri, yan): (16, 0), (-10, 9), (-5, 0), (-10, -9). İki eş üçgenin
	# alan ağırlık merkezi ileri eksende 1/3 birimdedir; uç pos + fwd * 16.
	var far := -INF
	var tip := Vector2.ZERO
	for q in pts:
		var along: float = (q - pos).dot(fwd)
		if along > far:
			far = along
			tip = q
	var dc := c.distance_to(pos + fwd / 3.0)
	var dt := tip.distance_to(pos + fwd * 16.0)
	arrow_center_max = maxf(arrow_center_max, dc)
	arrow_tip_max = maxf(arrow_tip_max, dt)
	_check("%s: konum (ağırlık merkezi) %.2f px ≤ %.0f" % [label, dc, ARROW_CENTER_TOL], dc <= ARROW_CENTER_TOL)
	_check("%s: rasterleştirme (sivri uç) %.2f px ≤ %.0f" % [label, dt, ARROW_TIP_TOL], dt <= ARROW_TIP_TOL)


func _wait_arrow(p: Vector3) -> int:
	var img := root.get_texture().get_image()
	var e := _expected(ship.global_position, ship.global_basis, map._map_rect)
	var pts := _arrow_pixels(img, e[0], img.get_width() / 1920.0)
	var waited: int = Time.get_ticks_msec() - data["moved_ms"]
	if pts.size() >= 10:
		_check("gemi taşınınca ok %d ms içinde güncellendi (≤ 200)" % waited, waited <= 200)
		return 0
	if waited > 1000:
		_check("gemi taşınınca ok güncellendi", false)
		return 0
	step_i -= 1
	return 1


## Ekran görüntüleri: TEST_CIKTI ortam değişkeni ya da user://test_ciktilari.
static func _cikti_klasoru() -> String:
	var d := OS.get_environment("TEST_CIKTI")
	if d.is_empty():
		d = OS.get_user_data_dir().path_join("test_ciktilari")
	DirAccess.make_dir_recursive_absolute(d)
	return d + "/"
