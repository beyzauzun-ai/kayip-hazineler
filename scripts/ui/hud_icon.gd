@tool
class_name HudIcon
extends Control
## Kodla çizilen küçük masalsı simgeler (dosya gerektirmez): kum saati,
## pusula, taç, safir ve altın sikkeler. `active` false ise soluk siluet olur.

enum Kind { HOURGLASS, COMPASS, CROWN, GEM, COINS }

const GOLD := Color("#F2B53A")
const GOLD_DARK := Color("#B8801F")
const GOLD_LIGHT := Color("#FFE08A")
const WOOD := Color("#8A5A2B")
const SAND := Color("#F2C14E")
const RED := Color("#D9483B")
const SAPPHIRE := Color("#3E7BFA")
const SAPPHIRE_LIGHT := Color("#9CC2FF")

@export var kind := Kind.HOURGLASS:
	set(value):
		kind = value
		queue_redraw()
@export var active := true:
	set(value):
		active = value
		modulate = Color.WHITE if active else Color(0.5, 0.5, 0.68, 0.55)

var _c := Vector2.ZERO
var _s := 1.0


func _draw() -> void:
	_s = minf(size.x, size.y)
	_c = size * 0.5
	match kind:
		Kind.HOURGLASS:
			_hourglass()
		Kind.COMPASS:
			_compass()
		Kind.CROWN:
			_crown()
		Kind.GEM:
			_gem()
		Kind.COINS:
			_coins()


## Simge koordinatı (-0,5..0,5) → piksel.
func _p(x: float, y: float) -> Vector2:
	return _c + Vector2(x, y) * _s


func _poly(points: Array, color: Color) -> void:
	var packed := PackedVector2Array()
	for pt in points:
		packed.append(_p(pt.x, pt.y))
	draw_colored_polygon(packed, color)


func _hourglass() -> void:
	_poly([Vector2(-0.22, -0.38), Vector2(0.22, -0.38), Vector2(0.03, 0.0), Vector2(0.22, 0.38), Vector2(-0.22, 0.38), Vector2(-0.03, 0.0)], Color(0.85, 0.95, 1.0, 0.45))
	_poly([Vector2(-0.14, -0.2), Vector2(0.14, -0.2), Vector2(0.02, -0.03), Vector2(-0.02, -0.03)], SAND)
	_poly([Vector2(-0.2, 0.36), Vector2(0.2, 0.36), Vector2(0.0, 0.16)], SAND)
	draw_line(_p(0.0, -0.03), _p(0.0, 0.3), SAND, maxf(_s * 0.025, 1.0))
	for x in [-0.28, 0.28]:
		draw_line(_p(x, -0.42), _p(x, 0.42), WOOD, _s * 0.06)
	for y in [-0.46, 0.38]:
		draw_rect(Rect2(_p(-0.34, y), Vector2(0.68, 0.08) * _s), GOLD)
		draw_rect(Rect2(_p(-0.34, y + 0.06), Vector2(0.68, 0.02) * _s), GOLD_DARK)


func _compass() -> void:
	draw_circle(_c, _s * 0.46, GOLD_DARK)
	draw_circle(_c, _s * 0.42, GOLD)
	draw_circle(_c, _s * 0.34, Color("#FFF1D0"))
	for i in 8:
		var a := TAU * i / 8.0
		var r1 := 0.27 if i % 2 == 0 else 0.3
		draw_line(_c + Vector2(cos(a), sin(a)) * _s * r1, _c + Vector2(cos(a), sin(a)) * _s * 0.33, GOLD_DARK, maxf(_s * 0.02, 1.0))
	_poly([Vector2(0.0, -0.3), Vector2(0.07, 0.0), Vector2(-0.07, 0.0)], RED)
	_poly([Vector2(0.0, 0.3), Vector2(0.07, 0.0), Vector2(-0.07, 0.0)], Color("#3A3550"))
	draw_circle(_c, _s * 0.05, GOLD_DARK)


func _crown() -> void:
	_poly([Vector2(-0.4, 0.28), Vector2(-0.42, -0.2), Vector2(-0.2, 0.02), Vector2(0.0, -0.32), Vector2(0.2, 0.02), Vector2(0.42, -0.2), Vector2(0.4, 0.28)], GOLD)
	draw_rect(Rect2(_p(-0.4, 0.16), Vector2(0.8, 0.14) * _s), GOLD_DARK)
	for pt in [Vector2(-0.42, -0.22), Vector2(0.0, -0.34), Vector2(0.42, -0.22)]:
		draw_circle(_p(pt.x, pt.y), _s * 0.06, GOLD_LIGHT)
	draw_circle(_p(-0.2, 0.23), _s * 0.045, RED)
	draw_circle(_p(0.0, 0.23), _s * 0.05, SAPPHIRE)
	draw_circle(_p(0.2, 0.23), _s * 0.045, RED)


func _gem() -> void:
	_poly([Vector2(-0.38, -0.1), Vector2(-0.2, -0.32), Vector2(0.2, -0.32), Vector2(0.38, -0.1), Vector2(0.0, 0.4)], SAPPHIRE)
	_poly([Vector2(-0.2, -0.32), Vector2(0.2, -0.32), Vector2(0.12, -0.1), Vector2(-0.12, -0.1)], SAPPHIRE_LIGHT)
	_poly([Vector2(-0.12, -0.1), Vector2(0.12, -0.1), Vector2(0.0, 0.4)], Color("#5C93FF"))
	var w := maxf(_s * 0.02, 1.0)
	draw_line(_p(-0.38, -0.1), _p(0.38, -0.1), SAPPHIRE_LIGHT, w)
	draw_line(_p(-0.12, -0.1), _p(0.0, 0.4), Color("#2A5BD0"), w)
	draw_line(_p(0.12, -0.1), _p(0.0, 0.4), Color("#2A5BD0"), w)
	draw_circle(_p(-0.08, -0.22), _s * 0.035, Color.WHITE)


func _coins() -> void:
	for coin in [Vector3(0.14, -0.14, 0.24), Vector3(-0.16, -0.02, 0.24), Vector3(0.08, 0.14, 0.28)]:
		var center := _p(coin.x, coin.y)
		draw_circle(center, _s * coin.z, GOLD_DARK)
		draw_circle(center, _s * (coin.z - 0.04), GOLD)
		draw_circle(center, _s * (coin.z - 0.11), GOLD_LIGHT)
		draw_circle(center, _s * (coin.z - 0.15), GOLD)
