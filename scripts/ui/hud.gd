class_name Hud
extends Control
## Oyun içi HUD (reference/hud.webp): sol üstte kum saati ve kalan süre, sağ
## üstte üç eser yuvası ve altın, altta tuş ipuçları. Kısa bildirimler (keşif,
## uyarı, bulunan eser) gemi ve batıkları kapatmasın diye üst paneller arasındaki
## boşlukta gösterilir. Paneller 96 px yüksekliğinde tutulur; Derin Mavi batığı
## (ekranda y ≈ 193) sağ üst panellerin altında görünür kalır.

const MESSAGE_TIME := 2.4
const TIME_WARNING := 20.0
const TOP := 16.0
const PANEL_HEIGHT := 96.0
## Bildirimin ortalandığı x: sol süre paneli ile sağ eser paneli arasındaki boşluk.
const TOAST_CENTER_X := 757.0

var _time_label: Label
var _artifact_label: Label
var _gold_label: Label
var _slots: Dictionary = {}
var _toast: PanelContainer
var _toast_label: Label
var _toast_left := 0.0


func _ready() -> void:
	theme = UiTheme.get_theme()
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_build_time_panel()
	_build_artifact_panel()
	_build_gold_panel()
	_build_hint_bar()
	_build_toast()
	for wreck in get_tree().get_nodes_in_group(&"wrecks"):
		wreck.discovered.connect(_on_discovered)
		wreck.extraction_failed.connect(_on_failed)
		wreck.extracted.connect(_on_extracted)
		wreck.hint.connect(_on_hint)


func _process(delta: float) -> void:
	# Metin ve renkler yalnızca değiştiğinde yazılır; her kare yazmak arayüz
	# yerleşimini yeniden hesaplatır ve entegre ekran kartında FPS düşürür.
	var t := GameManager.time_left
	var warning := t <= TIME_WARNING and GameManager.is_sailing()
	_set_text(_time_label, UiTheme.format_time(t))
	if warning != _time_label.has_meta(&"warning"):
		_time_label.add_theme_color_override("font_color", UiTheme.WARN if warning else UiTheme.CREAM)
		if warning:
			_time_label.set_meta(&"warning", true)
		else:
			_time_label.remove_meta(&"warning")
			_time_label.scale = Vector2.ONE
	if warning:
		_time_label.scale = Vector2.ONE * (1.0 + 0.06 * sin(Time.get_ticks_msec() * 0.012))
	_set_text(_artifact_label, "Eser %d/%d" % [GameManager.collected.size(), GameManager.ARTIFACTS.size()])
	_set_text(_gold_label, "Altın: %d" % GameManager.gold)
	for id in _slots:
		var collected: bool = id in GameManager.collected
		if _slots[id].active != collected:
			_slots[id].active = collected
	if _toast_left > 0.0:
		_toast_left = maxf(_toast_left - delta, 0.0)
		_toast.visible = _toast_left > 0.0
		_toast.modulate.a = clampf(_toast_left / 0.4, 0.0, 1.0)


static func _set_text(label: Label, text: String) -> void:
	if label.text != text:
		label.text = text


func show_message(text: String, color: Color = UiTheme.GOLD_LIGHT) -> void:
	_toast_label.text = text
	_toast_label.add_theme_color_override("font_color", color)
	_toast.reset_size()
	_toast.position = Vector2(TOAST_CENTER_X - _toast.size.x * 0.5, TOP + 6.0)
	_toast_left = MESSAGE_TIME
	_toast.show()


## Bildirim kutusunun ekrandaki alanı (testler ve yerleşim kontrolü için).
func toast_rect() -> Rect2:
	return _toast.get_global_rect() if _toast.visible else Rect2()


func _on_discovered(wreck: Wreck) -> void:
	show_message("%s keşfedildi!" % wreck.wreck_name())


func _on_failed(_wreck: Wreck, reason: String) -> void:
	show_message("Çıkarma yarıda kaldı! (%s)" % reason, UiTheme.WARN)


func _on_extracted(wreck: Wreck) -> void:
	show_message("%s bulundu! (%d/%d)" % [wreck.artifact_name(), GameManager.collected.size(), GameManager.ARTIFACTS.size()])


