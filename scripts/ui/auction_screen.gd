class_name AuctionScreen
extends Control
## Liman açık artırması ekranı (yalnızca görünüm ve girdi; kurallar AuctionSession'da).
## Satıştaki eserin simgesi ve adı, mevcut teklif, kullanılan bekleme hakkı (x/2),
## beklemenin başarı ihtimali / olası yeni teklif / 0 altın riski, Kabul Et ve
## Bekle düğmeleri, satış sonucu bildirimi, üç eserin durum şeridi ve toplam altın.
## Bekleme ve eser geçişleri sırasında girdi kilitlenir (çift satış olmaz);
## otomatik satıştan sonra düğmeler ancak sıradaki eserde yeniden açılır.

signal auction_finished(session: AuctionSession)

const INTRO_TIME := 1.4
const WAIT_TIME := 1.2
const RESULT_TIME := 1.8
const DIFFICULTY := {&"compass": "kolay", &"crown": "orta", &"sapphire": "zor"}
const ICONS := {&"compass": HudIcon.Kind.COMPASS, &"crown": HudIcon.Kind.CROWN, &"sapphire": HudIcon.Kind.GEM}

var session: AuctionSession

var _busy := true
var _total_panel: PanelContainer
var _total_label: Label
var _strip: Dictionary = {}
var _card: PanelContainer
var _card_style: StyleBoxFlat
## "Alıcılar çekildi" görünümü: önceki teklifin üstü çizilir, altında kırmızı
## kayıp satırı, kartın üstünde eğik mühür; kart çerçevesi kırmızıya döner.
var _strike: ColorRect
var _lost_label: Label
var _stamp: PanelContainer
var _icon: HudIcon
var _name_label: Label
var _sub_label: Label
var _offer_label: Label
var _waits_label: Label
var _pips: Array[Panel] = []
var _risk_label: Label
var _accept: Button
var _wait: Button
var _message: Label


func _ready() -> void:
	theme = UiTheme.get_theme()
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_build()
	hide()


## Açık artırmayı açar: kısa bir "Limana vardın" girişinden sonra ilk eser satışa çıkar.
func open(new_session: AuctionSession) -> void:
	session = new_session
	session.item_started.connect(_on_item_started)
	session.offer_raised.connect(_on_offer_raised)
	session.sold.connect(_on_sold)
	session.buyers_left.connect(_on_buyers_left)
	session.finished.connect(_on_finished)
	AudioManager.play_music(&"music_auction")
	show()
	_set_busy(true)
	_card.modulate.a = 0.0
	_show_message("Limana vardın! Açık artırma başlıyor...", UiTheme.GOLD_LIGHT)
	_update_total()
	get_tree().create_timer(INTRO_TIME).timeout.connect(_begin)


func _begin() -> void:
	_card.modulate.a = 1.0
	session.start()


func _on_accept_pressed() -> void:
	if _busy or not session.can_accept():
		return
	session.accept()


func _on_wait_pressed() -> void:
	if _busy or not session.can_wait():
		return
	AudioManager.play_sfx(&"auction_waiting")
	_set_busy(true)
	_show_message("Teklifler bekleniyor...", UiTheme.CREAM)
	get_tree().create_timer(WAIT_TIME).timeout.connect(session.wait)


func _on_item_started(id: StringName, offer: int) -> void:
	var entry: Dictionary = GameManager.get_artifact(id)
	_icon.kind = ICONS[id]
	_name_label.text = entry["name"]
	_sub_label.text = "%s · Eser %d/%d" % [DIFFICULTY[id].capitalize(), session.index + 1, GameManager.ARTIFACTS.size()]
	_set_strip(id, "Satışta", UiTheme.GOLD_LIGHT)
	_set_lost_look(false)
	_show_offer(offer)
	_show_message("%s satışta! İlk teklif: %d altın" % [entry["name"], offer], UiTheme.CREAM)
	_set_busy(false)
	_accept.grab_focus()


func _on_offer_raised(_id: StringName, offer: int, _waits: int) -> void:
	AudioManager.play_sfx(&"auction_new_offer")
	_show_offer(offer)
	if session.can_wait():
		_show_message("Yeni teklif: %d altın!" % offer, UiTheme.GOLD_LIGHT)
		_set_busy(false)
		_accept.grab_focus()


