extends SceneTree
## Normal oyunun 120 sn geri sayımı (yaklaşık 2 dk sürer). Sayaca hiç dokunulmaz;
## görev ana menüdeki "Oyna" düğmesinin sinyaliyle başlar ve gerçek zamanlı akar.
## Denetlenenler: menüde 120 sn ve HUD gizli; başlangıçta HUD 02:00; 60/20/10/1
## sn noktalarında gerçek geçen süre; son 20 sn'de uyarı sesi (1 kez) ve HUD
## uyarı rengi, son 10 sn'de 10 tık; 00:00'da görev sonu (sonuç durumu, gemi
## kontrolü kapalı, "Süre doldu" ekranı, kayıp sesi). Gerçek saat toleransı ±0,5 sn.

var scene: Node
var gm: Node
var am: Node
var hud: Control
var frame := 0
var started_ms := 0
var marks := {}
var sounds := []
var done := false
var errors := 0
var end_frames := 0
var max_delta := 0.0
var slow_frames := 0
var warn_before_20 := false
var warn_after_20 := false


func _initialize() -> void:
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED)
	scene = (load("res://scenes/sea_level.tscn") as PackedScene).instantiate()
	root.add_child(scene)
	current_scene = scene


func _check(label: String, ok: bool) -> void:
	if not ok:
		errors += 1
	print(("  [OK]   " if ok else "  [HATA] ") + label)


func _process(d: float) -> bool:
	frame += 1
	if started_ms > 0 and not done:
		max_delta = maxf(max_delta, d)
		if d > 0.1:
			slow_frames += 1
	if frame == 5:
		gm = root.get_node("GameManager")
		am = root.get_node("AudioManager")
		hud = scene.get_node("Arayuz/HUD")
		am.sfx_requested.connect(func(n): sounds.append(n))
		_check("menüde durum MENU, sayaç %.1f sn, HUD gizli" % gm.time_left, gm.state == 0 and gm.time_left == 120.0 and not hud.visible)
		# Ana menüdeki "Oyna" düğmesinin yaptığı çağrı.
		scene.get_node("Arayuz/AnaMenu").play_requested.emit()
		started_ms = Time.get_ticks_msec()
		return false
	if done:
		end_frames += 1
		if end_frames < 3:
			return false
		_finish()
		return true
	if frame < 7:
		return false
	var label: String = hud._time_label.text
	var real := (Time.get_ticks_msec() - started_ms) / 1000.0
	var warning: bool = hud._time_label.has_meta(&"warning")
	if gm.time_left > 20.5 and warning:
		warn_before_20 = true
	if gm.time_left < 19.5 and gm.time_left > 0.0 and warning:
		warn_after_20 = true
	if not marks.has("start"):
		marks["start"] = [label, gm.time_left, real]
		_check("görev başında HUD '%s', sayaç %.2f sn" % [label, gm.time_left], label == "02:00" and gm.time_left > 119.0)
	for sec in [60, 20, 10, 1]:
		var key := "s%d" % sec
		if not marks.has(key) and gm.time_left <= sec:
			marks[key] = [label, gm.time_left, real]
			_check("sayaç %d sn: HUD '%s', gerçek geçen %.2f sn (beklenen %d ± 0,5)" % [sec, label, real, 120 - sec], absf(real - (120 - sec)) <= 0.5)
	if gm.state != 1 and not marks.has("end"):
		marks["end"] = [label, gm.time_left, real]
		done = true
	return false


func _finish() -> void:
	var real: float = marks["end"][2]
	var end_label: String = hud._time_label.text
	print("  süre doldu: gerçek geçen %.2f sn; en uzun kare %.3f sn, 0,1 sn'den uzun kare %d" % [real, max_delta, slow_frames])
	_check("20 sn öncesinde HUD uyarı renginde değil, son 20 sn'de uyarı renginde", not warn_before_20 and warn_after_20)
	_check("20 sn uyarı sesi tam 1 kez (%d), son 10 sn'de 10 tık (%d)" % [sounds.count(&"timer_warning"), sounds.count(&"timer_tick")], sounds.count(&"timer_warning") == 1 and sounds.count(&"timer_tick") == 10)
	_check("bitişte sayaç 0, HUD '%s'" % end_label, gm.time_left == 0.0 and end_label == "00:00")
	_check("toplam süre gerçek saatle 120 sn (%.2f; ±0,5)" % real, absf(real - 120.0) <= 0.5)
	_check("durum RESULT (%d), gemi kontrolü kapalı" % gm.state, gm.state == 3 and not scene.get_node("Gemi").controls_enabled)
	_check("'Süre doldu' sonuç ekranı açık ve görev kaybı sesi çaldı", scene.get_node("Arayuz/GorevSonucu").visible and &"mission_lose" in sounds)
	print("SONUÇ: hata sayısı = %d" % errors)
