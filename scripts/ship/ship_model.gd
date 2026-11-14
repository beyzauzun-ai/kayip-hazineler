@tool
class_name ShipModel
extends Node3D
## Sevimli korsan gemisi modeli: sıcak kahverengi gövde, altın lombozlar, kıç
## köşkü, iki direk, kabarık krem yelkenler ve kırmızı bayrak. İleri yön -Z;
## boy yaklaşık 6,5 birim. Gövde tek mesh'tir; bayrak ve iz köpüğü ayrı tutulur
## çünkü Ship script'i onları her kare canlandırır.

const HULL := Color("#A0602E")
const HULL_DARK := Color("#6E3F1E")
const DECK := Color("#D39A5E")
const GOLD := Color("#E8B04A")
const FLAG := Color("#D9483B")

## Direkler: (z, yükseklik)
const MASTS: Array[Vector2] = [Vector2(-1.0, 4.0), Vector2(0.7, 4.8)]
const DECK_Y := 1.0

@export_tool_button("Yeniden Oluştur", "Reload") var rebuild_action: Callable = rebuild

var _flag_pivot: Node3D
var _wake_material: ShaderMaterial


func _ready() -> void:
	rebuild()


func rebuild() -> void:
	PropLibrary.clear_generated(self)
	var b := MeshBatcher.new()
	_add_hull(b)
	_add_stern(b)
	_add_rigging(b)
	PropLibrary.add_mesh(self, "_Govde", b.commit(PropLibrary.toon_material()), true)
	_add_flag()
	_add_wake()


## Bayrağı rüzgârda dalgalandırır.
func wave_flag(time: float) -> void:
	if _flag_pivot:
		_flag_pivot.rotation.y = sin(time * 5.0) * 0.22 + sin(time * 8.3) * 0.08


## Gemi hızına göre gövde etrafındaki köpüğün görünürlüğü (0..1).
func set_wake_strength(strength: float) -> void:
	if _wake_material:
		_wake_material.set_shader_parameter("foam_color", Color(1.0, 1.0, 1.0, 0.25 + 0.65 * clampf(strength, 0.0, 1.0)))


func _part(b: MeshBatcher, mesh: Mesh, pos: Vector3, size: Vector3, color: Color, basis := Basis.IDENTITY) -> void:
	b.add(mesh, Transform3D(basis * Basis.from_scale(size), pos), color)


## Yarıçapları verilen elipsoit (PropLibrary.sphere() birim çaplıdır).
func _ellipsoid(b: MeshBatcher, pos: Vector3, radii: Vector3, color: Color) -> void:
	_part(b, PropLibrary.sphere(), pos, radii * 2.0, color)


func _add_hull(b: MeshBatcher) -> void:
	_ellipsoid(b, Vector3(0.0, 0.1, 0.1), Vector3(1.3, 0.95, 3.1), HULL)
	_ellipsoid(b, Vector3(0.0, 0.9, 0.1), Vector3(1.36, 0.22, 3.15), HULL_DARK)
	_ellipsoid(b, Vector3(0.0, DECK_Y + 0.08, 0.1), Vector3(1.15, 0.1, 2.8), DECK)
	_ellipsoid(b, Vector3(0.0, 0.95, -2.3), Vector3(0.9, 0.6, 1.2), HULL)
	for side in [-1.0, 1.0]:
		for z in [-1.2, 0.0, 1.2]:
			_ellipsoid(b, Vector3(side * 1.15, 0.55, z), Vector3.ONE * 0.17, GOLD)
	var sprit_dir := Vector3(0.0, 0.35, -1.0).normalized()
	_part(b, PropLibrary.cylinder(), Vector3(0.0, 1.3, -3.3), Vector3(0.08, 1.6, 0.08), HULL_DARK, Basis(Quaternion(Vector3.UP, sprit_dir)))


func _add_stern(b: MeshBatcher) -> void:
	var box := PropLibrary.box()
	_part(b, box, Vector3(0.0, 1.35, 2.1), Vector3(2.0, 0.8, 1.4), HULL)
	_part(b, box, Vector3(0.0, 1.8, 2.1), Vector3(2.12, 0.15, 1.52), HULL_DARK)
	_part(b, box, Vector3(0.0, 1.05, 2.82), Vector3(2.0, 0.1, 0.06), GOLD)
	for x in [-0.45, 0.45]:
		_part(b, box, Vector3(x, 1.35, 2.81), Vector3(0.36, 0.36, 0.06), PropLibrary.WINDOW)
	_part(b, PropLibrary.cylinder(), Vector3(0.0, 2.15, 2.5), Vector3(0.05, 0.6, 0.05), HULL_DARK)
	_part(b, box, Vector3(0.0, 2.5, 2.5), Vector3.ONE * 0.24, PropLibrary.LANTERN)


func _add_rigging(b: MeshBatcher) -> void:
	var cylinder := PropLibrary.cylinder()
	var yard_basis := Basis(Vector3.BACK, PI * 0.5)
	for mast in MASTS:
		var z := mast.x
		var height := mast.y
		_part(b, cylinder, Vector3(0.0, DECK_Y + height * 0.5, z), Vector3(0.13, height, 0.13), HULL_DARK)
		var low_y := DECK_Y + height * 0.42
		var high_y := DECK_Y + height * 0.78
		_part(b, cylinder, Vector3(0.0, low_y + 0.95, z), Vector3(0.06, 2.7, 0.06), HULL_DARK, yard_basis)
		_part(b, cylinder, Vector3(0.0, high_y + 0.65, z), Vector3(0.05, 2.0, 0.05), HULL_DARK, yard_basis)
		# Kabarık yelkenler: her yönden (yandan bile) okunabilsin diye kalın.
		_ellipsoid(b, Vector3(0.0, low_y, z - 0.3), Vector3(1.3, 0.95, 0.42), PropLibrary.CANVAS)
		_ellipsoid(b, Vector3(0.0, high_y, z - 0.25), Vector3(0.95, 0.65, 0.34), PropLibrary.CANVAS.darkened(0.04))
	var main := MASTS[1]
	_part(b, cylinder, Vector3(0.0, DECK_Y + main.y - 0.7, main.x), Vector3(0.32, 0.25, 0.32), HULL)


func _add_flag() -> void:
	var main := MASTS[1]
	_flag_pivot = Node3D.new()
	_flag_pivot.name = "_BayrakPivot"
	_flag_pivot.set_meta(&"generated", true)
	_flag_pivot.position = Vector3(0.0, DECK_Y + main.y - 0.1, main.x)
	add_child(_flag_pivot)
	var b := MeshBatcher.new()
	b.add(PropLibrary.box(), Transform3D(Basis.from_scale(Vector3(0.05, 0.45, 0.85)), Vector3(0.0, 0.0, 0.45)), FLAG)
	PropLibrary.add_mesh(_flag_pivot, "_Bayrak", b.commit(PropLibrary.toon_material()), true)


func _add_wake() -> void:
	_wake_material = PropLibrary.foam_material().duplicate() as ShaderMaterial
	var b := MeshBatcher.new()
	b.add(PropLibrary.ring(1.35, 3.0, 0.9), Transform3D(Basis.IDENTITY, Vector3(0.0, 0.05, 0.1)))
	b.add(PropLibrary.ring(0.8, 2.0, 0.7), Transform3D(Basis.IDENTITY, Vector3(0.0, 0.05, 4.2)))
	PropLibrary.add_mesh(self, "_Iz", b.commit(_wake_material), false)
	set_wake_strength(0.0)
