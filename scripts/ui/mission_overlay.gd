class_name MissionOverlay
extends Control
## Görev sonuç ekranı.
## Açık artırma bitince: üç eserin satış sonuçları, toplam altın ve korsan rütbesi.
## Deniz görevi başarısızsa: "Süre doldu!" ve toplanan eser sayısı (açık artırma yok).
## Seçenekler: Yeniden Başlat, Ana Menü.

signal restart_requested
signal menu_requested

var _panel: PanelContainer
var _title: Label
var _body: Label
var _rows: VBoxContainer
var _rank: Label
var _note: Label
var _first_button: Button


func _ready() -> void:
	theme = UiTheme.get_theme()
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_build()
	hide()


func show_auction_results(session: AuctionSession) -> void:
	for child in _rows.get_children():
		child.queue_free()
	for r in session.results:
		var entry: Dictionary = GameManager.get_artifact(r["id"])
		var waits := "bekleme yok" if r["waits"] == 0 else "%d bekleme" % r["waits"]
		var text: String
		if r["amount"] > 0:
			text = "%s — Satıldı: %d altın (%s%s)" % [entry["name"], r["amount"], waits, ", otomatik" if r["automatic"] else ""]
		else:
			text = "%s — Alıcılar çekildi: 0 altın (%s)" % [entry["name"], waits]
		var row := UiTheme.label(text, 30, UiTheme.CREAM if r["amount"] > 0 else UiTheme.WARN)
		row.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_rows.add_child(row)
	_rows.show()
	_rank.text = "Rütbe: %s" % GameManager.get_title()
	_rank.show()
	_open("Açık Artırma Tamamlandı!", "Toplam: %d altın" % GameManager.gold, "", UiTheme.GOLD_LIGHT)


func show_lost() -> void:
	_rows.hide()
	_rank.hide()
	_open("Süre doldu!",
		"Limana zamanında dönülemedi. Eserler: %d/%d" % [GameManager.collected.size(), GameManager.ARTIFACTS.size()],
		"Açık artırmaya yalnızca üç eserle zamanında dönünce çıkılır.", UiTheme.WARN)


func _open(title: String, body: String, note: String, color: Color) -> void:
	_title.text = title
	_title.add_theme_color_override("font_color", color)
	_body.text = body
	_note.text = note
	_note.visible = note != ""
	show()
	_panel.reset_size()
	_panel.position = (Vector2(1920.0, 1080.0) - _panel.size) * 0.5
	_first_button.grab_focus()


func _build() -> void:
	var shade := ColorRect.new()
	shade.color = Color(0.06, 0.04, 0.18, 0.5)
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(shade)
	_panel = PanelContainer.new()
	var style := UiTheme.panel_style(26, 4)
	style.set_content_margin_all(40)
	_panel.add_theme_stylebox_override("panel", style)
	_panel.custom_minimum_size.x = 980.0
	add_child(_panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 16)
	_panel.add_child(box)
	_title = UiTheme.label("", 64, UiTheme.GOLD_LIGHT, 800)
	_rows = VBoxContainer.new()
	_rows.add_theme_constant_override("separation", 4)
	_body = UiTheme.label("", 40, UiTheme.GOLD_LIGHT)
	_rank = UiTheme.label("", 52, UiTheme.GOLD_LIGHT, 800)
	_rank.add_theme_constant_override("outline_size", 12)
	_note = UiTheme.label("", 24, UiTheme.CREAM.darkened(0.15))
	for l in [_title, _rows, _body, _rank, _note]:
		if l is Label:
			l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		box.add_child(l)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 24)
	box.add_child(row)
	_first_button = UiTheme.button("Yeniden Başlat", 340.0)
	_first_button.pressed.connect(func(): restart_requested.emit())
	var menu := UiTheme.button("Ana Menü", 340.0)
	menu.pressed.connect(func(): menu_requested.emit())
	row.add_child(_first_button)
	row.add_child(menu)