func _on_sold(id: StringName, amount: int, automatic: bool) -> void:
	AudioManager.play_sfx(&"auction_sold")
	var text := "Son teklif otomatik kabul edildi! +%d altın" if automatic else "Satıldı! +%d altın"
	_show_message(text % amount, UiTheme.GOLD_LIGHT)
	_set_strip(id, "Satıldı: %d" % amount, UiTheme.GOLD_LIGHT)
	_finish_item()


func _on_buyers_left(id: StringName) -> void:
	AudioManager.play_sfx(&"auction_buyers_left")
	_show_message("Alıcılar çekildi! Bu eserden 0 altın.", UiTheme.WARN)
	_set_strip(id, "Satılamadı", UiTheme.WARN)
	_offer_label.text = "%d altın" % session.offer
	_lost_label.text = "0 altın kazanıldı · %d altınlık teklif kaybedildi" % session.offer
	_set_lost_look(true)
	_finish_item()


func _set_lost_look(lost: bool) -> void:
	_strike.visible = lost
	_lost_label.visible = lost
	_stamp.visible = lost
	_offer_label.add_theme_color_override("font_color", UiTheme.CREAM.darkened(0.45) if lost else UiTheme.GOLD_LIGHT)
	_icon.modulate = Color(0.55, 0.5, 0.6, 0.7) if lost else Color.WHITE
	_card_style.border_color = UiTheme.WARN if lost else UiTheme.GOLD
	_card_style.set_border_width_all(6 if lost else 4)
	if lost:
		_stamp.reset_size()
		_stamp.pivot_offset = _stamp.size * 0.5
		_stamp.position = _card.position + Vector2(_card.size.x - _stamp.size.x - 40.0, -_stamp.size.y * 0.45)


## Satış sonucu görünümü (testler için): üstü çizili teklif ve mühür görünüyor mu.
func is_showing_lost() -> bool:
	return _stamp.visible and _strike.visible and _lost_label.visible


func _on_finished(_total: int) -> void:
	auction_finished.emit(session)


func _finish_item() -> void:
	_set_busy(true)
	_update_total()
	_update_waits()
	get_tree().create_timer(RESULT_TIME).timeout.connect(session.next_item)


func _show_offer(offer: int) -> void:
	_offer_label.text = "%d altın" % offer
	_update_waits()


func _update_waits() -> void:
	var used := session.waits_used
	_waits_label.text = "Kullanılan bekleme hakkı: %d/%d" % [used, GameManager.MAX_WAITS]
	for i in _pips.size():
		_pips[i].modulate = UiTheme.GOLD_LIGHT if i < used else Color(1, 1, 1, 0.35)
	if session.can_wait():
		_risk_label.text = "Beklersen: %%%d ihtimalle teklif %d altına çıkar\n%%%d ihtimalle alıcılar çekilir ve bu eserden 0 altın kazanırsın" % [
			roundi(session.raise_chance() * 100.0), session.next_offer(), 100 - roundi(session.raise_chance() * 100.0)]
		_risk_label.add_theme_color_override("font_color", UiTheme.CREAM)
	elif session.phase == AuctionSession.Phase.OFFER:
		_risk_label.text = "Bekleme hakkı kalmadı."
		_risk_label.add_theme_color_override("font_color", UiTheme.CREAM.darkened(0.2))
	else:
		_risk_label.text = ""


func _update_total() -> void:
	_total_label.text = "Toplam: %d altın" % GameManager.gold
	_total_panel.reset_size()
	_total_panel.position = Vector2(1890.0 - _total_panel.size.x, 40.0)


func _set_busy(busy: bool) -> void:
	_busy = busy
	_accept.disabled = busy or not session.can_accept() if session else true
	_wait.disabled = busy or not session.can_wait() if session else true
	_wait.text = "Daha Yüksek Teklif Bekle" if session == null or session.can_wait() or session.phase != AuctionSession.Phase.OFFER else "Bekleme hakkı kalmadı"
	_update_accept_text()
	# Kapalı düğme odakta kalırsa altın odak çerçevesiyle açıkmış gibi görünür.
	if busy and (_accept.has_focus() or _wait.has_focus()):
		get_viewport().gui_release_focus()


