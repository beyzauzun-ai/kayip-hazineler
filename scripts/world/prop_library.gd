@tool
class_name PropLibrary
extends RefCounted
## Masalsı dünyanın ortak parçaları: renk paleti, paylaşılan mesh ve malzemeler,
## palmiye, ağaç, kaya, mercan gibi süslerin MeshBatcher'a eklenmesi ve
## üretilen düğümlerin yönetimi.

const LAYER_WORLD := 1
const LAYER_ROCKS := 2

const SAND := Color("#F2D49B")
const SHALLOW := Color(0.62, 0.98, 0.9, 0.42)
## Çimen: referanstaki daha koyu, daha az doygun yeşile yakın iki ton (lob
## başına değişir, üst üste binen tepeler lekeli bir görünüm verir).
const GRASS := Color("#7FA83F")
const GRASS_ALT := Color("#6F9A3A")
## Ada yamacı (kum ile çimen platosu arasındaki dik toprak bandı).
const EARTH := Color("#C59A62")
const ROCK := Color("#968AA3")
const WOOD := Color("#9A5A2E")
const WOOD_LIGHT := Color("#C08048")
const WOOD_DARK := Color("#6E3F1E")
const ROOF := Color("#D9603B")
const CANVAS := Color("#F3E6C8")
const TRUNK := Color("#A0703F")
const TRUNK_DARK := Color("#86592F")
const LEAF := Color("#7CC243")
const LEAF_DARK := Color("#5FAE3A")
const SPLASH := Color("#F4FBFF")
## Alfa 0 olan renkler toon shader'da ışık saçar.
const LANTERN := Color(1.0, 0.71, 0.29, 0.0)
const WINDOW := Color(1.0, 0.82, 0.45, 0.0)
const TREE_COLORS: Array[Color] = [Color("#5E9E3A"), Color("#74B242"), Color("#4E8A34")]
const CORAL_COLORS: Array[Color] = [Color("#F28DB2"), Color("#F6A6C1"), Color("#E87AA4")]

## Tepecik kesiti (yarıçap, yükseklik), birim boyutta; dıştan tepeye doğru.
const MOUND_PROFILE: Array[Vector2] = [
	Vector2(1.0, -1.0), Vector2(1.0, 0.35), Vector2(0.97, 0.62), Vector2(0.9, 0.82),
	Vector2(0.78, 0.94), Vector2(0.6, 0.99), Vector2(0.3, 1.0), Vector2(0.0, 1.0),
]
## Dik yamaç kesiti: neredeyse dikey kenar, düz tepe (ada platosu).
const CLIFF_PROFILE: Array[Vector2] = [
	Vector2(1.0, -1.0), Vector2(1.0, 0.72), Vector2(0.97, 0.93), Vector2(0.9, 1.0), Vector2(0.0, 1.0),
]
## Çimen platosu kesiti: geniş düz tepe, yumuşak kenar. Komşu loblar aynı
## yükseklikte birleştiği için aralarında eğim kırığı (yay çizgisi) oluşmaz.
const PLATEAU_PROFILE: Array[Vector2] = [
	Vector2(1.0, -1.0), Vector2(1.0, 0.45), Vector2(0.96, 0.8), Vector2(0.88, 0.95), Vector2(0.76, 1.0), Vector2(0.0, 1.0),
]
const ROCK_VARIANTS := 5

static var _cache: Dictionary = {}


# --- Paylaşılan mesh'ler -----------------------------------------------------

## Yuvarlak tepecik (kum, çimen).
static func mound() -> ArrayMesh:
	return _lathe(&"mound", MOUND_PROFILE)


## Düz tepeli çimen platosu.
static func plateau() -> ArrayMesh:
	return _lathe(&"plateau", PLATEAU_PROFILE)


## Dik kenarlı yamaç (toprak bandı).
static func cliff() -> ArrayMesh:
	return _lathe(&"cliff", CLIFF_PROFILE)


