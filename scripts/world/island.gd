@tool
class_name Island
extends Node3D
## Örtüşen yuvarlak tepeciklerden (lob) masalsı bir ada üretir: kum kıyı, dik
## toprak yamacı üzerinde çimen platosu, isteğe bağlı iç yükseltiler, kıyı
## kayaları, palmiyeler, ağaç kümeleri, çalılar, isteğe bağlı şelale, köpük ve
## çarpışma. Tüm konumlar adanın yerel koordinatlarındadır.
## Otomatik süsler (kıyı kayaları, ağaç/palmiye/çalı) tohumla üretilir; her
## açılışta aynıdır ve yalnızca görseldir (çarpışma yalnızca loblardan gelir).

const SAND_HEIGHT := 0.7
## Yamaçsız adalarda (liman) çimen tepeciği.
const GRASS_HEIGHT := 2.2
const GRASS_RATIO := 0.8
## Yamaçlı adalarda: dik toprak bandı ve üstündeki çimen platosu.
const EARTH_RATIO := 0.86
const EARTH_HEIGHT := 1.4
## Çimen platosu yamacın düz tepesini tamamen örtecek kadar geniş ve yüksek
## (aksi hâlde her lobun yamaç kenarı çimen içinde bej halka olarak görünür).
const PLATEAU_GRASS_RATIO := 0.84
const PLATEAU_GRASS_HEIGHT := 2.35
## İç yükseltiler platonun üstünden başlar.
const HIGHLAND_BASE := 1.9
const HIGHLAND_EARTH_HEIGHT := 1.5
const HIGHLAND_GRASS_HEIGHT := 2.4
const HIGHLAND_GRASS_RATIO := 0.96
const SHALLOW_WIDTH := 4.5
## Kum meydanı (liman) yüksekliği ve rengi.
const PLAZA_HEIGHT := 1.0
const PLAZA_RATIO := 0.9

## Lob: (x, z, yarıçap_x, yarıçap_z)
@export var lobes := PackedVector4Array()
## İç yükseltiler: (x, z, yarıçap_x, yarıçap_z); lobların içinde kalmalı.
@export var highlands := PackedVector4Array()
## Kaya: (x, z, boyut, dikey_uzama)
@export var rocks := PackedVector4Array()
## Palmiye / ağaç: (x, z, ölçek)
@export var palms := PackedVector3Array()
@export var trees := PackedVector3Array()
## false ise yamaç ve plato yerine tek çimen tepeciği kullanılır (liman adası).
@export var cliffs := true
## Çimen yerine yükseltilmiş kum meydanı olan lobların sıra numaraları (liman).
@export var plaza_lobes := PackedInt32Array()
@export_group("Otomatik süsler")
## Çimen alanına dağıtılan çalı yoğunluğu (birim alan başına).
@export var bush_density := 0.09
## Plato iç kesimindeki ağaç yoğunluğu (birim alan başına).
@export var tree_density := 0.1
## Kumsala dizilen palmiye ve kıyı kayası yoğunluğu (birim çevre başına).
@export var palm_density := 0.025
@export var shore_rock_density := 0.06
@export var decoration_seed := 1
@export_group("Şelale")
@export var waterfall_width := 0.0
@export var waterfall_top := Vector3.ZERO
@export var waterfall_bottom := Vector3.ZERO
@export_group("")
@export_tool_button("Yeniden Oluştur", "Reload") var rebuild_action: Callable = rebuild

## Otomatik yerleşimde çakışmayı önlemek için dolu noktalar: (x, z, yarıçap).
var _occupied: Array[Vector3] = []
## Son yeniden oluşturmada otomatik yerleşen ağaç sayısı (ölçüm için).
var _tree_count := 0
## Uzun bitkiler (ağaç, palmiye): (x, z, tepe yüksekliği); görünürlük testleri için.
var tall_plants: Array[Vector3] = []


func _ready() -> void:
	rebuild()


