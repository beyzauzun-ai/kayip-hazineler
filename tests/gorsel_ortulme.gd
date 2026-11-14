extends SceneTree
## Piksel tabanlı görünürlük ölçümü: kutu yaklaşımıyla "örtülü" işaretlenen gemi
## konumlarında geminin ekranda gerçekten ne kadarının göründüğünü ölçer.
## Her konumda dört kare çizilir: (A) sahne + gemi, (B) sahne, gemi gizli,
## (C) adalar gizli + gemi, (D) adalar gizli, gemi gizli. C–D farkı geminin tam
## silüetidir; A–B farkı bu silüetin adalar varken görünen kısmıdır.
## Bitki örtüsü testinin 10 rota noktası ve kaya örtme testinin örnekleri ölçülür.
## Görünür oran ≥ %90 "açıkta" (kutu testinin yanlış pozitifi), %50–90 "kısmen
## örtülü", %50 altı "büyük ölçüde örtülü" sayılır. Yakın görüntüler bir pafta
## olarak kaydedilir. Hiçbir dosya değiştirmez.

## Bitki örtüsü testinin (cubuk_ve_ortulme) kuzey geçidinde işaretlediği 10 rota noktası.
const PLANT_POINTS := [
	Vector3(15.2, 0, -28.1), Vector3(16.0, 0, -29.0), Vector3(17.4, 0, -29.1), Vector3(18.8, 0, -29.2),
	Vector3(20.2, 0, -29.3), Vector3(21.6, 0, -29.4), Vector3(23.0, 0, -29.5), Vector3(25.8, 0, -29.7),
	Vector3(27.2, 0, -29.8), Vector3(28.6, 0, -29.9),
]
## Kaya örtme testinin (kaya_ortulme) "büyük ölçüde örtülü" saydığı 32 örnek:
## (x, z, yön derecesi). Aynı yönün iki karşıtı aynı silüeti verdiğinden konum
## başına yalnızca 0° ve 90° ölçülür.
const ROCK_POINTS := [
	Vector3(-1, -23, 90), Vector3(25, -27, 0), Vector3(25, -27, 90), Vector3(25, -29, 90),
	Vector3(27, -27, 0), Vector3(27, -27, 90), Vector3(27, -29, 90), Vector3(27, -31, 90),
	Vector3(29, -27, 0), Vector3(29, -27, 90), Vector3(29, -29, 90), Vector3(29, -31, 90),
	Vector3(31, -25, 0), Vector3(31, -25, 90), Vector3(31, -27, 0), Vector3(31, -27, 90),
]
const DIFF := 0.12

var OUT := _cikti_klasoru()
var scene: Node
var ship: Node3D
var cam: Camera3D
var islands: Node3D
var frame := 0
var samples := []
var idx := 0
var stage := 0
var wait := 0
var imgs := []
var results := []
var sheet: Image
var errors := 0
var review := 0
var rock_sheet: Image


func _initialize() -> void:
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	scene = (load("res://scenes/sea_level.tscn") as PackedScene).instantiate()
	root.add_child(scene)
	current_scene = scene
	# Rota noktaları (doğuya giden geçit, gemi doğuya bakar).
	for p in PLANT_POINTS:
		samples.append(["bitki", p, -PI * 0.5])
	for r in ROCK_POINTS:
		samples.append(["kaya", Vector3(r.x, 0, r.y), deg_to_rad(r.z)])


## Gemi çevresindeki bölge, okunan görüntünün kendi piksel boyutunda (pencere
## ölçeği 1920 tabanından farklı olabilir).
func _region(img: Image) -> Rect2i:
	var k := img.get_width() / 1920.0
	var c := cam.unproject_position(ship.global_position + Vector3(0, 2.0, 0)) * k
	var half := Vector2(150, 120) * k
	return Rect2i(Vector2i(c - half), Vector2i(half * 2.0)).intersection(Rect2i(Vector2i.ZERO, img.get_size()))


static func _mask(a: Image, b: Image) -> PackedByteArray:
	var m := PackedByteArray()
	m.resize(a.get_width() * a.get_height())
	for y in a.get_height():
		for x in a.get_width():
			var ca := a.get_pixel(x, y)
			var cb := b.get_pixel(x, y)
			m[y * a.get_width() + x] = 1 if absf(ca.r - cb.r) + absf(ca.g - cb.g) + absf(ca.b - cb.b) > DIFF else 0
	return m


func _set_state(s: int) -> void:
	ship.visible = s == 0 or s == 2
	islands.visible = s < 2


