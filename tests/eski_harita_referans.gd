extends Control
## Referans: birleştirmeden önceki hazine haritası çizimi (10. aşama öncesi
## treasure_map.gd _draw kodu, birebir). Yalnızca harita_dogrulama.gd'nin görsel
## karşılaştırması için kullanılır; oyunda kullanılmaz. Ayrı dosyadır, çünkü
## UiTheme'e başvuran kod -s ile çalışan test betiğinin içinde derlenemiyor.

const ZONE_RADIUS := 13.0
const ZONE_OFFSETS := {&"coral_cove": Vector2(3.0, -2.5), &"misty_pass": Vector2(-3.5, 3.0), &"deep_blue": Vector2(4.0, 3.5)}
const DIFFICULTY := {&"coral_cove": "kolay", &"misty_pass": "orta", &"deep_blue": "zor"}
const SEA := Color("#BFD9C9")
const LAND_SAND := Color("#E6C88E")
const LAND_GRASS := Color("#A9C27A")
const MAP_SIZE := Vector2(880.0, 700.0)
const WORLD := Rect2(-60.0, -42.8, 120.0, 85.6)
var _islands: Array = []
var _rocks: PackedVector4Array
var _port: Node3D
var _ship: Node3D
var _wrecks: Array = []
var _map_rect := Rect2()

func setup(islands: Array, rocks: PackedVector4Array, port: Node3D, ship: Node3D, wrecks: Array) -> void:
	_islands = islands
	_rocks = rocks
	_port = port
	_ship = ship
	_wrecks = wrecks
	theme = UiTheme.get_theme()
	mouse_filter = Control.MOUSE_FILTER_IGNORE

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
	for island in _islands:
		for lobe in island.lobes:
			_ellipse(island.position + Vector3(lobe.x, 0.0, lobe.y), lobe.z, lobe.w, LAND_SAND)
	for island in _islands:
		for lobe in island.lobes:
			_ellipse(island.position + Vector3(lobe.x, 0.0, lobe.y), lobe.z * Island.GRASS_RATIO, lobe.w * Island.GRASS_RATIO, LAND_GRASS)
	for r in _rocks:
		draw_circle(_to_map(Vector3(r.x, 0.0, r.y)), r.z * 0.8 * _scale(), Color("#9A8A9E"))
	if _port:
		var p := _to_map(_port.global_position)
		draw_arc(p, 7.0 * _scale(), 0.0, TAU, 40, UiTheme.GOLD.darkened(0.2), 3.0)
		draw_string(font, p + Vector2(-60.0, 7.0 * _scale() + 26.0), "Liman", HORIZONTAL_ALIGNMENT_CENTER, 120.0, 24, UiTheme.MAP_INK)
	var small := UiTheme.font(700)
	for wreck in _wrecks:
		_draw_wreck_zone(wreck, small)
	if _ship:
		var pos := _to_map(_ship.global_position)
		var fwd3: Vector3 = -_ship.global_basis.z
		var fwd := Vector2(fwd3.x, fwd3.z).normalized()
		var side := Vector2(-fwd.y, fwd.x)
		draw_colored_polygon(PackedVector2Array([pos + fwd * 16.0, pos - fwd * 10.0 + side * 9.0, pos - fwd * 5.0, pos - fwd * 10.0 - side * 9.0]), Color("#B03A2E"))
	var legend := "Kesikli daire: yaklaşık arama bölgesi   •   X: keşfedilen batık   •   M: Kapat"
	draw_string(small, Vector2(paper.position.x, paper.end.y - 16.0), legend, HORIZONTAL_ALIGNMENT_CENTER, paper.size.x, 22, UiTheme.MAP_INK)

func _draw_wreck_zone(wreck, font: Font) -> void:
	var offset: Vector2 = ZONE_OFFSETS.get(wreck.wreck_id, Vector2.ZERO)
	var center := _to_map(wreck.global_position + Vector3(offset.x, 0.0, offset.y))
	var radius := ZONE_RADIUS * _scale()
	var ink := Color("#A8432A")
	var dashes := 18
	for i in dashes:
		var a0 := TAU * i / dashes
		draw_arc(center, radius, a0, a0 + TAU / dashes * 0.55, 6, ink, 3.0)
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

func _ellipse(world_center: Vector3, rx: float, rz: float, color: Color) -> void:
	var c := _to_map(world_center)
	var k := _scale()
	var points := PackedVector2Array()
	for i in 24:
		var a := TAU * i / 24.0
		points.append(c + Vector2(cos(a) * rx, sin(a) * rz) * k)
	draw_colored_polygon(points, color)