func rebuild() -> void:
	PropLibrary.clear_generated(self)
	_occupied.clear()
	_tree_count = 0
	tall_plants.clear()
	var rng := RandomNumberGenerator.new()
	rng.seed = decoration_seed
	var body := PropLibrary.add_static_body(self, PropLibrary.LAYER_WORLD)
	var batch := MeshBatcher.new()
	var rock_batch := MeshBatcher.new()
	var foam := MeshBatcher.new()
	var shallow := MeshBatcher.new()

	for i in lobes.size():
		var lobe := lobes[i]
		var center := Vector3(lobe.x, 0.0, lobe.y)
		var grass_color := PropLibrary.GRASS if i % 2 == 0 else PropLibrary.GRASS_ALT
		batch.add(PropLibrary.mound(), Transform3D(Basis.from_scale(Vector3(lobe.z, SAND_HEIGHT, lobe.w)), center), PropLibrary.SAND)
		if i in plaza_lobes:
			batch.add(PropLibrary.plateau(), Transform3D(Basis.from_scale(Vector3(lobe.z * PLAZA_RATIO, PLAZA_HEIGHT, lobe.w * PLAZA_RATIO)), center), PropLibrary.SAND.darkened(0.04), 0.1)
		elif cliffs:
			batch.add(PropLibrary.cliff(), Transform3D(Basis.from_scale(Vector3(lobe.z * EARTH_RATIO, EARTH_HEIGHT, lobe.w * EARTH_RATIO)), center), PropLibrary.EARTH, 0.35)
			batch.add(PropLibrary.plateau(), Transform3D(Basis.from_scale(Vector3(lobe.z * PLATEAU_GRASS_RATIO, PLATEAU_GRASS_HEIGHT, lobe.w * PLATEAU_GRASS_RATIO)), center), grass_color, 0.12)
		else:
			batch.add(PropLibrary.mound(), Transform3D(Basis.from_scale(Vector3(lobe.z * GRASS_RATIO, GRASS_HEIGHT, lobe.w * GRASS_RATIO)), center), grass_color, 0.12)
		foam.add(PropLibrary.ring(lobe.z, lobe.w, 1.1), Transform3D(Basis.IDENTITY, center + Vector3(0.0, 0.04, 0.0)))
		shallow.add(PropLibrary.ring(lobe.z, lobe.w, SHALLOW_WIDTH), Transform3D(Basis.IDENTITY, center + Vector3(0.0, 0.02, 0.0)))
		PropLibrary.add_cylinder_shape(body, center, (lobe.z + lobe.w) * 0.5 * 0.95)

	for i in highlands.size():
		var h := highlands[i]
		var base := Vector3(h.x, HIGHLAND_BASE, h.y)
		batch.add(PropLibrary.cliff(), Transform3D(Basis.from_scale(Vector3(h.z, HIGHLAND_EARTH_HEIGHT, h.w)), base), PropLibrary.EARTH.darkened(0.05), 0.35)
		batch.add(PropLibrary.plateau(), Transform3D(Basis.from_scale(Vector3(h.z * HIGHLAND_GRASS_RATIO, HIGHLAND_GRASS_HEIGHT, h.w * HIGHLAND_GRASS_RATIO)), base), PropLibrary.GRASS_ALT if i % 2 == 0 else PropLibrary.GRASS, 0.12)

	for r in rocks:
		var ground := surface_height(r.x, r.y)
		PropLibrary.add_rock(rock_batch, Vector3(r.x, ground - r.z * 0.15, r.y), r.z, r.w, rng)
		_occupy(r.x, r.y, r.z * 0.45)
		if ground < 0.25:
			foam.add(PropLibrary.ring(r.z * 0.9, r.z * 0.85, 0.7), Transform3D(Basis.IDENTITY, Vector3(r.x, 0.04, r.y)))
			PropLibrary.add_cylinder_shape(body, Vector3(r.x, 0.0, r.y), r.z * 0.85)
	# Dolu alan yarıçapları gövde/taç boyuna yakın tutulur; büyük tutulursa dar
	# adalarda otomatik süslere yer kalmaz.
	for p in palms:
		_occupy(p.x, p.y, 1.0)
	for t in trees:
		_occupy(t.x, t.y, 1.4)
	if waterfall_width > 0.0:
		_occupy(waterfall_bottom.x, waterfall_bottom.z, waterfall_width * 1.5)
		_occupy(waterfall_top.x, waterfall_top.z, waterfall_width * 1.5)

	if cliffs:
		_scatter_shore_rocks(rock_batch, rng)
	for p in palms:
		_add_palm(batch, p.x, p.y, p.z, rng)
	for t in trees:
		_add_tree(batch, t.x, t.y, t.z, rng)
	_scatter_vegetation(batch, rng)

	if waterfall_width > 0.0:
		_add_waterfall(batch, foam)

	PropLibrary.add_mesh(self, "_Gorsel", batch.commit(PropLibrary.toon_material()), true)
	PropLibrary.add_mesh(self, "_Kayalar", rock_batch.commit(PropLibrary.rock_material()), true)
	PropLibrary.add_mesh(self, "_SigSu", shallow.commit(PropLibrary.shallow_material()), false)
	PropLibrary.add_mesh(self, "_Kopuk", foam.commit(PropLibrary.foam_material()), false)


