class_name TreasureMap
extends Control
## M ile açılıp kapanan parşömen hazine haritası. Adaları, kayalıkları, limanı ve
## geminin konumunu gösterir; batıklar için yalnızca yaklaşık arama bölgesi
## (gerçek konumdan kaydırılmış kesikli daire) çizilir. Keşfedilen batık X ile,
## hazinesi alınan batık ayrıca onay işaretiyle işaretlenir. Harita açıkken oyun
## durmaz: gemi kontrol edilebilir ve sayaç akar.

## Performans (10. aşama): ada kum/çimen elipsleri ve kayalık daireleri tek bir
## ArrayMesh'te (tek çizim çağrısı), arama bölgelerinin kesikli daireleri tek bir
## draw_multiline çağrısında çizilir; görünüm eskisiyle piksel olarak aynıdır.

## Haritada gösterilen dünya alanı (kamera kadrajı).
const WORLD := Rect2(-60.0, -42.8, 120.0, 85.6)
const MAP_SIZE := Vector2(880.0, 700.0)
const ZONE_RADIUS := 13.0
## Arama bölgesinin merkezi, batığın gerçek konumundan bu kadar kaydırılır
## (her oyunda aynı); gerçek konum her zaman dairenin içinde kalır.
const ZONE_OFFSETS := {&"coral_cove": Vector2(3.0, -2.5), &"misty_pass": Vector2(-3.5, 3.0), &"deep_blue": Vector2(4.0, 3.5)}
const DIFFICULTY := {&"coral_cove": "kolay", &"misty_pass": "orta", &"deep_blue": "zor"}
const SEA := Color("#BFD9C9")
const LAND_SAND := Color("#E6C88E")
const LAND_GRASS := Color("#A9C27A")
const ROCK := Color("#9A8A9E")
const ZONE_INK := Color("#A8432A")
## Elips ve daire başına kenar sayısı; kesikli daire parçası başına çizgi sayısı.
const SEGMENTS := 24
const DASH_STEPS := 5

var _islands: Array[Island] = []
var _rocks: PackedVector4Array = PackedVector4Array()
var _port: Node3D
var _ship: Node3D
var _wrecks: Array = []
var _map_rect := Rect2()
var _redraw_left := 0.0
## Kara ve kayalıkların birleşik mesh'i; harita alanı değişince yeniden kurulur.
var _land_mesh: ArrayMesh
var _land_rect := Rect2()


func _ready() -> void:
	theme = UiTheme.get_theme()
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	hide()


## Sahnedeki adaları, kayalıkları, limanı, gemiyi ve batıkları haritaya bağlar.
func setup(islands: Array, rocks: PackedVector4Array, port: Node3D, ship: Node3D, wrecks: Array) -> void:
	_islands.assign(islands)
	_rocks = rocks
	_port = port
	_ship = ship
	_wrecks = wrecks


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"toggle_map") and GameManager.is_sailing():
		toggle()
		get_viewport().set_input_as_handled()


func toggle() -> void:
	visible = not visible
	if visible:
		queue_redraw()


func close() -> void:
	hide()


## Kesin konumu haritada işaretlenen batıklar (yalnızca keşfedilenler).
func marked_wreck_ids() -> Array[StringName]:
	var ids: Array[StringName] = []
	for wreck in _wrecks:
		if wreck.is_discovered():
			ids.append(wreck.wreck_id)
	return ids


func _process(delta: float) -> void:
	# Gemi okunu güncellemek için saniyede 10 kez yeniden çizmek yeterli.
	if not visible:
		return
	_redraw_left -= delta
	if _redraw_left <= 0.0:
		_redraw_left = 0.1
		queue_redraw()


func _to_map(world: Vector3) -> Vector2:
	var u := (Vector2(world.x, world.z) - WORLD.position) / WORLD.size
	return _map_rect.position + u * _map_rect.size


func _scale() -> float:
	return _map_rect.size.x / WORLD.size.x


