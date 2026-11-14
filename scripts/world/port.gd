@tool
extends Node3D
## Başlangıç/bitiş limanı: tahta şeritli, kepenkli, iki tonlu dik beşik çatılı,
## bacalı kulübeler, L biçimli iskele, uzun direkli fenerler, çizgili tente,
## fıçı/sandık/ağ yığınları ve bağlı bir sandal. Fener ve pencerelerde ucuz sahte ışıltı (tek çizim çağrısı).
## Düğüm dünya orijininde durur; konumlar dünya koordinatındadır. Zemin
## yüksekliği bağlı adadan okunur. Çarpışma kutuları yalnızca iskelededir.

const DECK_Y := 0.9
const PIER_START := Vector3(-44.0, 0.0, 20.0)
const PIER_END_X := -27.0
const PIER_WIDTH := 3.0
const ARM_X := -34.0
const ARM_END_Z := 31.0
const ARM_WIDTH := 2.6
const STONE := Color("#8E8496")
const SHUTTER := Color("#4F86A8")
const STRIPE := Color("#D9483B")
const NET := Color("#7C8F6A")
const GLOW := Color(1.0, 0.72, 0.35)
## Çatı yüksekliğinin duvar yüksekliğine oranı (gemi görünürlüğü için %90).
const ROOF_RATIO := 0.9

@export var land: Island
@export var decoration_seed := 7
@export_tool_button("Yeniden Oluştur", "Reload") var rebuild_action: Callable = rebuild

var _halos: Array[Vector4] = []


func _ready() -> void:
	rebuild()


func rebuild() -> void:
	PropLibrary.clear_generated(self)
	_halos.clear()
	var rng := RandomNumberGenerator.new()
	rng.seed = decoration_seed
	var b := MeshBatcher.new()

	_add_house(b, Vector3(-49.0, 0.0, 12.0), 0.15, Vector3(6.0, 3.6, 4.8))
	_add_house(b, Vector3(-55.0, 0.0, 22.0), -0.1, Vector3(6.6, 3.9, 5.2))
	_add_tent(b, Vector3(-48.0, 0.0, 29.0))
	_add_pier(b)
	_add_rowboat(b, Vector3(-36.3, 0.0, 27.0), 0.15)
	for p in [Vector3(-43.6, 0.0, 22.7), Vector3(-42.7, 0.0, 23.5), Vector3(-44.4, 0.0, 17.4), Vector3(-51.5, 0.0, 16.6)]:
		_add_barrel(b, p)
	for p in [Vector3(-28.4, DECK_Y, 21.0), Vector3(-29.3, DECK_Y, 21.2)]:
		_add_barrel(b, p, true)
	for p in [Vector3(-45.2, 0.0, 23.2), Vector3(-46.0, 0.0, 30.6), Vector3(-52.6, 0.0, 16.0)]:
		_add_crate(b, p, rng.randf_range(-0.4, 0.4))
	_add_crate(b, Vector3(-33.3, DECK_Y, 29.4), 0.3, true)
	_add_net(b, Vector3(-42.2, 0.0, 17.2))
	var arm_start := PIER_START.z + PIER_WIDTH * 0.5
	for p in [
		Vector3(PIER_END_X - 0.6, DECK_Y, PIER_START.z - 1.3), Vector3(PIER_END_X - 0.6, DECK_Y, PIER_START.z + 1.3),
		Vector3(ARM_X + 1.1, DECK_Y, ARM_END_Z - 0.6), Vector3(PIER_START.x + 2.0, DECK_Y, PIER_START.z - 1.3),
		Vector3(ARM_X - 1.1, DECK_Y, arm_start + 4.0),
	]:
		_add_lantern(b, p)
	PropLibrary.add_mesh(self, "_Gorsel", b.commit(PropLibrary.toon_material()), true)
	PropLibrary.add_mesh(self, "_Isilti", PropLibrary.glow_mesh(_halos, GLOW), false)

	var body := PropLibrary.add_static_body(self, PropLibrary.LAYER_WORLD)
	var pier_length := PIER_END_X - PIER_START.x
	PropLibrary.add_box_shape(body, Vector3(PIER_START.x + pier_length * 0.5, 0.5, PIER_START.z), Vector3(pier_length + 0.4, 3.0, PIER_WIDTH))
	PropLibrary.add_box_shape(body, Vector3(ARM_X, 0.5, (arm_start + ARM_END_Z) * 0.5), Vector3(ARM_WIDTH, 3.0, ARM_END_Z - arm_start))