static func _lathe(key: StringName, profile: Array[Vector2]) -> ArrayMesh:
	if _cache.has(key):
		return _cache[key]
	var segs := 20
	var count := profile.size()
	var verts := PackedVector3Array()
	var norms := PackedVector3Array()
	var indices := PackedInt32Array()
	for k in count:
		var p := profile[k]
		var tangent := profile[mini(k + 1, count - 1)] - profile[maxi(k - 1, 0)]
		var n2 := Vector2(tangent.y, -tangent.x).normalized()
		for j in segs:
			var a := TAU * j / segs
			verts.append(Vector3(p.x * cos(a), p.y, p.x * sin(a)))
			norms.append(Vector3(n2.x * cos(a), n2.y, n2.x * sin(a)).normalized())
	for k in count - 1:
		for j in segs:
			var j2 := (j + 1) % segs
			var a := k * segs + j
			var b := k * segs + j2
			var c := (k + 1) * segs + j2
			var d := (k + 1) * segs + j
			indices.append_array([c, d, a, c, a, b])
	var mesh := _array_mesh(verts, norms, PackedVector2Array(), indices)
	_cache[key] = mesh
	return mesh


## Tepeciğin merkezden normalize uzaklıktaki yüksekliği (birim); dışındaysa -10.
static func mound_height(d: float) -> float:
	return _profile_height(MOUND_PROFILE, d)


static func plateau_height(d: float) -> float:
	return _profile_height(PLATEAU_PROFILE, d)


static func cliff_height(d: float) -> float:
	return _profile_height(CLIFF_PROFILE, d)


static func _profile_height(profile: Array[Vector2], d: float) -> float:
	for k in profile.size() - 1:
		var p := profile[k]
		var q := profile[k + 1]
		if p.x != q.x and d <= p.x and d >= q.x:
			return lerpf(q.y, p.y, (d - q.x) / (p.x - q.x))
	return -10.0


## Birim çaplı küre (yarıçap 0,5): ölçek değeri çapa eşittir.
static func sphere() -> Mesh:
	if not _cache.has(&"sphere"):
		var m := SphereMesh.new()
		m.radial_segments = 12
		m.rings = 6
		_cache[&"sphere"] = m
	return _cache[&"sphere"]


## Düşük bölümlü birim çaplı küre (çalı, ağaç taçları, palmiye yaprakları; ~64 üçgen).
static func sphere_low() -> Mesh:
	if not _cache.has(&"sphere_low"):
		var m := SphereMesh.new()
		m.radial_segments = 8
		m.rings = 4
		_cache[&"sphere_low"] = m
	return _cache[&"sphere_low"]


static func cylinder() -> Mesh:
	if not _cache.has(&"cylinder"):
		var m := CylinderMesh.new()
		m.top_radius = 1.0
		m.bottom_radius = 1.0
		m.height = 1.0
		m.radial_segments = 10
		m.rings = 0
		_cache[&"cylinder"] = m
	return _cache[&"cylinder"]


static func box() -> Mesh:
	if not _cache.has(&"box"):
		var m := BoxMesh.new()
		m.size = Vector3.ONE
		_cache[&"box"] = m
	return _cache[&"box"]


static func prism() -> Mesh:
	if not _cache.has(&"prism"):
		var m := PrismMesh.new()
		m.size = Vector3.ONE
		_cache[&"prism"] = m
	return _cache[&"prism"]


## "Yontulmuş" kaya (10. aşama): az parçalı küre güçlü gürültüyle bozulur, tepesi
## düz kesilir ve hafifçe yana yatar. Her yüz kendi normalini alır (düz gölge);
## böylece aydınlık ve gölgeli yüzler ayrı tonlarda görünür, kaya top gibi durmaz.
## Boyut eski kayayla aynıdır (birim çap), çarpışma şekilleri buna bağlı değildir.
static func rock(variant: int) -> Mesh:
	var key := StringName("rock_%d" % variant)
	if _cache.has(key):
		return _cache[key]
	var src := SphereMesh.new()
	src.radial_segments = 7
	src.rings = 5
	var arrays := src.get_mesh_arrays()
	var noise := FastNoiseLite.new()
	noise.seed = 2000 + variant * 41
	noise.frequency = 1.4
	var rng := RandomNumberGenerator.new()
	rng.seed = 500 + variant
	var top := rng.randf_range(0.38, 0.5)
	var lean := Vector2(rng.randf_range(-0.12, 0.12), rng.randf_range(-0.12, 0.12))
	var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	for i in verts.size():
		var v := verts[i] * (1.0 + noise.get_noise_3dv(verts[i]) * 0.38)
		v.y = clampf(v.y, -0.35, top)
		v.x += lean.x * (v.y + 0.35)
		v.z += lean.y * (v.y + 0.35)
		verts[i] = v
	# Düz gölge: üçgenler ortak köşe paylaşmaz, her yüz kendi normalini taşır.
	var flat := PackedVector3Array()
	var norms := PackedVector3Array()
	var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
	for i in range(0, indices.size(), 3):
		var a := verts[indices[i]]
		var b := verts[indices[i + 1]]
		var c := verts[indices[i + 2]]
		var n := (c - a).cross(b - a).normalized()
		flat.append_array([a, b, c])
		norms.append_array([n, n, n])
	var mesh := _array_mesh(flat, norms, PackedVector2Array(), PackedInt32Array())
	_cache[key] = mesh
	return mesh


