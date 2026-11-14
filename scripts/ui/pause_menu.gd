class_name PauseMenu
extends Control
## Esc ile açılan duraklatma menüsü: Devam Et, Yeniden Başlat, Ana Menü.
## Açıkken SceneTree duraklatılır; sayaç, gemi ve batıklar durur. Kendisi
## duraklatmadan etkilenmez (PROCESS_MODE_ALWAYS). Yalnızca görev sürerken açılır.

signal restart_requested
signal menu_requested

var _resume: Button


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	theme = UiTheme.get_theme()
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_build()
	hide()


func _unhandled_input(event: InputEvent) -> void:
	if not event.is_action_pressed(&"pause"):
		return
	if visible:
		resume()
	elif GameManager.is_sailing():
		open()
	else:
		return
	get_viewport().set_input_as_handled()


func open() -> void:
	get_tree().paused = true
	AudioManager.set_game_paused(true)
	show()
	_resume.grab_focus()


func resume() -> void:
	hide()
	get_tree().paused = false
	AudioManager.set_game_paused(false)


func _build() -> void:
	var shade := ColorRect.new()
	shade.color = Color(0.06, 0.04, 0.18, 0.5)
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(shade)
	var panel := PanelContainer.new()
	var style := UiTheme.panel_style(26, 4)
	style.set_content_margin_all(36)
	panel.add_theme_stylebox_override("panel", style)
	add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 18)
	panel.add_child(box)
	var title := UiTheme.label("Duraklatıldı", 60, UiTheme.GOLD_LIGHT, 800)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(title)
	var note := UiTheme.label("Süre durdu. Gemi ve batıklar seni bekliyor.", 26)
	note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(note)
	_resume = UiTheme.button("Devam Et", 420.0)
	_resume.pressed.connect(resume)
	var restart := UiTheme.button("Yeniden Başlat", 420.0)
	restart.pressed.connect(func(): restart_requested.emit())
	var menu := UiTheme.button("Ana Menü", 420.0)
	menu.pressed.connect(func(): menu_requested.emit())
	for b in [_resume, restart, menu]:
		b.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		box.add_child(b)
	panel.reset_size()
	panel.position = (Vector2(1920.0, 1080.0) - panel.size) * 0.5
