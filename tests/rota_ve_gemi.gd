extends SceneTree
## 3. aşama testi: gerçek pencerede klavye girdisi (Input.action_press) ile gemi
## kontrolleri, kayalık yavaşlaması ve otopilot rotası (3 batık + liman).

var OUT := _cikti_klasoru() + "s8reg_"
const ACTIONS := [&"ship_forward", &"ship_back", &"ship_left", &"ship_right"]

## (x, z, durak mı?)
const ROUTE := [
	Vector3(-40, -3, 1), Vector3(-30, 10, 0), Vector3(-5, 9.5, 0), Vector3(11, -3, 1),
	Vector3(8, -20, 0), Vector3(16, -29, 0), Vector3(30, -30, 0), Vector3(46, -27.5, 1),
	Vector3(46, -18, 0), Vector3(45, 6, 0), Vector3(20, 10, 0), Vector3(-8, 12, 0), Vector3(-29, 15, 0),
]

var scene: Node3D
var ship
var cam: Camera3D
var step := "warmup"
var t := 0.0
var phase_t := 0.0
var fails := 0
var data := {}
var wp := 0
var stop_wait := -1.0
var rock_hits := 0
var shore_frames := 0
var wp_time := 0.0
var fps_frames := 0
var fps_time := 0.0
var shot_taken := {}


func _initialize() -> void:
	scene = (load("res://scenes/sea_level.tscn") as PackedScene).instantiate()
	root.add_child(scene)
	scene.call_deferred("start_game")
	ship = scene.get_node("Gemi")
	cam = scene.get_node("Kamera")
	ship.rock_hit.connect(func():
		rock_hits += 1
		print("    rock_hit: adim=%s t=%.2f konum=%s hiz=%.2f yavas=%s" % [step, phase_t, ship.global_position, ship.speed, ship.is_slowed()]))
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)


func _process(delta: float) -> bool:
	t += delta
	phase_t += delta
	match step:
		"warmup":
			if phase_t > 1.0:
				_shot("stage3_start")
				data["start"] = ship.global_transform
				ship.reset_to(Transform3D(Basis(Vector3.UP, deg_to_rad(-125)), Vector3(4, 0, 4)))
				_go("diag")
		"diag":
			if phase_t > 0.3:
				_shot("stage3_diagonal")
				ship.reset_to(data["start"])
				var b: Vector2 = cam.unproject_position(ship.to_global(Vector3(0, 0.5, -4.4)))
				var s: Vector2 = cam.unproject_position(ship.to_global(Vector3(0, 0.5, 3.0)))
				var scale := 1920.0 / root.get_visible_rect().size.x
				print("Gemi ekran boyu (1920 genişlikte): %.0f px (bowsprit dahil)" % (b.distance_to(s) * scale))
				_go("accel")
				_press(&"ship_forward")
		"accel":
			if not data.has("t_max") and ship.speed >= ship.max_speed - 0.01:
				data["t_max"] = phase_t
			if phase_t > 2.5:
				_check("ileri: azami hıza ulaştı (%.1f sn'de %.2f)" % [data.get("t_max", -1.0), ship.speed], data.has("t_max"))
				_release_all()
				_press(&"ship_back")
				data["brake_min_positive"] = ship.speed
				_go("brake")
		"brake":
			if ship.speed > 0.0:
				data["t_stop"] = phase_t
			if ship.speed < 0.0 and not data.has("rev_start"):
				data["rev_start"] = phase_t
			if phase_t > 2.5:
				_check("S: önce fren, %.2f sn'de durdu" % data.get("t_stop", -1.0), data.has("t_stop") and data["t_stop"] < 1.0)
				_check("S: durunca geri gitti (hız %.2f)" % ship.speed, ship.speed < -1.0)
				_release_all()
				_press(&"ship_left")
				data["yaw0"] = ship.rotation.y
				_go("turn_still")
		"turn_still":
			if phase_t > 1.0:
				var turned: float = rad_to_deg(absf(angle_difference(data["yaw0"], ship.rotation.y)))
				_check("A: dururken/yavaşken dönüyor (%.0f°/sn)" % turned, turned > 20.0)
				_release_all()
				ship.reset_to(Transform3D(Basis(Vector3.UP, deg_to_rad(-90)), Vector3(-17, 0, 19.6)))
				rock_hits = 0
				_press(&"ship_forward")
				_go("rock")
		"rock":
			if rock_hits == 0:
				data["pre_speed"] = ship.speed
			if rock_hits > 0 and not data.has("hit_speed"):
				data["hit_speed"] = ship.speed
				data["hit_t"] = phase_t
				_shot("stage3_rock")
			if data.has("hit_t") and not data.has("backed"):
				# Çarpınca geri çekil, sonra kayalıktan uzaklaşıp hızlan.
				data["backed"] = true
				_release_all()
				_press(&"ship_back")
			if data.has("hit_t") and phase_t - data["hit_t"] > 0.6 and not data.has("mid_slowed"):
				data["mid_slowed"] = ship.is_slowed()
				_release_all()
				_press(&"ship_right")
				_press(&"ship_forward")
			if phase_t > 5.0:
				_check("kayalık çarpması algılandı (%d kez)" % rock_hits, rock_hits >= 1)
				_check("çarpınca hız düştü (%.2f → çarpma anında %.2f)" % [data.get("pre_speed", -1.0), data.get("hit_speed", -1.0)], data.get("hit_speed", 99.0) <= ship.max_speed * ship.rock_slow_multiplier + 0.01)
				_check("0,6 sn sonra hâlâ yavaşlatılmış: %s" % data.get("mid_slowed"), data.get("mid_slowed", false))
				_check("yavaşlama geçti, gemi yine hızlanıyor (yavaş: %s, hız %.2f)" % [ship.is_slowed(), ship.speed], not ship.is_slowed() and ship.speed > ship.max_speed * ship.rock_slow_multiplier)
				_release_all()
				ship.reset_to(scene.get_node("OyunNoktalari/GemiBaslangic").global_transform)
				rock_hits = 0
				_go("route")
		"route":
			_autopilot(delta)
			fps_frames += 1
			fps_time += delta
			if wp >= ROUTE.size():
				print("Rota süresi (3 durak × 3 sn dahil): %.1f sn" % phase_t)
				print("Rota boyunca kayalık çarpması: %d, kıyıya sürtünen kare: %d" % [rock_hits, shore_frames])
				print("Ortalama FPS (rota sırasında, vsync kapalı): %.1f" % (fps_frames / fps_time))
				_check("rota 120 sn içinde tamamlandı", phase_t < 120.0)
				_release_all()
				print("SONUÇ: hata sayısı = ", fails)
				return true
			if wp_time > 25.0:
				_check("otopilot %d. noktada takıldı (konum %s)" % [wp, ship.global_position], false)
				_shot("stage3_stuck")
				return true
	return false


