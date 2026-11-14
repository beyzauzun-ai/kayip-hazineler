extends SceneTree
## 8. aşama 2. bölüm testi: çıkarma çubuğu gemi/batık/HUD ile çakışmıyor mu
## (farklı yaklaşma yönleri) ve bitki örtüsü gemiyi, batıkları, limanı örtüyor mu.

var OUT := _cikti_klasoru() + "s8b_"
## (batık adı, gemi konumu, gemi yönü derece)
const CASES := [
	["MercanKoyu", Vector3(-35.8, 0, -1.2), 30.0],
	["MercanKoyu", Vector3(-40.0, 0, 1.6), 90.0],
	["SisliGecit", Vector3(6.6, 0, -1.6), -60.0],
	["SisliGecit", Vector3(11.0, 0, -7.4), 0.0],
	["DerinMavi", Vector3(42.0, 0, -25.5), -90.0],
	["DerinMavi", Vector3(46.0, 0, -32.0), 180.0],
]
const ROUTE := [
	Vector3(-24, 0, 15), Vector3(-40, 0, -3), Vector3(-30, 0, 10), Vector3(-5, 0, 9.5), Vector3(11, 0, -3),
	Vector3(8, 0, -20), Vector3(16, 0, -29), Vector3(30, 0, -30), Vector3(46, 0, -27.5), Vector3(46, 0, -18),
	Vector3(45, 0, 6), Vector3(20, 0, 10), Vector3(-8, 0, 12), Vector3(-29, 0, 15),
]

var scene: Node
var gm: Node
var cam: Camera3D
var ship
var bar
var fails := 0
var review := 0
var frame := 0
var case_i := 0
var case_t := 0.0


func _initialize() -> void:
	scene = (load("res://scenes/sea_level.tscn") as PackedScene).instantiate()
	root.add_child(scene)
	current_scene = scene


func _process(delta: float) -> bool:
	frame += 1
	if frame == 3:
		gm = root.get_node("GameManager")
		scene.start_game()
		cam = scene.get_node("Kamera")
		ship = scene.get_node("Gemi")
		bar = scene.get_node("Arayuz/CikarmaCubugu")
		_occlusion_checks()
		_start_case()
		return false
	if frame < 3:
		return false
	gm.time_left = 999.0
	case_t += delta
	if case_t < 1.4:
		return false
	_check_case()
	Input.action_release(&"extract")
	case_i += 1
	if case_i >= CASES.size():
		print("SONUÇ: hata sayısı = %d; katı hedefi karşılanmayan (incelenecek) = %d" % [fails, review])
		return true
	_start_case()
	return false


func _start_case() -> void:
	var c: Array = CASES[case_i]
	ship.reset_to(Transform3D(Basis(Vector3.UP, deg_to_rad(c[2])), c[1]))
	case_t = 0.0
	Input.action_press(&"extract")


func _check_case() -> void:
	var c: Array = CASES[case_i]
	var wreck: Node3D = scene.get_node("Batiklar/" + c[0])
	var panel: Rect2 = bar.panel_rect()
	var avoid: Rect2 = bar.avoid_rect()
	var ship_px := cam.unproject_position(ship.global_position + Vector3(0, 1.5, 0))
	var wreck_px := cam.unproject_position(wreck.global_position)
	var hud_hit := false
	for path in ["Arayuz/HUD"]:
		for p in scene.get_node(path).get_children():
			if p is PanelContainer and p.visible and p.get_global_rect().intersects(panel):
				hud_hit = true
	var label := "%s, gemi %s yön %d°" % [c[0], c[1], c[2]]
	_check("%s: çubuk görünür (%.0f%%)" % [label, wreck.progress / 3.0 * 100.0], panel.size.x > 0.0)
	_check("%s: çubuk gemi+batık kutusuyla kesişmiyor (çubuk %s, kutu %s)" % [label, _r(panel), _r(avoid)], not panel.intersects(avoid))
	_check("%s: geminin ve batığın merkezi açıkta" % label, not panel.grow(8).has_point(ship_px) and not panel.grow(8).has_point(wreck_px))
	_check("%s: üst HUD panelleriyle ve ekran kenarıyla çakışmıyor" % label, not hud_hit and Rect2(0, 0, 1920, 1080).encloses(panel))
	var img := root.get_texture().get_image()
	var k := Vector2(img.get_size()) / Vector2(1920, 1080)
	var region := Rect2i(Vector2i(avoid.merge(panel).grow(60).position * k), Vector2i(avoid.merge(panel).grow(60).size * k))
	region = region.intersection(Rect2i(Vector2i.ZERO, img.get_size()))
	var crop := img.get_region(region)
	crop.resize(crop.get_width() * 2, crop.get_height() * 2, Image.INTERPOLATE_LANCZOS)
	crop.save_png(OUT + "cubuk_%d.png" % case_i)


