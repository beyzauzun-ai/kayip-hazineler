class_name MainMenu
extends Control
## Türkçe ana menü: Oyna, Ayarlar, Çıkış. Arkada canlı deniz sahnesi görünür;
## menü açıkken görev başlamaz ve sayaç akmaz. Ayarlar: ses aç/kapat, müzik
## ve efekt seviyesi (AudioManager'a kaydedilir).

signal play_requested

var _panel: PanelContainer
var _main_box: VBoxContainer
var _settings_box: VBoxContainer
var _play: Button
var _sound_toggle: CheckButton
var _music_slider: HSlider
var _sfx_slider: HSlider
var _music_value: Label
var _sfx_value: Label


func _ready() -> void:
	theme = UiTheme.get_theme()
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_build()
	_show_settings(false)
	hide()


func open() -> void:
	show()
	_show_settings(false)


func close() -> void:
	hide()


func _unhandled_input(event: InputEvent) -> void:
	if visible and _settings_box.visible and event.is_action_pressed(&"pause"):
		_show_settings(false)
		get_viewport().set_input_as_handled()


func _show_settings(on: bool) -> void:
	_main_box.visible = not on
	_settings_box.visible = on
	if on:
		_sound_toggle.button_pressed = AudioManager.sound_enabled
		_music_slider.value = AudioManager.music_volume * 100.0
		_sfx_slider.value = AudioManager.sfx_volume * 100.0
		_sound_toggle.grab_focus()
	else:
		_play.grab_focus()
	# Panel, görünen bölüme göre yeniden boyutlanıp ortalanır.
	_panel.reset_size()
	_panel.position = Vector2((1920.0 - _panel.size.x) * 0.5, 400.0)


func _build() -> void:
	var shade := ColorRect.new()
	shade.color = Color(0.09, 0.07, 0.25, 0.45)
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(shade)

	var title := UiTheme.label("Kayıp Hazineler", 120, UiTheme.GOLD_LIGHT, 800)
	title.add_theme_constant_override("outline_size", 18)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.position = Vector2((1920.0 - 1200.0) * 0.5, 110.0)
	title.size = Vector2(1200.0, 150.0)
	add_child(title)
	var subtitle := UiTheme.label("Son 120 Saniye", 56, UiTheme.CREAM, 800)
	subtitle.add_theme_constant_override("outline_size", 12)
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.position = Vector2((1920.0 - 1200.0) * 0.5, 255.0)
	subtitle.size = Vector2(1200.0, 80.0)
	add_child(subtitle)

	_panel = PanelContainer.new()
	var style := UiTheme.panel_style(26, 4)
	style.set_content_margin_all(34)
	_panel.add_theme_stylebox_override("panel", style)
	add_child(_panel)
	var stack := VBoxContainer.new()
	_panel.add_child(stack)

	_main_box = VBoxContainer.new()
	_main_box.add_theme_constant_override("separation", 18)
	stack.add_child(_main_box)
	_play = UiTheme.button("Oyna")
	_play.pressed.connect(func(): play_requested.emit())
	var settings := UiTheme.button("Ayarlar")
	settings.pressed.connect(_show_settings.bind(true))
	var quit := UiTheme.button("Çıkış")
	quit.pressed.connect(func(): get_tree().quit())
	for b in [_play, settings, quit]:
		_main_box.add_child(b)

	_settings_box = VBoxContainer.new()
	_settings_box.add_theme_constant_override("separation", 14)
	stack.add_child(_settings_box)
	var heading := UiTheme.label("Ayarlar", 44, UiTheme.GOLD_LIGHT, 800)
	heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_settings_box.add_child(heading)
	_sound_toggle = CheckButton.new()
	_sound_toggle.text = "Ses Açık"
	_sound_toggle.toggled.connect(func(on: bool):
		AudioManager.set_sound_enabled(on)
		AudioManager.play_sfx(&"ui_click"))
	_settings_box.add_child(_sound_toggle)
	_music_value = UiTheme.label("", 28)
	_music_slider = _slider(_music_value, "Müzik", func(v: float): AudioManager.set_music_volume(v / 100.0))
	_sfx_value = UiTheme.label("", 28)
	_sfx_slider = _slider(_sfx_value, "Efektler", func(v: float): AudioManager.set_sfx_volume(v / 100.0))
	var back := UiTheme.button("Geri")
	back.pressed.connect(_show_settings.bind(false))
	_settings_box.add_child(back)

	var footer := UiTheme.label("Hazine haritası elinde, kaptan! Üç batığın eserini bul ve 120 saniye dolmadan limana dön.", 30)
	footer.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	footer.position = Vector2(0.0, 990.0)
	footer.size = Vector2(1920.0, 50.0)
	add_child(footer)


func _slider(value_label: Label, caption: String, on_change: Callable) -> HSlider:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)
	var name_label := UiTheme.label(caption, 30)
	name_label.custom_minimum_size.x = 130.0
	row.add_child(name_label)
	var slider := HSlider.new()
	slider.min_value = 0.0
	slider.max_value = 100.0
	slider.step = 5.0
	slider.custom_minimum_size = Vector2(240.0, 32.0)
	slider.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	slider.focus_mode = Control.FOCUS_ALL
	slider.value_changed.connect(func(v: float):
		value_label.text = "%%%d" % int(v)
		on_change.call(v)
		# Kullanıcı değiştirirken yeni seviyeyi duyurmak için kısa önizleme sesi
		# (ayarlar açılırken kodla verilen değerlerde çalmaz).
		if slider.has_focus():
			AudioManager.play_sfx(&"ui_move"))
	row.add_child(slider)
	value_label.custom_minimum_size.x = 70.0
	row.add_child(value_label)
	_settings_box.add_child(row)
	return slider