func _on_hint(_wreck: Wreck, text: String) -> void:
	show_message(text, UiTheme.WARN)


func _panel(pos: Vector2, width: float) -> HBoxContainer:
	var panel := PanelContainer.new()
	panel.position = pos
	panel.custom_minimum_size = Vector2(width, PANEL_HEIGHT)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(panel)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 14)
	panel.add_child(row)
	return row


func _icon(kind: HudIcon.Kind, edge: float) -> HudIcon:
	var icon := HudIcon.new()
	icon.kind = kind
	icon.custom_minimum_size = Vector2(edge, edge)
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return icon


func _build_time_panel() -> void:
	var row := _panel(Vector2(24.0, TOP), 300.0)
	row.add_child(_icon(HudIcon.Kind.HOURGLASS, 66.0))
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", -14)
	row.add_child(col)
	_time_label = UiTheme.label("02:00", 54, UiTheme.CREAM, 800)
	_time_label.pivot_offset = Vector2(60.0, 34.0)
	col.add_child(_time_label)
	col.add_child(UiTheme.label("Kalan Süre", 24))


func _build_artifact_panel() -> void:
	var row := _panel(Vector2(1190.0, TOP), 372.0)
	var kinds := {&"compass": HudIcon.Kind.COMPASS, &"crown": HudIcon.Kind.CROWN, &"sapphire": HudIcon.Kind.GEM}
	for entry in GameManager.ARTIFACTS:
		var slot := PanelContainer.new()
		var style := UiTheme.panel_style(33, 3, UiTheme.INK.lerp(UiTheme.PANEL, 0.4))
		style.set_content_margin_all(6)
		style.shadow_size = 0
		slot.add_theme_stylebox_override("panel", style)
		slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var icon := _icon(kinds[entry["id"]], 52.0)
		icon.active = false
		slot.add_child(icon)
		row.add_child(slot)
		_slots[entry["id"]] = icon
	_artifact_label = UiTheme.label("Eser 0/3", 34)
	row.add_child(_artifact_label)


func _build_gold_panel() -> void:
	var row := _panel(Vector2(1578.0, TOP), 318.0)
	row.add_child(_icon(HudIcon.Kind.COINS, 64.0))
	_gold_label = UiTheme.label("Altın: 0", 40)
	row.add_child(_gold_label)


func _build_hint_bar() -> void:
	var row := _panel(Vector2.ZERO, 0.0)
	var panel := row.get_parent() as PanelContainer
	panel.custom_minimum_size.y = 70.0
	row.add_theme_constant_override("separation", 10)
	var hints := [["W/S", "İleri-Geri"], ["A/D", "Dön"], ["M", "Harita"], ["E", "Hazine Çıkar"], ["Esc", "Duraklat"]]
	for i in hints.size():
		if i > 0:
			row.add_child(UiTheme.label("•", 26, UiTheme.GOLD))
		var cap := PanelContainer.new()
		var cap_style := StyleBoxFlat.new()
		cap_style.bg_color = UiTheme.INK
		cap_style.border_color = UiTheme.CREAM
		cap_style.set_border_width_all(2)
		cap_style.set_corner_radius_all(8)
		cap_style.content_margin_left = 10
		cap_style.content_margin_right = 10
		cap_style.content_margin_top = 0
		cap_style.content_margin_bottom = 0
		cap.add_theme_stylebox_override("panel", cap_style)
		cap.mouse_filter = Control.MOUSE_FILTER_IGNORE
		cap.add_child(UiTheme.label(hints[i][0], 26))
		row.add_child(cap)
		row.add_child(UiTheme.label(hints[i][1], 28))
	panel.reset_size()
	panel.position = Vector2((1920.0 - panel.size.x) * 0.5, 1080.0 - panel.size.y - 14.0)


func _build_toast() -> void:
	_toast = PanelContainer.new()
	var style := UiTheme.panel_style(16, 2)
	style.content_margin_top = 6
	style.content_margin_bottom = 6
	style.content_margin_left = 22
	style.content_margin_right = 22
	_toast.add_theme_stylebox_override("panel", style)
	_toast.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_toast_label = UiTheme.label("", 32)
	_toast.add_child(_toast_label)
	add_child(_toast)
	_toast.hide()
