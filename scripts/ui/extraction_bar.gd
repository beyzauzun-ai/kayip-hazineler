class_name ExtractionBar
extends Control
## Hazine çıkarma çubuğu. Gemiyi ve çıkarma yapılan batığı kapatmasın diye ikisinin
## ekrandaki kapsayıcı kutusu hesaplanır ve çubuk bu kutunun ÜSTÜNE yerleştirilir;
## üst HUD panellerine çarpacaksa kutunun ALTINA, oraya da sığmazsa YANINA geçer.
## Batıkların ilerleme sinyallerini dinler; çıkarma bitince ya da yarıda kalınca
## gizlenir. (Bildirim metinleri HUD'ın üst ortasında gösterilir.)

## Gemi ve batığın ekran kutusu için yaklaşık dünya ölçüleri: yarıçap, alt, üst.
const SHIP_EXTENT := Vector3(3.6, 0.0, 7.0)
const WRECK_EXTENT := Vector3(3.6, -1.0, 3.2)
const MARGIN := 10.0
## Üst HUD panellerinin alt sınırı ve alt ipucu şeridinin üst sınırı (1920x1080).
const SAFE_TOP := 122.0
const SAFE_BOTTOM := 980.0

var _panel: PanelContainer
var _bar: ProgressBar
var _ship: Node3D
var _wreck: Node3D


func _ready() -> void:
	theme = UiTheme.get_theme()
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_build()
	_ship = get_tree().get_first_node_in_group(&"player_ship")
	for wreck in get_tree().get_nodes_in_group(&"wrecks"):
		wreck.extraction_progress.connect(_on_progress)
		wreck.extraction_failed.connect(_on_finished.unbind(1))
		wreck.extracted.connect(_on_finished)


func _process(_delta: float) -> void:
	var camera := get_viewport().get_camera_3d()
	if _ship == null or camera == null or not _panel.visible:
		return
	var avoid := _screen_box(camera, _ship.global_position, SHIP_EXTENT)
	if _wreck:
		avoid = avoid.merge(_screen_box(camera, _wreck.global_position, WRECK_EXTENT))
	_panel.position = _place(avoid, _panel.size)


## Gemi ve batığın birlikte kapladığı ekran alanı (testler ve yerleşim için).
func avoid_rect() -> Rect2:
	var camera := get_viewport().get_camera_3d()
	var box := _screen_box(camera, _ship.global_position, SHIP_EXTENT)
	if _wreck:
		box = box.merge(_screen_box(camera, _wreck.global_position, WRECK_EXTENT))
	return box


func panel_rect() -> Rect2:
	return Rect2(_panel.position, _panel.size) if _panel.visible else Rect2()


func _place(avoid: Rect2, panel_size: Vector2) -> Vector2:
	var x := clampf(avoid.get_center().x - panel_size.x * 0.5, 8.0, 1912.0 - panel_size.x)
	var above := avoid.position.y - MARGIN - panel_size.y
	if above >= SAFE_TOP:
		return Vector2(x, above)
	var below := avoid.end.y + MARGIN
	if below + panel_size.y <= SAFE_BOTTOM:
		return Vector2(x, below)
	var right := avoid.end.x + MARGIN
	if right + panel_size.x > 1912.0:
		right = avoid.position.x - MARGIN - panel_size.x
	return Vector2(right, clampf(avoid.get_center().y - panel_size.y * 0.5, SAFE_TOP, SAFE_BOTTOM - panel_size.y))


## Dünya-eksenli bir kutunun (yarıçap, alt, üst) köşelerinin ekran kapsayıcısı.
static func _screen_box(camera: Camera3D, center: Vector3, extent: Vector3) -> Rect2:
	var box := Rect2(camera.unproject_position(center), Vector2.ZERO)
	for sx in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			for y in [extent.y, extent.z]:
				box = box.expand(camera.unproject_position(center + Vector3(sx * extent.x, y, sz * extent.x)))
	return box


func _on_progress(wreck: Wreck, ratio: float) -> void:
	_wreck = wreck
	_panel.visible = ratio > 0.0
	_bar.value = ratio * 100.0


func _on_finished(_wreck_node: Wreck) -> void:
	_panel.hide()


func _build() -> void:
	_panel = PanelContainer.new()
	var style := UiTheme.panel_style(14, 3)
	style.set_content_margin_all(9)
	style.content_margin_left = 14
	style.content_margin_right = 14
	_panel.add_theme_stylebox_override("panel", style)
	_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 4)
	_panel.add_child(box)
	var title := UiTheme.label("Hazine çıkarılıyor... (E basılı tut)", 22)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(title)
	_bar = ProgressBar.new()
	_bar.show_percentage = false
	_bar.custom_minimum_size = Vector2(300.0, 20.0)
	box.add_child(_bar)
	_panel.hide()
