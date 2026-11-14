extends SceneTree
## HUD çakışma taraması (10. aşama, kamera kadrajı): gemi denizin ulaşılabilen her
## yerine (3 birim aralık) 4 yönde konur; ekrandaki kutusu üst HUD panelleriyle
## örtüşmemelidir. Alttaki tuş ipucu çubuğu güney kıyısında eskiden de hafifçe
## değiyordu; yalnızca bilgi olarak raporlanır. Batıklar ve oyun alanı köşeleri de
## denetlenir. Hiçbir dosya değiştirmez.

const CAMERA_POS := Vector3(0, 80.81, 59)
const CAMERA_SIZE := 133.8

var scene: Node
var ship: Node3D
var cam: Camera3D
var hud: Control
var frame := 0
var errors := 0


func _initialize() -> void:
	scene = (load("res://scenes/sea_level.tscn") as PackedScene).instantiate()
	root.add_child(scene)
	current_scene = scene


func _check(name: String, ok: bool) -> void:
	print("  [%s] %s" % ["OK" if ok else "HATA", name])
	if not ok:
		errors += 1


func _meshes(n: Node) -> Array:
	var out := []
	if n is MeshInstance3D and n.visible:
		out.append(n)
	for c in n.get_children():
		out.append_array(_meshes(c))
	return out


func _rect(node: Node3D) -> Rect2:
	var pts := []
	for m in _meshes(node):
		var a: AABB = m.global_transform * m.get_aabb()
		for i in 8:
			pts.append(cam.unproject_position(a.get_endpoint(i)))
	var r := Rect2(pts[0], Vector2.ZERO)
	for p in pts:
		r = r.expand(p)
	return r


## where: 1 üst paneller, 2 alttaki tuş ipucu çubuğu.
func _cover(r: Rect2, where: int) -> float:
	var c := 0.0
	for p in hud.get_children():
		if not (p is PanelContainer and p.visible and p.get_global_rect().size.x > 50):
			continue
		if (where == 1) != (p.position.y < 500):
			continue
		var i: Rect2 = r.intersection(p.get_global_rect())
		if i.has_area():
			c += i.get_area()
	return c / maxf(r.get_area(), 1.0)


func _reachable(pos: Vector3) -> bool:
	var q := PhysicsShapeQueryParameters3D.new()
	var sh := SphereShape3D.new()
	sh.radius = 2.2
	q.shape = sh
	q.transform = Transform3D(Basis(), Vector3(pos.x, 1.0, pos.z))
	q.exclude = [ship.get_rid()]
	if not ship.get_world_3d().direct_space_state.intersect_shape(q, 1).is_empty():
		return false
	# Adaların çarpışma silindirleri uzun lobların uçlarını tam kapsamaz; kara
	# (yüksekliği 0'dan büyük) noktalar da gemi için ulaşılamaz sayılır.
	for isl in scene.get_node("Adalar").get_children():
		if isl.has_method("surface_height"):
			var l: Vector3 = isl.to_local(pos)
			if isl.surface_height(l.x, l.z) > 0.05:
				return false
	return true


func _process(_d: float) -> bool:
	frame += 1
	if frame < 4:
		return false
	ship = scene.get_node("Gemi")
	cam = scene.get_node("Kamera")
	hud = scene.get_node("Arayuz/HUD")
	scene.start_game()
	ship.set_controls_enabled(false)
	_check("kamera onaylı kadrajda (konum %s, genişlik %.1f, açı %s)" % [cam.position, cam.size, cam.rotation_degrees],
		cam.position.is_equal_approx(CAMERA_POS) and is_equal_approx(cam.size, CAMERA_SIZE) and cam.rotation_degrees.is_equal_approx(Vector3(-52, 0, 0)))
	var y := ship.global_position.y
	var total := 0
	var top := 0
	var bottom := 0
	var bottom_worst := 0.0
	for xi in range(-55, 56, 3):
		for zi in range(-35, 36, 3):
			var p := Vector3(xi, y, zi)
			if not _reachable(p):
				continue
			for h in 4:
				ship.global_position = p
				ship.rotation = Vector3(0, h * PI * 0.5, 0)
				var r := _rect(ship)
				total += 1
				if _cover(r, 1) > 0.0:
					top += 1
				var fb := _cover(r, 2)
				if fb > 0.0:
					bottom += 1
				bottom_worst = maxf(bottom_worst, fb)
	print("Taranan örnek: %d; üst panellere değen %d; tuş ipucu çubuğuna değen %d (en fazla %%%d, bilgi)" % [total, top, bottom, roundi(bottom_worst * 100)])
	_check("gemi hiçbir konum/yönde üst HUD panellerine değmiyor", total > 1000 and top == 0)
	for path in ["Batiklar/MercanKoyu", "Batiklar/SisliGecit", "Batiklar/DerinMavi"]:
		_check("%s HUD panelleriyle örtüşmüyor" % path.get_file(), _cover(_rect(scene.get_node(path)), 1) == 0.0)
	var ok := true
	for c in [Vector3(-57, 0, -36), Vector3(57, 0, -36), Vector3(-57, 0, 36), Vector3(57, 0, 36)]:
		var v := cam.unproject_position(c)
		ok = ok and v.x >= 0 and v.x <= 1920 and v.y >= 0 and v.y <= 1080
	_check("oyun alanının dört köşesi ekranın içinde", ok)
	print("SONUÇ: hata sayısı = %d" % errors)
	return true