func _process(_d: float) -> bool:
	frame += 1
	if frame == 3:
		ship = scene.get_node("Gemi")
		cam = scene.get_node("Kamera")
		islands = scene.get_node("Adalar")
		scene.start_game()
		ship.set_controls_enabled(false)
		sheet = Image.create(5 * 300, 2 * 240, false, Image.FORMAT_RGBA8)
		rock_sheet = Image.create(4 * 300, 4 * 240, false, Image.FORMAT_RGBA8)
	if frame < 6:
		return false
	var s: Array = samples[idx]
	ship.reset_to(Transform3D(Basis(Vector3.UP, s[2]), s[1]))
	if wait == 0:
		_set_state(stage)
	wait += 1
	if wait < 4:
		return false
	wait = 0
	var img := root.get_texture().get_image()
	imgs.append(img.get_region(_region(img)))
	if stage == 0 and idx < 10:
		var crop: Image = imgs[0].duplicate()
		crop.resize(300, 240, Image.INTERPOLATE_BILINEAR)
		sheet.blit_rect(crop, Rect2i(0, 0, 300, 240), Vector2i((idx % 5) * 300, (idx / 5) * 240))
	elif stage == 0:
		var crop: Image = imgs[0].duplicate()
		crop.resize(300, 240, Image.INTERPOLATE_BILINEAR)
		var j := idx - PLANT_POINTS.size()
		rock_sheet.blit_rect(crop, Rect2i(0, 0, 300, 240), Vector2i((j % 4) * 300, (j / 4) * 240))
	stage += 1
	if stage < 4:
		return false
	var full := _mask(imgs[2], imgs[3])
	var seen := _mask(imgs[0], imgs[1])
	var total := 0
	var visible := 0
	for i in full.size():
		if full[i] == 1:
			total += 1
			if seen[i] == 1:
				visible += 1
	var ratio := float(visible) / maxf(total, 1.0)
	var verdict := "açıkta (kutu testinin yanlış pozitifi)" if ratio >= 0.9 else ("kısmen örtülü" if ratio >= 0.5 else "büyük ölçüde örtülü")
	results.append([s[0], s[1], ratio, verdict])
	imgs.clear()
	stage = 0
	_set_state(0)
	idx += 1
	if idx < samples.size():
		return false
	sheet.save_png(OUT + "bitki_10_nokta.png")
	rock_sheet.save_png(OUT + "kaya_16_ornek.png")
	var counts := {"bitki": {}, "kaya": {}}
	for r in results:
		print("  %-6s gemi (%.1f, %.1f): görünür %%%d → %s" % [r[0], r[1].x, r[1].z, roundi(r[2] * 100), r[3]])
		counts[r[0]][r[3]] = counts[r[0]].get(r[3], 0) + 1
	print("Özet (bitki, 10 nokta): ", counts["bitki"])
	print("Özet (kaya, 16 ölçüm): ", counts["kaya"])
	print("Paftalar: ", OUT + "bitki_10_nokta.png", " , ", OUT + "kaya_16_ornek.png")
	var hidden := results.filter(func(r): return r[2] < 0.5).size()
	var partial := results.filter(func(r): return r[2] >= 0.5 and r[2] < 0.9).size()
	_check("hiçbir ölçümde geminin yarısından fazlası örtülü değil (%d)" % hidden, hidden == 0)
	_strict("hiçbir ölçümde gemi kısmen de örtülü değil (kısmen örtülü: %d/%d)" % [partial, results.size()], partial == 0)
	print("SONUÇ: hata sayısı = %d; katı hedefi karşılanmayan (incelenecek) = %d" % [errors, review])
	return true


## Ekran görüntüleri: TEST_CIKTI ortam değişkeni ya da user://test_ciktilari.
static func _cikti_klasoru() -> String:
	var d := OS.get_environment("TEST_CIKTI")
	if d.is_empty():
		d = OS.get_user_data_dir().path_join("test_ciktilari")
	DirAccess.make_dir_recursive_absolute(d)
	return d + "/"


func _check(label: String, ok: bool) -> void:
	if not ok:
		errors += 1
	print(("  [OK]     " if ok else "  [HATA]   ") + label)


## Katı hedef: karşılanmazsa regresyon hatası sayılmaz ama açıkça "[İNCELE]"
## olarak yazılır ve SONUÇ satırında ayrıca sayılır.
func _strict(label: String, ok: bool) -> void:
	if not ok:
		review += 1
	print(("  [OK]     " if ok else "  [İNCELE] ") + "KATI HEDEF: " + label)