func _update_accept_text() -> void:
	_accept.text = "Teklifi Kabul Et (%d)" % session.offer if session and session.can_accept() else "Teklifi Kabul Et"


func _show_message(text: String, color: Color) -> void:
	_message.text = text
	_message.add_theme_color_override("font_color", color)


func _set_strip(id: StringName, status: String, color: Color) -> void:
	var label: Label = _strip[id]
	label.text = status
	label.add_theme_color_override("font_color", color)


# --- Kurulum -------------------------------------------------------------------------

func _build() -> void:
	var shade := ColorRect.new()
	shade.color = Color(0.06, 0.04, 0.18, 0.62)
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(shade)

	var title := UiTheme.label("Liman Açık Artırması", 64, UiTheme.GOLD_LIGHT, 800)
	title.add_theme_constant_override("outline_size", 14)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.position = Vector2(0.0, 36.0)
	title.size = Vector2(1920.0, 90.0)
	add_child(title)

	_total_panel = PanelContainer.new()
	_total_panel.custom_minimum_size = Vector2(360.0, 86.0)
	add_child(_total_panel)
	var total_row := HBoxContainer.new()
	total_row.alignment = BoxContainer.ALIGNMENT_CENTER
	total_row.add_theme_constant_override("separation", 12)
	_total_panel.add_child(total_row)
	total_row.add_child(_make_icon(HudIcon.Kind.COINS, 58.0))
	_total_label = UiTheme.label("Toplam: 0 altın", 36)
	total_row.add_child(_total_label)

	var strip := HBoxContainer.new()
	strip.add_theme_constant_override("separation", 24)
	add_child(strip)
	for entry in GameManager.ARTIFACTS:
		var cell := PanelContainer.new()
		var cell_style := UiTheme.panel_style(16, 2)
		cell_style.set_content_margin_all(10)
		cell.add_theme_stylebox_override("panel", cell_style)
		strip.add_child(cell)
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 10)
		cell.add_child(row)
		row.add_child(_make_icon(ICONS[entry["id"]], 44.0))
		var col := VBoxContainer.new()
		col.add_theme_constant_override("separation", -8)
		row.add_child(col)
		col.add_child(UiTheme.label(entry["name"], 24))
		var status := UiTheme.label("Sırada", 22, UiTheme.CREAM.darkened(0.25))
		col.add_child(status)
		_strip[entry["id"]] = status
		cell.custom_minimum_size.x = 300.0
	strip.reset_size()
	strip.position = Vector2((1920.0 - strip.size.x) * 0.5, 150.0)

	_card = PanelContainer.new()
	_card_style = UiTheme.panel_style(28, 4)
	_card_style.set_content_margin_all(36)
	_card.add_theme_stylebox_override("panel", _card_style)
	_card.custom_minimum_size = Vector2(1240.0, 0.0)
	add_child(_card)
	var card_row := HBoxContainer.new()
	card_row.add_theme_constant_override("separation", 48)
	_card.add_child(card_row)

	var left := VBoxContainer.new()
	left.alignment = BoxContainer.ALIGNMENT_CENTER
	left.add_theme_constant_override("separation", 6)
	card_row.add_child(left)
	var slot := PanelContainer.new()
	var slot_style := UiTheme.panel_style(120, 5, UiTheme.INK.lerp(UiTheme.PANEL, 0.4))
	slot_style.set_content_margin_all(26)
	slot.add_theme_stylebox_override("panel", slot_style)
	slot.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	left.add_child(slot)
	_icon = _make_icon(HudIcon.Kind.COMPASS, 170.0)
	slot.add_child(_icon)
	_name_label = UiTheme.label("", 44, UiTheme.GOLD_LIGHT, 800)
	_name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	left.add_child(_name_label)
	_sub_label = UiTheme.label("", 26)
	_sub_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	left.add_child(_sub_label)

	var right := VBoxContainer.new()
	right.alignment = BoxContainer.ALIGNMENT_CENTER
	right.add_theme_constant_override("separation", 10)
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card_row.add_child(right)
	right.add_child(UiTheme.label("Mevcut Teklif", 30, UiTheme.CREAM.darkened(0.1)))
	var offer_row := HBoxContainer.new()
	offer_row.add_theme_constant_override("separation", 14)
	right.add_child(offer_row)
	offer_row.add_child(_make_icon(HudIcon.Kind.COINS, 76.0))
	_offer_label = UiTheme.label("", 76, UiTheme.GOLD_LIGHT, 800)
	offer_row.add_child(_offer_label)
	_strike = ColorRect.new()
	_strike.color = UiTheme.WARN
	_strike.anchor_left = 0.0
	_strike.anchor_right = 1.0
	_strike.anchor_top = 0.5
	_strike.anchor_bottom = 0.5
	_strike.offset_top = -4.0
	_strike.offset_bottom = 4.0
	_strike.offset_left = -6.0
	_strike.offset_right = 6.0
	_strike.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_strike.hide()
	_offer_label.add_child(_strike)
	_lost_label = UiTheme.label("", 30, UiTheme.WARN, 800)
	_lost_label.hide()
	right.add_child(_lost_label)
	var waits_row := HBoxContainer.new()
	waits_row.add_theme_constant_override("separation", 10)
	right.add_child(waits_row)
	_waits_label = UiTheme.label("", 30)
	waits_row.add_child(_waits_label)
	for i in GameManager.MAX_WAITS:
		var pip := Panel.new()
		var pip_style := StyleBoxFlat.new()
		pip_style.bg_color = Color.WHITE
		pip_style.set_corner_radius_all(11)
		pip.add_theme_stylebox_override("panel", pip_style)
		pip.custom_minimum_size = Vector2(22.0, 22.0)
		pip.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		waits_row.add_child(pip)
		_pips.append(pip)
	_risk_label = UiTheme.label("", 26)
	right.add_child(_risk_label)

	var buttons := HBoxContainer.new()
	buttons.add_theme_constant_override("separation", 30)
	add_child(buttons)
	_accept = UiTheme.button("Teklifi Kabul Et", 520.0)
	_accept.pressed.connect(_on_accept_pressed)
	_wait = UiTheme.button("Daha Yüksek Teklif Bekle", 520.0)
	_wait.pressed.connect(_on_wait_pressed)
	buttons.add_child(_accept)
	buttons.add_child(_wait)

	_message = UiTheme.label("", 40, UiTheme.CREAM, 800)
	_message.add_theme_constant_override("outline_size", 10)
	_message.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_message.position = Vector2(0.0, 965.0)
	_message.size = Vector2(1920.0, 60.0)
	add_child(_message)

	_card.reset_size()
	_card.position = Vector2((1920.0 - _card.size.x) * 0.5, 250.0)

	_stamp = PanelContainer.new()
	var stamp_style := StyleBoxFlat.new()
	stamp_style.bg_color = Color(0.55, 0.12, 0.1, 0.92)
	stamp_style.border_color = UiTheme.WARN
	stamp_style.set_border_width_all(4)
	stamp_style.set_corner_radius_all(10)
	stamp_style.content_margin_left = 22
	stamp_style.content_margin_right = 22
	stamp_style.content_margin_top = 6
	stamp_style.content_margin_bottom = 6
	_stamp.add_theme_stylebox_override("panel", stamp_style)
	_stamp.rotation = -0.12
	_stamp.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_stamp.add_child(UiTheme.label("ALICILAR ÇEKİLDİ", 40, UiTheme.CREAM, 800))
	_stamp.hide()
	add_child(_stamp)
	buttons.reset_size()
	buttons.position = Vector2((1920.0 - buttons.size.x) * 0.5, 850.0)
	_accept.disabled = true
	_wait.disabled = true


static func _make_icon(kind: HudIcon.Kind, edge: float) -> HudIcon:
	var icon := HudIcon.new()
	icon.kind = kind
	icon.custom_minimum_size = Vector2(edge, edge)
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return icon
