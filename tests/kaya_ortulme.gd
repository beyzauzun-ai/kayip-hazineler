extends SceneTree
## Kaya örtme testi (10. aşama, Yontulmuş kayalar): gemi denizin ulaşılabilen her
## yerine (2 birim aralık) 4 yönde konur. Kameraya gemiden daha yakın duran bir
## kayanın ekran kutusu geminin noktalarını (pruva, orta, kıç, direk tepesi)
## kapatıyor mu? Ada kayaları ve denizdeki kayalıklar denetlenir; kaya yüksekliği
## gerçek kaya mesh'lerinden alınır. Ayrıca kayalık çarpışma şekilleri sayılır.

var scene: Node
var ship: Node3D
var cam: Camera3D
var frame := 0
var errors := 0
var review := 0


func _initialize() -> void:
	scene = (load("res://scenes/sea_level.tscn") as PackedScene).instantiate()
	root.add_child(scene)
	current_scene = scene


func _check(name: String, ok: bool) -> void:
	print("  [%s] %s" % ["OK" if ok else "HATA", name])
	if not ok:
		errors += 1


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


## Kayalar: [taban merkezi (dünya), yarıçap, yükseklik]
func _rocks() -> Array:
	var top := 0.0
	var bottom := 0.0
	for v in 5:
		var a: AABB = PropLibrary.rock(v).get_aabb()
		top = maxf(top, a.end.y)
		bottom = minf(bottom, a.position.y)
	var out := []
	for isl in scene.get_node("Adalar").get_children():
		if not isl.has_method("surface_height"):
			continue
		for r in isl.rocks:
			var ground: float = isl.surface_height(r.x, r.y)
			var base: Vector3 = isl.to_global(Vector3(r.x, ground - r.z * 0.15, r.y))
			out.append([base, r.z * 0.6, (top - bottom) * r.z * r.w])
	var sea: Node3D = scene.get_node("Kayaliklar")
	for r in sea.rocks:
		out.append([sea.to_global(Vector3(r.x, -0.15 * r.z, r.y)), r.z * 0.6, (top - bottom) * r.z * r.w])
	return out


func _box(base: Vector3, radius: float, height: float) -> Rect2:
	var box := Rect2(cam.unproject_position(base), Vector2.ZERO)
	for sx in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			for y in [0.0, height]:
				box = box.expand(cam.unproject_position(base + Vector3(sx * radius, y, sz * radius)))
	return box


func _process(_d: float) -> bool:
	frame += 1
	if frame < 4:
		return false
	ship = scene.get_node("Gemi")
	cam = scene.get_node("Kamera")
	scene.start_game()
	ship.set_controls_enabled(false)
	var rocks := _rocks()
	print("Denetlenen kaya: %d (ada kayaları + denizdeki kayalıklar)" % rocks.size())
	var total := 0
	var partly := 0
	var mostly := 0
	var worst := ""
	var y := ship.global_position.y
	for xi in range(-55, 56, 2):
		for zi in range(-35, 36, 2):
			var p := Vector3(xi, y, zi)
			if not _reachable(p):
				continue
			for h in 4:
				var fwd := Vector3(sin(h * PI * 0.5), 0, cos(h * PI * 0.5))
				# Gemi ≈ 6,5 birim boyunda; direk tepesi ≈ 5 birim yukarıda.
				var pts := [p, p + fwd * 3.0, p - fwd * 3.0, p + Vector3(0, 5.0, 0)]
				var hidden := 0
				for q in pts:
					var sp := cam.unproject_position(q)
					for r in rocks:
						if r[0].z > q.z + r[1] * 0.5 and _box(r[0], r[1], r[2]).has_point(sp):
							hidden += 1
							break
				total += 1
				if hidden > 0:
					partly += 1
				if hidden >= 3:
					mostly += 1
					worst = "(%d, %d) yön %d°" % [xi, zi, h * 90]
	print("Taranan örnek: %d; bir noktası kaya arkasında kalan %d; büyük ölçüde kaya arkasında kalan %d %s" % [total, partly, mostly, worst])
	# İki ayrı sonuç: (1) regresyon — eski yuvarlak kayalarla 40, Yontulmuş
	# kayalarla 32 örnek ölçüldü (32'si de eski 40'ın içinde); fazlası kötüleşme
	# sayılır. (2) katı hedef — hiçbir örnekte gemi kutu testinde büyük ölçüde
	# kaya arkasında olmamalı. Piksel ölçümü için gorsel_ortulme.gd'ye bakın.
	_check("REGRESYON: kaya arkasında büyük ölçüde kalan örnek önceki sürüme göre artmadı (%d, önceki 32; eski kayalarla 40)" % mostly, total > 1000 and mostly <= 32)
	_strict("gemi hiçbir örnekte kayaların arkasında büyük ölçüde kalmıyor (%d/%d)" % [mostly, total], mostly == 0)
	var sea: Node3D = scene.get_node("Kayaliklar")
	var shapes := sea.find_children("*", "CollisionShape3D", true, false).size()
	print("Denizdeki kayalık çarpışma şekli: %d (kayalık sayısı %d)" % [shapes, sea.rocks.size()])
	_check("her denizdeki kayalığın bir çarpışma şekli var", shapes == sea.rocks.size())
	print("SONUÇ: hata sayısı = %d; katı hedefi karşılanmayan (incelenecek) = %d" % [errors, review])
	return true


## Katı hedef: karşılanmazsa regresyon hatası sayılmaz ama açıkça "[İNCELE]"
## olarak yazılır ve SONUÇ satırında ayrıca sayılır.
func _strict(label: String, ok: bool) -> void:
	if not ok:
		review += 1
	print(("  [OK]     " if ok else "  [İNCELE] ") + "KATI HEDEF: " + label)