## Yerel (x, z) noktasındaki kara yüksekliği; denizde 0.
func surface_height(x: float, z: float) -> float:
	var h := 0.0
	for i in lobes.size():
		var lobe := lobes[i]
		var d := Vector2((x - lobe.x) / lobe.z, (z - lobe.y) / lobe.w).length()
		h = maxf(h, PropLibrary.mound_height(d) * SAND_HEIGHT)
		if i in plaza_lobes:
			h = maxf(h, PropLibrary.plateau_height(d / PLAZA_RATIO) * PLAZA_HEIGHT)
		elif cliffs:
			h = maxf(h, PropLibrary.cliff_height(d / EARTH_RATIO) * EARTH_HEIGHT)
			h = maxf(h, PropLibrary.plateau_height(d / PLATEAU_GRASS_RATIO) * PLATEAU_GRASS_HEIGHT)
		else:
			h = maxf(h, PropLibrary.mound_height(d / GRASS_RATIO) * GRASS_HEIGHT)
	for hl in highlands:
		var d := Vector2((x - hl.x) / hl.z, (z - hl.y) / hl.w).length()
		h = maxf(h, HIGHLAND_BASE + PropLibrary.cliff_height(d) * HIGHLAND_EARTH_HEIGHT)
		h = maxf(h, HIGHLAND_BASE + PropLibrary.plateau_height(d / HIGHLAND_GRASS_RATIO) * HIGHLAND_GRASS_HEIGHT)
	return h


## Noktanın en yakın lob merkezine göre normalize uzaklığı (0 = merkez, 1 = kum kenarı).
func _lobe_depth(x: float, z: float) -> float:
	var best := INF
	for lobe in lobes:
		best = minf(best, Vector2((x - lobe.x) / lobe.z, (z - lobe.y) / lobe.w).length())
	return best


func _occupy(x: float, z: float, radius: float) -> void:
	_occupied.append(Vector3(x, z, radius))


## Kamera güneyden baktığı için kuzey kıyıdaki uzun bitkiler hemen kuzeyden geçen
## gemiyi örter (plato/yükselti üstündeki 7,5 birimlik palmiye ekranda ~8 birim
## kuzeyi kapatır). Kuzeyinde 8 birim içinde su olan noktalara ağaç/palmiye
## konmaz; alçak çalılar serbesttir.
func _near_north_shore(x: float, z: float) -> bool:
	return _lobe_depth(x, z - 8.0) > 0.95


func _is_free(x: float, z: float, radius: float) -> bool:
	for o in _occupied:
		if Vector2(x - o.x, z - o.y).length() < radius + o.z:
			return false
	return true


func _perimeter(lobe: Vector4) -> float:
	return TAU * sqrt((lobe.z * lobe.z + lobe.w * lobe.w) * 0.5)


## Kıyı boyunca, toprak yamacının dibine yuvarlak kayalar dizer (yalnızca görsel).
## Başka bir lobun içine düşen noktalar atlanır; kayalar çarpışma yarıçapının
## içinde kalacak şekilde yerleştirilir, böylece geçitler daralmaz.
func _scatter_shore_rocks(rock_batch: MeshBatcher, rng: RandomNumberGenerator) -> void:
	for lobe in lobes:
		var count := roundi(_perimeter(lobe) * shore_rock_density)
		for i in count:
			var angle := TAU * (i + rng.randf_range(0.0, 0.7)) / maxf(count, 1)
			var ring := rng.randf_range(0.74, 0.82)
			var x := lobe.x + cos(angle) * lobe.z * ring
			var z := lobe.y + sin(angle) * lobe.w * ring
			if _lobe_depth(x, z) < ring - 0.05:
				continue
			var size := rng.randf_range(1.6, 2.8)
			if not _is_free(x, z, size * 0.5):
				continue
			_occupy(x, z, size * 0.5)
			PropLibrary.add_rock(rock_batch, Vector3(x, surface_height(x, z) - size * 0.3, z), size, rng.randf_range(1.2, 1.8), rng)
			# Referanstaki gibi kümelensin: yanına bazen küçük bir kaya daha.
			if rng.randf() < 0.6:
				var side := Vector2(-sin(angle), cos(angle)) * size * rng.randf_range(0.5, 0.7)
				var small := size * rng.randf_range(0.5, 0.7)
				PropLibrary.add_rock(rock_batch, Vector3(x + side.x, surface_height(x + side.x, z + side.y) - small * 0.3, z + side.y), small, rng.randf_range(0.9, 1.3), rng)


