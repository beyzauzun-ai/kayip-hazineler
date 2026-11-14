extends SceneTree
## Hazine çıkarma süresi: her batıkta 2 tur. Oyunun kendi zamanlayıcısı (kare
## delta toplamı; batığın ilerlemesiyle aynı) ve gerçek saat (Time.get_ticks_usec)
## ayrı ölçülür ve ayrı denetlenir. Ölçüm sırasında ekran görüntüsü alınmaz.
## - Oyun zamanlayıcısı: 3 sn'ye, en fazla bir kare fazlasıyla ulaşmalı.
## - Gerçek saat: oyun zamanlayıcısından en fazla 0,1 sn sapmalı (düşük FPS'te
##   oyun yine 3 sn sayar; gerçek saat sapması bilgisayarın yavaşladığını gösterir).

const EXTRACT_TIME := 3.0
const CASES := [
	["MercanKoyu", Vector3(-35.8, 0, -1.2), 30.0],
	["SisliGecit", Vector3(6.6, 0, -1.6), -60.0],
	["DerinMavi", Vector3(42.0, 0, -25.5), -90.0],
]

var scene: Node
var gm: Node
var ship
var frame := 0
var round_i := 0
var case_i := 0
var state := 0
var wait := 0.0
var game_t := 0.0
var max_delta := 0.0
var frames := 0
var wall0 := 0
var extracted := 0
var errors := 0
var results := []


func _initialize() -> void:
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	scene = (load("res://scenes/sea_level.tscn") as PackedScene).instantiate()
	root.add_child(scene)
	current_scene = scene


func _on_extracted(_w) -> void:
	extracted += 1


func _process(delta: float) -> bool:
	frame += 1
	if frame == 3:
		gm = root.get_node("GameManager")
		ship = scene.get_node("Gemi")
		scene.start_game()
		for w in scene.get_node("Batiklar").get_children():
			w.extracted.connect(_on_extracted)
		_begin()
	if frame <= 3:
		return false
	gm.time_left = 999.0
	var c: Array = CASES[case_i]
	var w = scene.get_node("Batiklar/" + c[0])
	match state:
		0:
			wait += delta
			if wait > 0.6:
				Input.action_press(&"extract")
				state = 1
		1:
			if extracted == 0 and w.progress > 0.0 and wall0 == 0:
				# İlk ilerleme karesi: batığın ilerlemesi bu karenin delta'sıyla başlar.
				wall0 = Time.get_ticks_usec()
				game_t = w.progress
				max_delta = w.progress
				frames = 1
			elif wall0 != 0 and extracted == 0:
				game_t += delta
				max_delta = maxf(max_delta, delta)
				frames += 1
			if extracted > 0:
				var wall := (Time.get_ticks_usec() - wall0) / 1e6
				results.append([c[0], round_i + 1, game_t, wall, frames, frames / maxf(wall, 0.001), max_delta, extracted])
				Input.action_release(&"extract")
				case_i += 1
				if case_i >= CASES.size():
					case_i = 0
					round_i += 1
					if round_i >= 2:
						_report()
						return true
					gm.reset()
					gm.start_mission()
				_begin()
	return false


func _begin() -> void:
	var c: Array = CASES[case_i]
	ship.reset_to(Transform3D(Basis(Vector3.UP, deg_to_rad(c[2])), c[1]))
	state = 0
	wait = 0.0
	wall0 = 0
	extracted = 0


func _report() -> void:
	print("Batık         tur  oyun zamanlayıcısı  gerçek saat  kare  FPS")
	for r in results:
		print("%-12s  %d    %.3f sn           %.3f sn     %d   %.0f" % [r[0], r[1], r[2], r[3], r[4], r[5]])
	for r in results:
		var label := "%s tur %d" % [r[0], r[1]]
		_check("%s: eser tam 1 kez verildi (%d)" % [label, r[7]], r[7] == 1)
		_check("%s: oyun zamanlayıcısı %.3f sn (3,000 – %.3f)" % [label, r[2], EXTRACT_TIME + r[6] + 0.001], r[2] >= EXTRACT_TIME and r[2] <= EXTRACT_TIME + r[6] + 0.001)
		_check("%s: gerçek saat %.3f sn, oyun zamanlayıcısından sapma %.3f sn (≤ 0,1)" % [label, r[3], absf(r[3] - r[2])], absf(r[3] - r[2]) <= 0.1)
	print("SONUÇ: hata sayısı = %d" % errors)


func _check(label: String, ok: bool) -> void:
	if not ok:
		errors += 1
	print(("  [OK]   " if ok else "  [HATA] ") + label)