func _ground(x: float, z: float) -> float:
	if land == null:
		return 0.0
	return land.surface_height(x - land.position.x, z - land.position.z)


func _part(b: MeshBatcher, mesh: Mesh, origin: Vector3, basis: Basis, offset: Vector3, size: Vector3, color: Color) -> void:
	b.add(mesh, Transform3D(basis * Basis.from_scale(size), origin + basis * offset), color)


func _add_house(b: MeshBatcher, pos: Vector3, yaw: float, size: Vector3) -> void:
	var origin := Vector3(pos.x, _ground(pos.x, pos.z), pos.z)
	var basis := Basis(Vector3.UP, yaw)
	var box := PropLibrary.box()
	var w := size.x
	var h := size.y
	var d := size.z
	var floor_y := 0.4
	var front := d * 0.5
	# Taş temel, duvar ve köşe dikmeleri.
	_part(b, box, origin, basis, Vector3(0.0, 0.15, 0.0), Vector3(w + 0.3, 0.5, d + 0.3), STONE)
	_part(b, box, origin, basis, Vector3(0.0, floor_y + h * 0.5, 0.0), Vector3(w, h, d), PropLibrary.WOOD_LIGHT)
	for sx in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			_part(b, box, origin, basis, Vector3(sx * w * 0.5, floor_y + h * 0.5, sz * d * 0.5), Vector3(0.24, h + 0.05, 0.24), PropLibrary.WOOD_DARK)
	# Yatay tahta şeritleri (ön ve yan cephe).
	for k in 3:
		var y := floor_y + h * (k + 1) / 4.0
		_part(b, box, origin, basis, Vector3(0.0, y, front + 0.02), Vector3(w, 0.07, 0.05), PropLibrary.WOOD)
		_part(b, box, origin, basis, Vector3(w * 0.5 + 0.02, y, 0.0), Vector3(0.05, 0.07, d), PropLibrary.WOOD)
	# Dik beşik çatı (10. aşama). Mahya evin derinliği boyunca uzanır; iki eğimli
	# yüz doğuya ve batıya bakar, böylece güneşli yüz açık, gölgeli yüz koyu
	# görünür ve kamera ikisini birden görür. Ön ve arka alınlık duvar renginde.
	var roof_h := h * ROOF_RATIO
	var top := floor_y + h
	var half := w * 0.62
	var angle := atan2(roof_h, half)
	var slope := sqrt(half * half + roof_h * roof_h)
	var depth := d * 1.24
	_part(b, PropLibrary.prism(), origin, basis, Vector3(0.0, top + roof_h * 0.5, 0.0), Vector3(w, roof_h, d), PropLibrary.WOOD_LIGHT)
	for side in [-1.0, 1.0]:
		var tilt := basis * Basis(Vector3.BACK, -side * angle)
		var center := origin + basis * Vector3(side * half * 0.5, top + roof_h * 0.5, 0.0)
		b.add(box, Transform3D(tilt * Basis.from_scale(Vector3(slope + 0.2, 0.2, depth)), center + tilt * Vector3(0.0, 0.1, 0.0)), PropLibrary.ROOF)
		# Sade kiremit sıraları: mahyaya paralel, hafif kabarık şeritler.
		for k in 3:
			var along := ((k + 1) / 4.0 - 0.5) * slope
			b.add(box, Transform3D(tilt * Basis.from_scale(Vector3(0.14, 0.08, depth)), center + tilt * Vector3(along, 0.22, 0.0)), PropLibrary.ROOF.darkened(0.14))
		# Saçak kirişi.
		_part(b, box, origin, basis, Vector3(side * (half + 0.05), top - 0.02, 0.0), Vector3(0.16, 0.16, depth), PropLibrary.ROOF.darkened(0.3))
	# Mahya kirişi.
	_part(b, box, origin, basis, Vector3(0.0, top + roof_h + 0.16, 0.0), Vector3(0.32, 0.26, depth + 0.1), PropLibrary.ROOF.darkened(0.32))
	# Baca: doğu yüzünden çıkar.
	var cx := w * 0.3
	var surface := top + roof_h * (1.0 - cx / half)
	_part(b, box, origin, basis, Vector3(cx, surface + 0.35, -d * 0.15), Vector3(0.7, 1.3, 0.7), STONE)
	_part(b, box, origin, basis, Vector3(cx, surface + 1.05, -d * 0.15), Vector3(0.85, 0.15, 0.85), STONE.darkened(0.2))
	# Kapı, kapı çerçevesi, saçaklı giriş ve basamak.
	_part(b, box, origin, basis, Vector3(0.0, floor_y + 0.7, front + 0.03), Vector3(1.05, 1.5, 0.06), PropLibrary.WOOD_DARK.darkened(0.2))
	_part(b, box, origin, basis, Vector3(0.0, floor_y + 0.65, front + 0.06), Vector3(0.8, 1.3, 0.06), PropLibrary.WOOD_DARK)
	_part(b, PropLibrary.prism(), origin, basis, Vector3(0.0, floor_y + 1.75, front + 0.55), Vector3(1.9, 0.45, 1.2), PropLibrary.ROOF.darkened(0.08))
	for sx in [-0.8, 0.8]:
		_part(b, PropLibrary.cylinder(), origin, basis, Vector3(sx, floor_y + 0.8, front + 1.05), Vector3(0.07, 1.6, 0.07), PropLibrary.WOOD_DARK)
	_part(b, box, origin, basis, Vector3(0.0, 0.2, front + 0.6), Vector3(1.4, 0.25, 0.8), PropLibrary.WOOD)
	# Pencereler: çerçeve, ışıklı cam, kepenkler ve ışıltı.
	for sx in [-1.0, 1.0]:
		var win := Vector3(sx * w * 0.3, floor_y + h * 0.6, front)
		_part(b, box, origin, basis, win + Vector3(0.0, 0.0, 0.03), Vector3(0.75, 0.75, 0.05), PropLibrary.WOOD_DARK)
		_part(b, box, origin, basis, win + Vector3(0.0, 0.0, 0.06), Vector3(0.55, 0.55, 0.05), PropLibrary.WINDOW)
		for side in [-1.0, 1.0]:
			_part(b, box, origin, basis, win + Vector3(side * 0.55, 0.0, 0.05), Vector3(0.26, 0.7, 0.05), SHUTTER)
		_halo(origin + basis * (win + Vector3(0.0, 0.0, 0.3)), 2.4)
	var side_win := Vector3(w * 0.5, floor_y + h * 0.6, 0.0)
	_part(b, box, origin, basis, side_win + Vector3(0.04, 0.0, 0.0), Vector3(0.06, 0.55, 0.55), PropLibrary.WINDOW)
	_halo(origin + basis * (side_win + Vector3(0.3, 0.0, 0.0)), 2.1)
	# Kapı feneri.
	var lamp := Vector3(0.75, floor_y + 1.55, front + 0.12)
	_part(b, box, origin, basis, lamp, Vector3(0.22, 0.28, 0.22), PropLibrary.LANTERN)
	_halo(origin + basis * (lamp + Vector3(0.0, 0.0, 0.2)), 2.4)