## Kumsala palmiye grupları, plato iç kesimine ağaç kümeleri, çimene çalılar.
func _scatter_vegetation(batch: MeshBatcher, rng: RandomNumberGenerator) -> void:
	for lobe in lobes:
		for i in roundi(_perimeter(lobe) * palm_density):
			var spot := _find_spot(lobe, rng, 0.88, 0.92, 1.2, 0.85, true)
			if spot.is_finite():
				_add_palm(batch, spot.x, spot.y, rng.randf_range(0.8, 1.0), rng)
	for lobe in lobes:
		for i in roundi(lobe.z * lobe.w * tree_density):
			var spot := _find_spot(lobe, rng, 0.0, 0.72 * PLATEAU_GRASS_RATIO, 1.5, 0.0, true)
			if not spot.is_finite():
				continue
			_tree_count += 1
			_add_tree(batch, spot.x, spot.y, rng.randf_range(1.05, 1.35), rng)
			# Referanstaki gibi kümeler: yanına bir-iki ağaç daha.
			for k in rng.randi_range(0, 2):
				var a := rng.randf_range(0.0, TAU)
				var cx := spot.x + cos(a) * 3.2
				var cz := spot.y + sin(a) * 3.2
				if _lobe_depth(cx, cz) < 0.7 and _is_free(cx, cz, 1.4) and not _near_north_shore(cx, cz):
					_occupy(cx, cz, 1.4)
					_add_tree(batch, cx, cz, rng.randf_range(0.85, 1.1), rng)
					_tree_count += 1
	for li in lobes.size():
		if li in plaza_lobes:
			continue
		var lobe := lobes[li]
		for i in roundi(lobe.z * lobe.w * bush_density):
			var spot := _find_spot(lobe, rng, 0.0, 0.72 * GRASS_RATIO, 0.7)
			if spot.is_finite():
				PropLibrary.add_bush(batch, Vector3(spot.x, surface_height(spot.x, spot.y) - 0.3, spot.y), rng.randf_range(1.6, 2.3), rng)


## Lob içinde (normalize uzaklık min_d..max_d) boş bir nokta arar ve işaretler;
## birkaç denemede bulunamazsa sonsuz vektör döner. min_depth > 0 ise nokta
## başka bir lobun iç kısmına düşmemeli (kumsal şeridi için).
func _find_spot(lobe: Vector4, rng: RandomNumberGenerator, min_d: float, max_d: float, radius: float, min_depth: float = 0.0, tall: bool = false) -> Vector2:
	for attempt in 6:
		var angle := rng.randf_range(0.0, TAU)
		var dist := sqrt(rng.randf_range(min_d * min_d, max_d * max_d))
		var x := lobe.x + cos(angle) * dist * lobe.z
		var z := lobe.y + sin(angle) * dist * lobe.w
		if (min_depth > 0.0 and _lobe_depth(x, z) < min_depth) or not _is_free(x, z, radius):
			continue
		if tall and _near_north_shore(x, z):
			continue
		_occupy(x, z, radius)
		return Vector2(x, z)
	return Vector2.INF


func _add_palm(batch: MeshBatcher, x: float, z: float, s: float, rng: RandomNumberGenerator) -> void:
	var ground := surface_height(x, z)
	PropLibrary.add_palm(batch, Vector3(x, ground, z), s, rng)
	tall_plants.append(Vector3(x, z, ground + 7.5 * s))


func _add_tree(batch: MeshBatcher, x: float, z: float, s: float, rng: RandomNumberGenerator) -> void:
	var ground := surface_height(x, z)
	PropLibrary.add_tree(batch, Vector3(x, ground, z), s, rng)
	tall_plants.append(Vector3(x, z, ground + 6.0 * s))


func _add_waterfall(batch: MeshBatcher, foam: MeshBatcher) -> void:
	var fall := waterfall_top - waterfall_bottom
	var x_axis := Vector3(waterfall_width, 0.0, 0.0)
	var z_axis := x_axis.cross(fall).normalized()
	var quad := QuadMesh.new()
	var instance := PropLibrary.add_mesh(self, "_Selale", quad, false)
	instance.transform = Transform3D(Basis(x_axis, fall, z_axis), (waterfall_top + waterfall_bottom) * 0.5)
	instance.material_override = PropLibrary.waterfall_material()
	var base := Vector3(waterfall_bottom.x, 0.04, waterfall_bottom.z)
	foam.add(PropLibrary.ring(waterfall_width * 0.7, waterfall_width * 0.5, 1.0), Transform3D(Basis.IDENTITY, base))
	for offset in [Vector3(-0.5, 0.1, 0.1), Vector3(0.45, 0.05, 0.2), Vector3(0.0, 0.2, 0.35)]:
		batch.add(PropLibrary.sphere(), Transform3D(Basis.from_scale(Vector3.ONE * 0.45), base + offset * waterfall_width), PropLibrary.SPLASH)