## Bitki ve kayaların ekran kutuları; hedef noktayı kameraya daha yakın bir
## süs örtüyorsa sayılır. (Ortografik kamera güneyden baktığı için "önde" = daha büyük z.)
func _occlusion_checks() -> void:
	var covers := []
	for isl in scene.get_node("Adalar").get_children():
		if not isl.has_method("surface_height"):
			continue
		for o in isl._occupied:
			if o.z > 1.6:
				continue
			var base: Vector3 = isl.position + Vector3(o.x, isl.surface_height(o.x, o.y), o.y)
			covers.append([base, _box(base, Vector3(1.8, 0.0, 7.5))])
	var targets := {}
	for w in scene.get_node("Batiklar").get_children():
		targets["batık " + w.name] = w.global_position
	targets["liman alanı"] = scene.get_node("OyunNoktalari/LimanAlani").global_position
	var blocked := 0
	for key in targets:
		var p: Vector3 = targets[key]
		var px := cam.unproject_position(p + Vector3(0, 0.5, 0))
		var hit := false
		for c in covers:
			if c[0].z > p.z + 1.0 and c[1].has_point(px):
				hit = true
		_check("bitki örtüsü %s noktasını örtmüyor" % key, not hit)
	var samples := 0
	for i in ROUTE.size() - 1:
		for t in 10:
			var p: Vector3 = ROUTE[i].lerp(ROUTE[i + 1], t / 10.0)
			var px := cam.unproject_position(p + Vector3(0, 1.5, 0))
			samples += 1
			for c in covers:
				if c[0].z > p.z + 1.0 and c[1].has_point(px):
					blocked += 1
					print("    örtülü: gemi %s ← süs %s" % [p.snapped(Vector3.ONE * 0.1), c[0].snapped(Vector3.ONE * 0.1)])
					break
	print("  Rota boyunca %d örnekten %d tanesinde gemi merkezi bir ağaç/palmiye kutusunun arkasında" % [samples, blocked])
	# İki ayrı sonuç: (1) regresyon — 9. aşama yedeğinde ve Yontulmuş kayalarla
	# ölçülen 10 örnekten fazlası kötüleşme sayılır; (2) katı hedef — rotada hiçbir
	# örnek kutu testinde örtülü çıkmamalı. Bu 10 noktanın piksel ölçümü için
	# gorsel_ortulme.gd'ye bakın (9'u gerçekte açıkta, 1'i kısmen örtülü).
	_check("REGRESYON: bitki örtüsü arkasında kalan rota örneği önceki sürüme göre artmadı (%d/%d, önceki 10)" % [blocked, samples], blocked <= 10)
	_strict("rotada gemi hiçbir noktada bitki örtüsü kutusunun arkasında değil (%d/%d)" % [blocked, samples], blocked == 0)


func _box(center: Vector3, extent: Vector3) -> Rect2:
	var box := Rect2(cam.unproject_position(center), Vector2.ZERO)
	for sx in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			for y in [extent.y, extent.z]:
				box = box.expand(cam.unproject_position(center + Vector3(sx * extent.x, y, sz * extent.x)))
	return box


static func _r(r: Rect2) -> String:
	return "(%d,%d %dx%d)" % [r.position.x, r.position.y, r.size.x, r.size.y]


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


## Katı hedef: karşılanmazsa regresyon hatası sayılmaz ama açıkça "[İNCELE]"
## olarak yazılır ve SONUÇ satırında ayrıca sayılır.
func _strict(label: String, ok: bool) -> void:
	if not ok:
		review += 1
	print(("  [OK]     " if ok else "  [İNCELE] ") + "KATI HEDEF: " + label)