func _add_pier(b: MeshBatcher) -> void:
	var post := PropLibrary.cylinder()
	var x := PIER_START.x + 0.5
	var i := 0
	while x < PIER_END_X:
		var color := PropLibrary.WOOD if i % 2 == 0 else PropLibrary.WOOD_LIGHT
		b.add(PropLibrary.box(), Transform3D(Basis.from_scale(Vector3(0.92, 0.18, PIER_WIDTH)), Vector3(x, DECK_Y, PIER_START.z)), color)
		if i % 3 == 0 or x + 1.0 >= PIER_END_X:
			for side in [-1.0, 1.0]:
				b.add(post, Transform3D(Basis.from_scale(Vector3(0.2, 2.6, 0.2)), Vector3(x, DECK_Y - 1.0, PIER_START.z + side * PIER_WIDTH * 0.5)), PropLibrary.WOOD_DARK)
				# Babalar ve halat sargısı.
				b.add(post, Transform3D(Basis.from_scale(Vector3(0.26, 0.5, 0.26)), Vector3(x, DECK_Y + 0.3, PIER_START.z + side * PIER_WIDTH * 0.5)), PropLibrary.WOOD_DARK)
				b.add(post, Transform3D(Basis.from_scale(Vector3(0.3, 0.12, 0.3)), Vector3(x, DECK_Y + 0.38, PIER_START.z + side * PIER_WIDTH * 0.5)), PropLibrary.CANVAS.darkened(0.25))
		x += 1.0
		i += 1
	var z := PIER_START.z + PIER_WIDTH * 0.5 + 0.5
	i = 0
	while z < ARM_END_Z:
		var color := PropLibrary.WOOD_LIGHT if i % 2 == 0 else PropLibrary.WOOD
		b.add(PropLibrary.box(), Transform3D(Basis.from_scale(Vector3(ARM_WIDTH, 0.18, 0.92)), Vector3(ARM_X, DECK_Y, z)), color)
		if i % 3 == 2 or z + 1.0 >= ARM_END_Z:
			for side in [-1.0, 1.0]:
				b.add(post, Transform3D(Basis.from_scale(Vector3(0.2, 2.6, 0.2)), Vector3(ARM_X + side * ARM_WIDTH * 0.5, DECK_Y - 1.0, z)), PropLibrary.WOOD_DARK)
				b.add(post, Transform3D(Basis.from_scale(Vector3(0.26, 0.5, 0.26)), Vector3(ARM_X + side * ARM_WIDTH * 0.5, DECK_Y + 0.3, z)), PropLibrary.WOOD_DARK)
		z += 1.0
		i += 1