## Yatay elips halka (köpük). UV.y: 0 iç kenar, 1 dış kenar.
static func ring(rx: float, rz: float, width: float, segs: int = 40) -> Mesh:
	var verts := PackedVector3Array()
	var norms := PackedVector3Array()
	var uvs := PackedVector2Array()
	var indices := PackedInt32Array()
	for j in segs + 1:
		var a := TAU * j / segs
		var dir := Vector2(cos(a), sin(a))
		verts.append(Vector3(dir.x * rx * 0.97, 0.0, dir.y * rz * 0.97))
		verts.append(Vector3(dir.x * (rx + width), 0.0, dir.y * (rz + width)))
		norms.append(Vector3.UP)
		norms.append(Vector3.UP)
		uvs.append(Vector2(float(j) / segs, 0.0))
		uvs.append(Vector2(float(j) / segs, 1.0))
	for j in segs:
		var i := j * 2
		indices.append_array([i, i + 1, i + 3, i, i + 3, i + 2])
	return _array_mesh(verts, norms, uvs, indices)


static func _array_mesh(verts: PackedVector3Array, norms: PackedVector3Array, uvs: PackedVector2Array, indices: PackedInt32Array) -> ArrayMesh:
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = norms
	if not uvs.is_empty():
		arrays[Mesh.ARRAY_TEX_UV] = uvs
	if not indices.is_empty():
		arrays[Mesh.ARRAY_INDEX] = indices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh


# --- Malzemeler ----------------------------------------------------------------

static func noise_texture() -> Texture2D:
	return load("res://shaders/wave_noise.tres")


static func toon_material() -> Material:
	return _shader_material(&"toon", "res://shaders/toon.gdshader")


static func foam_material() -> Material:
	return _shader_material(&"foam", "res://shaders/foam.gdshader")


static func waterfall_material() -> Material:
	return _shader_material(&"waterfall", "res://shaders/waterfall.gdshader")


## Kıyıların çevresindeki yumuşak, açık turkuaz sığ su halesi (köpük shader'ı, gürültüsüz).
static func shallow_material() -> Material:
	if not _cache.has(&"shallow"):
		var m := ShaderMaterial.new()
		m.shader = load("res://shaders/foam.gdshader")
		m.set_shader_parameter("noise_tex", noise_texture())
		m.set_shader_parameter("foam_color", SHALLOW)
		m.set_shader_parameter("fade_start", 0.0)
		m.set_shader_parameter("pulse_amount", 0.0)
		m.set_shader_parameter("edge_noise", 0.0)
		_cache[&"shallow"] = m
	return _cache[&"shallow"]


## Kayalar için daha koyu gölge rengi ve daha keskin geçişli toon malzeme
## (aydınlık / gölgeli yüz farkı referanstaki gibi belirgin olsun diye).
static func rock_material() -> Material:
	if not _cache.has(&"rock"):
		var m := (toon_material() as ShaderMaterial).duplicate() as ShaderMaterial
		m.set_shader_parameter("shadow_color", Color(0.26, 0.22, 0.42))
		m.set_shader_parameter("band_softness", 0.3)
		m.set_shader_parameter("rim_strength", 0.06)
		_cache[&"rock"] = m
	return _cache[&"rock"]


static func glow_material() -> Material:
	return _shader_material(&"glow", "res://shaders/glow_halo.gdshader")


