class_name UiTheme
extends RefCounted
## Ortak masalsı korsan arayüz teması (reference/hud.webp): koyu lacivert-mor
## paneller, ince altın çerçeveler, krem renkli Baloo 2 yazılar.
## Tüm arayüz kökleri `theme = UiTheme.get_theme()` ile bu temayı kullanır.

const PANEL := Color(0.165, 0.141, 0.384, 0.9)
const PANEL_HOVER := Color(0.235, 0.2, 0.5, 0.95)
const GOLD := Color("#E8B04A")
const GOLD_LIGHT := Color("#FFD45A")
const BAR_FILL := Color("#FFC93C")
const CREAM := Color("#FFF4DC")
const WARN := Color("#FF9A85")
const INK := Color("#1A1640")
const PARCHMENT := Color("#F1DDB0")
const PARCHMENT_DARK := Color("#B98A4E")
const MAP_INK := Color("#6B3A1E")

static var _theme: Theme
static var _fonts: Dictionary = {}


## Baloo 2'nin istenen ağırlıktaki hâli (400–800).
static func font(weight: int = 700) -> FontVariation:
	if not _fonts.has(weight):
		var f := FontVariation.new()
		f.base_font = load("res://assets/fonts/Baloo2-Variable.ttf")
		f.variation_opentype = {TextServerManager.get_primary_interface().name_to_tag("wght"): weight}
		_fonts[weight] = f
	return _fonts[weight]


static func panel_style(radius: int = 18, border: int = 3, bg: Color = PANEL, border_color: Color = GOLD) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = border_color
	s.set_border_width_all(border)
	s.set_corner_radius_all(radius)
	s.set_content_margin_all(14)
	s.shadow_color = Color(0.05, 0.03, 0.15, 0.35)
	s.shadow_size = 6
	return s


static func get_theme() -> Theme:
	if _theme:
		return _theme
	var t := Theme.new()
	t.default_font = font(700)
	t.default_font_size = 30

	t.set_color("font_color", "Label", CREAM)
	t.set_color("font_outline_color", "Label", INK)
	t.set_constant("outline_size", "Label", 8)

	t.set_stylebox("panel", "PanelContainer", panel_style())

	var normal := panel_style(16, 3)
	normal.set_content_margin_all(12)
	normal.content_margin_left = 28
	normal.content_margin_right = 28
	var hover := normal.duplicate() as StyleBoxFlat
	hover.bg_color = PANEL_HOVER
	var focus := normal.duplicate() as StyleBoxFlat
	focus.bg_color = PANEL_HOVER
	focus.border_color = GOLD_LIGHT
	focus.set_border_width_all(5)
	var pressed := normal.duplicate() as StyleBoxFlat
	pressed.bg_color = GOLD.darkened(0.35)
	var disabled := normal.duplicate() as StyleBoxFlat
	disabled.bg_color = Color(0.2, 0.2, 0.25, 0.7)
	disabled.border_color = Color(0.5, 0.45, 0.4)
	t.set_stylebox("normal", "Button", normal)
	t.set_stylebox("hover", "Button", hover)
	t.set_stylebox("focus", "Button", focus)
	t.set_stylebox("pressed", "Button", pressed)
	t.set_stylebox("disabled", "Button", disabled)
	t.set_color("font_color", "Button", CREAM)
	t.set_color("font_hover_color", "Button", GOLD_LIGHT)
	t.set_color("font_focus_color", "Button", GOLD_LIGHT)
	t.set_color("font_pressed_color", "Button", CREAM)
	t.set_color("font_disabled_color", "Button", Color(0.75, 0.7, 0.65))
	t.set_color("font_outline_color", "Button", INK)
	t.set_constant("outline_size", "Button", 6)
	t.set_font_size("font_size", "Button", 34)

	for type in ["CheckButton"]:
		var flat := StyleBoxEmpty.new()
		t.set_stylebox("normal", type, flat)
		t.set_stylebox("hover", type, flat)
		t.set_stylebox("pressed", type, flat)
		t.set_stylebox("hover_pressed", type, flat)
		var check_focus := StyleBoxFlat.new()
		check_focus.draw_center = false
		check_focus.border_color = GOLD_LIGHT
		check_focus.set_border_width_all(3)
		check_focus.set_corner_radius_all(10)
		t.set_stylebox("focus", type, check_focus)
		t.set_color("font_color", type, CREAM)
		t.set_color("font_hover_color", type, GOLD_LIGHT)
		t.set_color("font_focus_color", type, GOLD_LIGHT)
		t.set_color("font_pressed_color", type, CREAM)
		t.set_color("font_hover_pressed_color", type, GOLD_LIGHT)
		t.set_font_size("font_size", type, 30)

	var track := StyleBoxFlat.new()
	track.bg_color = INK
	track.set_corner_radius_all(8)
	track.content_margin_top = 6
	track.content_margin_bottom = 6
	var filled := StyleBoxFlat.new()
	filled.bg_color = BAR_FILL
	filled.set_corner_radius_all(8)
	t.set_stylebox("slider", "HSlider", track)
	t.set_stylebox("grabber_area", "HSlider", filled)
	t.set_stylebox("grabber_area_highlight", "HSlider", filled)

	var bar_back := StyleBoxFlat.new()
	bar_back.bg_color = INK
	bar_back.set_corner_radius_all(12)
	var bar_fill := StyleBoxFlat.new()
	bar_fill.bg_color = BAR_FILL
	bar_fill.set_corner_radius_all(12)
	t.set_stylebox("background", "ProgressBar", bar_back)
	t.set_stylebox("fill", "ProgressBar", bar_fill)
	_theme = t
	return t


static func label(text: String, font_size: int, color: Color = CREAM, weight: int = 700) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_override("font", font(weight))
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_color_override("font_color", color)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


## Temalı düğme; basınca tık, klavye ya da fareyle üzerine gelince hafif ses çalar.
static func button(text: String, min_width: float = 380.0) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(min_width, 72.0)
	b.focus_mode = Control.FOCUS_ALL
	b.pressed.connect(AudioManager.play_sfx.bind(&"ui_click"))
	b.mouse_entered.connect(_on_hover.bind(b))
	b.focus_entered.connect(_on_keyboard_focus)
	return b


static func _on_hover(b: Button) -> void:
	if not b.disabled:
		AudioManager.play_sfx(&"ui_move")


## Odak kodla verildiğinde (menü açılırken) ses çalmasın; yalnızca ok tuşlarıyla.
static func _on_keyboard_focus() -> void:
	for action in [&"ui_up", &"ui_down", &"ui_left", &"ui_right", &"ui_focus_next", &"ui_focus_prev"]:
		if Input.is_action_just_pressed(action):
			AudioManager.play_sfx(&"ui_move")
			return


## Kalan süreyi yukarı yuvarlayarak dd:ss biçiminde verir (00:00 yalnızca süre bittiğinde).
static func format_time(seconds: float) -> String:
	var s := ceili(maxf(seconds, 0.0))
	return "%02d:%02d" % [s / 60, s % 60]