## Uzun direkli fener: direk, kol, ışıklı kutu, şapka ve ışıltı.
func _add_lantern(b: MeshBatcher, base: Vector3) -> void:
	b.add(PropLibrary.cylinder(), Transform3D(Basis.from_scale(Vector3(0.1, 2.6, 0.1)), base + Vector3(0.0, 1.3, 0.0)), PropLibrary.WOOD_DARK)
	b.add(PropLibrary.box(), Transform3D(Basis.from_scale(Vector3(0.66, 0.66, 0.66)), base + Vector3(0.0, 2.8, 0.0)), PropLibrary.WOOD_DARK)
	b.add(PropLibrary.box(), Transform3D(Basis.from_scale(Vector3.ONE * 0.56), base + Vector3(0.0, 2.8, 0.0)), PropLibrary.LANTERN)
	b.add(PropLibrary.prism(), Transform3D(Basis.from_scale(Vector3(0.9, 0.4, 0.9)), base + Vector3(0.0, 3.32, 0.0)), PropLibrary.WOOD_DARK)
	_halo(base + Vector3(0.0, 2.8, 0.4), 4.0)


## Kırmızı-krem çizgili tente, tezgâh ve üstünde mallar.
func _add_tent(b: MeshBatcher, pos: Vector3) -> void:
	var origin := Vector3(pos.x, _ground(pos.x, pos.z), pos.z)
	for sx in [-1.4, 1.4]:
		for sz in [-1.0, 1.0]:
			b.add(PropLibrary.cylinder(), Transform3D(Basis.from_scale(Vector3(0.08, 2.0, 0.08)), origin + Vector3(sx, 1.0, sz)), PropLibrary.WOOD_DARK)
	var slices := 5
	for k in slices:
		var z := -1.3 + 2.6 * (k + 0.5) / slices
		b.add(PropLibrary.prism(), Transform3D(Basis.from_scale(Vector3(3.4, 0.9, 2.6 / slices + 0.01)), origin + Vector3(0.0, 2.4, z)), STRIPE if k % 2 == 0 else PropLibrary.CANVAS)
	b.add(PropLibrary.box(), Transform3D(Basis.from_scale(Vector3(2.2, 0.8, 1.0)), origin + Vector3(0.0, 0.4, 0.3)), PropLibrary.WOOD)
	for item in [Vector4(-0.6, 0.0, 0.25, 0.0), Vector4(-0.2, 0.0, 0.4, 1.0), Vector4(0.3, 0.0, 0.2, 2.0), Vector4(0.7, 0.0, 0.45, 0.0)]:
		var color: Color = [Color("#E8B04A"), Color("#D9483B"), Color("#8DB845")][int(item.w)]
		b.add(PropLibrary.sphere_low(), Transform3D(Basis.from_scale(Vector3.ONE * 0.32), origin + Vector3(item.x, 0.95, item.z)), color)