func _draw() -> void:
	var paper := Rect2((size - MAP_SIZE) * 0.5, MAP_SIZE)
	var outer := StyleBoxFlat.new()
	outer.bg_color = UiTheme.PARCHMENT
	outer.border_color = UiTheme.PARCHMENT_DARK
	outer.set_border_width_all(10)
	outer.set_corner_radius_all(22)
	outer.shadow_color = Color(0.05, 0.03, 0.15, 0.45)
	outer.shadow_size = 18
	draw_style_box(outer, paper)

	var font := UiTheme.font(800)
	draw_string(font, paper.position + Vector2(0.0, 58.0), "Hazine Haritası", HORIZONTAL_ALIGNMENT_CENTER, paper.size.x, 44, UiTheme.MAP_INK)
	_map_rect = Rect2(paper.position + Vector2(40.0, 76.0), Vector2(paper.size.x - 80.0, (paper.size.x - 80.0) * WORLD.size.y / WORLD.size.x))
	draw_rect(_map_rect, SEA)
	draw_rect(_map_rect, UiTheme.MAP_INK.lerp(UiTheme.PARCHMENT, 0.4), false, 3.0)

	if _land_mesh == null or _land_rect != _map_rect:
		_build_land_mesh()
	draw_mesh(_land_mesh, null)

	if _port:
		var p := _to_map(_port.global_position)
		draw_arc(p, 7.0 * _scale(), 0.0, TAU, 40, UiTheme.GOLD.darkened(0.2), 3.0)
		draw_string(font, p + Vector2(-60.0, 7.0 * _scale() + 26.0), "Liman", HORIZONTAL_ALIGNMENT_CENTER, 120.0, 24, UiTheme.MAP_INK)

	var small := UiTheme.font(700)
	var dashes := PackedVector2Array()
	for wreck in _wrecks:
		_draw_wreck_zone(wreck, small, dashes)
	draw_multiline(dashes, ZONE_INK, 3.0)

	if _ship:
		var pos := _to_map(_ship.global_position)
		var fwd3: Vector3 = -_ship.global_basis.z
		var fwd := Vector2(fwd3.x, fwd3.z).normalized()
		var side := Vector2(-fwd.y, fwd.x)
		draw_colored_polygon(PackedVector2Array([pos + fwd * 16.0, pos - fwd * 10.0 + side * 9.0, pos - fwd * 5.0, pos - fwd * 10.0 - side * 9.0]), Color("#B03A2E"))

	var legend := "Kesikli daire: yaklaşık arama bölgesi   •   X: keşfedilen batık   •   M: Kapat"
	draw_string(small, Vector2(paper.position.x, paper.end.y - 16.0), legend, HORIZONTAL_ALIGNMENT_CENTER, paper.size.x, 22, UiTheme.MAP_INK)


## Bölge başlığını ve işaretlerini çizer; kesikli dairenin çizgi parçalarını
## `dashes` dizisine ekler (hepsi _draw'da tek çağrıyla çizilir).
func _draw_wreck_zone(wreck: Wreck, font: Font, dashes: PackedVector2Array) -> void:
	var offset: Vector2 = ZONE_OFFSETS.get(wreck.wreck_id, Vector2.ZERO)
	var center := _to_map(wreck.global_position + Vector3(offset.x, 0.0, offset.y))
	var radius := ZONE_RADIUS * _scale()
	var ink := ZONE_INK
	var count := 18
	for i in count:
		var a0 := TAU * i / count
		var span := TAU / count * 0.55
		for s in DASH_STEPS:
			var b0 := a0 + span * s / DASH_STEPS
			var b1 := a0 + span * (s + 1) / DASH_STEPS
			dashes.append_array([center + Vector2(cos(b0), sin(b0)) * radius, center + Vector2(cos(b1), sin(b1)) * radius])
	var title := "%s (%s)" % [wreck.wreck_name(), DIFFICULTY.get(wreck.wreck_id, "")]
	draw_string(font, center + Vector2(-140.0, -radius - 8.0), title, HORIZONTAL_ALIGNMENT_CENTER, 280.0, 22, UiTheme.MAP_INK)
	if not wreck.is_discovered():
		draw_string(UiTheme.font(800), center + Vector2(-20.0, 16.0), "?", HORIZONTAL_ALIGNMENT_CENTER, 40.0, 44, ink)
		return
	var exact := _to_map(wreck.global_position)
	draw_line(exact + Vector2(-11, -11), exact + Vector2(11, 11), Color("#C0392B"), 5.0)
	draw_line(exact + Vector2(-11, 11), exact + Vector2(11, -11), Color("#C0392B"), 5.0)
	if wreck.is_looted():
		var check := PackedVector2Array([exact + Vector2(14, -2), exact + Vector2(21, 6), exact + Vector2(34, -12)])
		draw_polyline(check, Color("#2E8B57"), 5.0)


## Kum ve çimen elipsleri ile kayalık dairelerini (aynı sırayla, aynı renklerle)
## tek bir köşe renkli mesh'e yazar.
func _build_land_mesh() -> void:
	var verts := PackedVector2Array()
	var colors := PackedColorArray()
	var k := _scale()
	for island in _islands:
		for lobe in island.lobes:
			_ellipse(verts, colors, island.position + Vector3(lobe.x, 0.0, lobe.y), lobe.z * k, lobe.w * k, LAND_SAND)
	for island in _islands:
		for lobe in island.lobes:
			_ellipse(verts, colors, island.position + Vector3(lobe.x, 0.0, lobe.y), lobe.z * Island.GRASS_RATIO * k, lobe.w * Island.GRASS_RATIO * k, LAND_GRASS)
	for r in _rocks:
		var radius: float = r.z * 0.8 * k
		_ellipse(verts, colors, Vector3(r.x, 0.0, r.y), radius, radius, ROCK)
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_COLOR] = colors
	_land_mesh = ArrayMesh.new()
	_land_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	_land_rect = _map_rect


## Harita pikseli cinsinden yarıçaplı elipsi üçgen yelpazesi olarak ekler.
func _ellipse(verts: PackedVector2Array, colors: PackedColorArray, world_center: Vector3, rx: float, rz: float, color: Color) -> void:
	var c := _to_map(world_center)
	for i in SEGMENTS:
		var a0 := TAU * i / SEGMENTS
		var a1 := TAU * (i + 1) / SEGMENTS
		verts.append_array([c, c + Vector2(cos(a0) * rx, sin(a0) * rz), c + Vector2(cos(a1) * rx, sin(a1) * rz)])
		colors.append_array([color, color, color])