## Sahte ışıltı haleleri tek mesh olarak: her öğe (x, y, z, çap). Bkz. glow_halo.gdshader.
static func glow_mesh(halos: Array[Vector4], color: Color) -> ArrayMesh:
	var verts := PackedVector3Array()
	var uvs := PackedVector2Array()
	var uv2s := PackedVector2Array()
	var colors := PackedColorArray()
	var indices := PackedInt32Array()
	var bounds := AABB()
	for i in halos.size():
		var h := halos[i]
		var center := Vector3(h.x, h.y, h.z)
		var base := verts.size()
		for corner in [Vector2(0, 0), Vector2(1, 0), Vector2(1, 1), Vector2(0, 1)]:
			verts.append(center)
			uvs.append(corner)
			uv2s.append(Vector2(h.w, 0.0))
			colors.append(Color(color.r, color.g, color.b, fmod(i * 0.37, 1.0)))
		indices.append_array([base, base + 1, base + 2, base, base + 2, base + 3])
		var box := AABB(center - Vector3.ONE * h.w, Vector3.ONE * h.w * 2.0)
		bounds = box if i == 0 else bounds.merge(box)
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_TEX_UV2] = uv2s
	arrays[Mesh.ARRAY_COLOR] = colors
	arrays[Mesh.ARRAY_INDEX] = indices
	var mesh := ArrayMesh.new()
	if not halos.is_empty():
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
		mesh.surface_set_material(0, glow_material())
		# Köşeler shader'da açıldığı için görünürlük sınırı elle genişletilir.
		mesh.custom_aabb = bounds
	return mesh


static func _shader_material(key: StringName, path: String) -> Material:
	if not _cache.has(key):
		var m := ShaderMaterial.new()
		m.shader = load(path)
		m.set_shader_parameter("noise_tex", noise_texture())
		_cache[key] = m
	return _cache[key]


# --- Süsler --------------------------------------------------------------------

static func add_rock(b: MeshBatcher, pos: Vector3, size: float, stretch: float, rng: RandomNumberGenerator) -> void:
	var basis := Basis(Vector3.UP, rng.randf_range(0.0, TAU)) * Basis.from_scale(Vector3(size, size * stretch, size * rng.randf_range(0.8, 1.0)))
	# Tepe açık, taban koyu: sabit (maliyetsiz) ortam gölgesi.
	b.add(rock(rng.randi_range(0, ROCK_VARIANTS - 1)), Transform3D(basis, pos), ROCK.lightened(rng.randf_range(0.0, 0.1)), 0.6)


## Hafif eğik gövdeli, sarkık yapraklı palmiye. Ölçek 1 ≈ 7,5 birim boy.
static func add_palm(b: MeshBatcher, base: Vector3, s: float, rng: RandomNumberGenerator) -> void:
	s *= 2.1
	var lean := Vector3(rng.randf_range(-1.0, 1.0), 0.0, rng.randf_range(-1.0, 1.0)).normalized() * 0.16
	var pos := base
	var dir := Vector3.UP
	var seg_len := 0.72 * s
	for i in 5:
		dir = (dir + lean).normalized()
		var radius := 0.2 * s * (1.0 - i * 0.1)
		var basis := Basis(Quaternion(Vector3.UP, dir)) * Basis.from_scale(Vector3(radius, seg_len * 1.05, radius))
		b.add(cylinder(), Transform3D(basis, pos + dir * seg_len * 0.5), TRUNK if i % 2 == 0 else TRUNK_DARK)
		pos += dir * seg_len
	var fronds := 7
	for k in fronds:
		var yaw := TAU * k / fronds + rng.randf_range(-0.2, 0.2)
		var droop := deg_to_rad(rng.randf_range(15.0, 35.0))
		var out := Vector3(cos(yaw) * cos(droop), -sin(droop), sin(yaw) * cos(droop))
		var basis := Basis.looking_at(out, Vector3.UP) * Basis.from_scale(Vector3(0.42, 0.07, 1.25) * s)
		b.add(sphere_low(), Transform3D(basis, pos + out * 1.05 * s), LEAF if k % 2 == 0 else LEAF_DARK)
	b.add(sphere(), Transform3D(Basis.from_scale(Vector3.ONE * 0.22 * s), pos + Vector3(0.15, -0.15, 0.1) * s), WOOD_DARK)