func _add_barrel(b: MeshBatcher, pos: Vector3, on_deck: bool = false) -> void:
	var origin := pos if on_deck else Vector3(pos.x, _ground(pos.x, pos.z), pos.z)
	b.add(PropLibrary.cylinder(), Transform3D(Basis.from_scale(Vector3(0.42, 0.9, 0.42)), origin + Vector3(0.0, 0.45, 0.0)), PropLibrary.WOOD)
	for y in [0.2, 0.7]:
		b.add(PropLibrary.cylinder(), Transform3D(Basis.from_scale(Vector3(0.45, 0.08, 0.45)), origin + Vector3(0.0, y, 0.0)), PropLibrary.WOOD_DARK)


func _add_crate(b: MeshBatcher, pos: Vector3, yaw: float, on_deck: bool = false) -> void:
	var origin := pos if on_deck else Vector3(pos.x, _ground(pos.x, pos.z), pos.z)
	var basis := Basis(Vector3.UP, yaw)
	b.add(PropLibrary.box(), Transform3D(basis * Basis.from_scale(Vector3.ONE * 0.8), origin + Vector3(0.0, 0.4, 0.0)), PropLibrary.WOOD_LIGHT)
	b.add(PropLibrary.box(), Transform3D(basis * Basis.from_scale(Vector3(0.84, 0.12, 0.84)), origin + Vector3(0.0, 0.62, 0.0)), PropLibrary.WOOD_DARK)


## Kumda yığılmış balık ağı.
func _add_net(b: MeshBatcher, pos: Vector3) -> void:
	var origin := Vector3(pos.x, _ground(pos.x, pos.z), pos.z)
	b.add(PropLibrary.sphere_low(), Transform3D(Basis.from_scale(Vector3(1.6, 0.5, 1.2)), origin + Vector3(0.0, 0.1, 0.0)), NET)
	b.add(PropLibrary.sphere_low(), Transform3D(Basis.from_scale(Vector3(0.9, 0.35, 0.8)), origin + Vector3(0.3, 0.3, 0.1)), NET.lightened(0.1))


## İskelenin yanında bağlı küçük sandal (gemi buraya giremez; çarpışmasız).
func _add_rowboat(b: MeshBatcher, pos: Vector3, yaw: float) -> void:
	var basis := Basis(Vector3.UP, yaw)
	b.add(PropLibrary.sphere_low(), Transform3D(basis * Basis.from_scale(Vector3(1.4, 0.7, 3.2)), pos + Vector3(0.0, 0.05, 0.0)), PropLibrary.WOOD)
	b.add(PropLibrary.sphere_low(), Transform3D(basis * Basis.from_scale(Vector3(1.1, 0.25, 2.7)), pos + Vector3(0.0, 0.3, 0.0)), PropLibrary.WOOD_DARK)
	b.add(PropLibrary.box(), Transform3D(basis * Basis.from_scale(Vector3(1.1, 0.1, 0.35)), pos + basis * Vector3(0.0, 0.35, 0.3)), PropLibrary.WOOD_LIGHT)
	for side in [-1.0, 1.0]:
		var oar := basis * Basis(Vector3.BACK, side * 1.25) * Basis.from_scale(Vector3(0.06, 2.0, 0.06))
		b.add(PropLibrary.cylinder(), Transform3D(oar, pos + basis * Vector3(side * 0.9, 0.4, 0.2)), PropLibrary.WOOD_LIGHT)


## Sıcak ışıltı: %30 büyütülmüş dış hale ve küçük parlak bir çekirdek hale.
func _halo(center: Vector3, size: float) -> void:
	_halos.append(Vector4(center.x, center.y, center.z, size * 1.3))
	_halos.append(Vector4(center.x, center.y, center.z, size * 0.5))