func _autopilot(delta: float) -> void:
	wp_time += delta
	if ship.get_slide_collision_count() > 0:
		shore_frames += 1
	var target: Vector3 = ROUTE[wp]
	var to: Vector3 = Vector3(target.x, 0, target.y) - ship.global_position
	to.y = 0
	var dist: float = to.length()
	if stop_wait >= 0.0:
		_release_all()
		if absf(ship.speed) > 0.3:
			_press(&"ship_back")
		else:
			stop_wait += delta
			if wp == 3 and not shot_taken.has("sisli"):
				shot_taken["sisli"] = true
				_shot("stage3_sisli")
		if stop_wait > 3.0:
			stop_wait = -1.0
			_advance()
		return
	var arrive := 2.5 if target.z > 0.5 else 4.0
	if dist < arrive:
		if target.z > 0.5:
			stop_wait = 0.0
		else:
			_advance()
		return
	var forward: Vector3 = -ship.global_basis.z
	var err: float = atan2(forward.cross(to.normalized()).y, forward.dot(to.normalized()))
	_release_all()
	if err > 0.05:
		Input.action_press(&"ship_left", clampf(err * 1.5, 0.2, 1.0))
	elif err < -0.05:
		Input.action_press(&"ship_right", clampf(-err * 1.5, 0.2, 1.0))
	var throttle: float = 1.0 if absf(err) < 0.9 else 0.35
	if target.z > 0.5 and dist < 9.0:
		throttle = minf(throttle, 0.45)
	Input.action_press(&"ship_forward", throttle)
	if wp == 5 and not shot_taken.has("gecit"):
		shot_taken["gecit"] = true
		_shot("stage3_gecit")


func _advance() -> void:
	print("  nokta %2d tamam (%5.1f sn)" % [wp, phase_t])
	wp += 1
	wp_time = 0.0


func _press(action: StringName) -> void:
	Input.action_press(action)


func _release_all() -> void:
	for a in ACTIONS:
		Input.action_release(a)


func _go(next: String) -> void:
	step = next
	phase_t = 0.0


func _shot(file: String) -> void:
	var img := root.get_texture().get_image()
	img.save_png(OUT + file + ".png")
	# Gemi çevresinden 2x yakınlaştırılmış kırpım.
	var p: Vector2 = cam.unproject_position(ship.global_position) * (Vector2(img.get_size()) / root.get_visible_rect().size)
	var w := int(img.get_width() * 0.3)
	var h := int(img.get_height() * 0.3)
	var rect := Rect2i(clampi(int(p.x) - w / 2, 0, img.get_width() - w), clampi(int(p.y) - h / 2 - h / 8, 0, img.get_height() - h), w, h)
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