## Yuvarlak taçlı ağaç. Ölçek 1 ≈ 6 birim boy.
static func add_tree(b: MeshBatcher, base: Vector3, s: float, rng: RandomNumberGenerator) -> void:
	s *= 2.0
	b.add(cylinder(), Transform3D(Basis.from_scale(Vector3(0.22, 1.2, 0.22) * s), base + Vector3(0.0, 0.6 * s, 0.0)), TRUNK_DARK)
	var blobs: Array[Vector4] = [
		Vector4(0.0, 1.75, 0.0, 0.95), Vector4(0.55, 1.45, 0.3, 0.7),
		Vector4(-0.5, 1.5, -0.25, 0.75), Vector4(0.1, 2.3, -0.1, 0.6),
	]
	var offset := rng.randi()
	for i in blobs.size():
		var blob := blobs[i]
		var color := TREE_COLORS[(i + offset) % TREE_COLORS.size()]
		b.add(sphere_low(), Transform3D(Basis.from_scale(Vector3.ONE * blob.w * s), base + Vector3(blob.x, blob.y, blob.z) * s), color, 0.35)


## Bir-üç küreden oluşan yuvarlak çalı öbeği.
static func add_bush(b: MeshBatcher, base: Vector3, s: float, rng: RandomNumberGenerator) -> void:
	for i in rng.randi_range(1, 3):
		var r := rng.randf_range(0.6, 1.0) * s
		var offset := Vector3(rng.randf_range(-0.7, 0.7), r * 0.6, rng.randf_range(-0.7, 0.7)) * s
		b.add(sphere_low(), Transform3D(Basis.from_scale(Vector3(r, r * 0.85, r)), base + offset), TREE_COLORS[rng.randi() % TREE_COLORS.size()], 0.35)


## Su yüzeyine kadar uzanan dallı pembe mercan.
static func add_coral(b: MeshBatcher, base: Vector3, s: float, rng: RandomNumberGenerator) -> void:
	var color := CORAL_COLORS[rng.randi() % CORAL_COLORS.size()]
	for i in rng.randi_range(3, 5):
		var tilt := Vector3(rng.randf_range(-0.6, 0.6), 1.0, rng.randf_range(-0.6, 0.6)).normalized()
		var length := rng.randf_range(0.9, 1.6) * s
		var basis := Basis(Quaternion(Vector3.UP, tilt)) * Basis.from_scale(Vector3(0.2 * s, length, 0.2 * s))
		b.add(cylinder(), Transform3D(basis, base + tilt * length * 0.5), color)
		b.add(sphere(), Transform3D(Basis.from_scale(Vector3.ONE * 0.26 * s), base + tilt * length), color.lightened(0.15))


# --- Üretilen düğümler -------------------------------------------------------------

## Üretilen düğümler sahneye kaydedilmez; her açılışta yeniden oluşturulur.
static func clear_generated(node: Node) -> void:
	for child in node.get_children():
		if child.has_meta(&"generated"):
			node.remove_child(child)
			child.free()


static func add_mesh(parent: Node3D, node_name: String, mesh: Mesh, cast_shadows: bool) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	instance.name = node_name
	instance.mesh = mesh
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if cast_shadows else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	instance.set_meta(&"generated", true)
	parent.add_child(instance)
	return instance


static func add_static_body(parent: Node3D, layer: int) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.name = "_Carpisma"
	body.collision_layer = layer
	body.collision_mask = 0
	body.set_meta(&"generated", true)
	parent.add_child(body)
	return body


static func add_cylinder_shape(body: StaticBody3D, center: Vector3, radius: float) -> void:
	var shape := CylinderShape3D.new()
	shape.radius = radius
	shape.height = 4.0
	var collider := CollisionShape3D.new()
	collider.shape = shape
	collider.position = center + Vector3(0.0, 0.5, 0.0)
	body.add_child(collider)


static func add_box_shape(body: StaticBody3D, center: Vector3, size: Vector3) -> void:
	var shape := BoxShape3D.new()
	shape.size = size
	var collider := CollisionShape3D.new()
	collider.shape = shape
	collider.position = center
	body.add_child(collider)
