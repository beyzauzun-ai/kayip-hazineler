extends SceneTree
## Hazine haritası performansı: harita açıkken (gemi fps.gd'deki gibi dönerek
## ilerlerken) 5 ayrı ölçüm, her biri 15 sn. Her ölçüm için FPS, ortalama ve en
## uzun kare süresi; sonunda ortalama ve en düşük FPS. 100 FPS hedefinin altında
## kalan ölçümler "[HEDEF ALTI]" olarak yazılır ve SONUÇ satırında ayrıca sayılır
## (açık takip maddesi; regresyon hatası sayılmaz). Bilgisayar prizde olmalıdır.

const TARGET := 100.0
const RUNS := 5
const SECONDS := 15.0

var scene: Node
var gm: Node
var map: Control
var frame := 0
var run := -1
var t := 0.0
var frames := 0
var max_dt := 0.0
var results := []


func _initialize() -> void:
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	scene = (load("res://scenes/sea_level.tscn") as PackedScene).instantiate()
	root.add_child(scene)
	current_scene = scene


func _process(delta: float) -> bool:
	frame += 1
	if frame == 5:
		gm = root.get_node("GameManager")
		map = scene.get_node("Arayuz/HazineHaritasi")
		scene.start_game()
		Input.action_press(&"ship_forward")
		Input.action_press(&"ship_left")
		map.toggle()
		run = 0
	if run < 0:
		return false
	gm.time_left = 999.0
	t += delta
	# Her ölçümden önce 1 sn ısınma.
	if t < 1.0:
		return false
	frames += 1
	max_dt = maxf(max_dt, delta)
	if t < 1.0 + SECONDS:
		return false
	var fps := frames / (t - 1.0)
	results.append([fps, 1000.0 / fps, max_dt * 1000.0, RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME)])
	t = 0.0
	frames = 0
	max_dt = 0.0
	run += 1
	if run < RUNS:
		return false
	Input.action_release(&"ship_forward")
	Input.action_release(&"ship_left")
	var below := 0
	var sum := 0.0
	var low := INF
	for i in results.size():
		var r: Array = results[i]
		sum += r[0]
		low = minf(low, r[0])
		var ok: bool = r[0] >= TARGET
		if not ok:
			below += 1
		print("  %s ölçüm %d: FPS %.1f, ortalama kare %.2f ms, en uzun kare %.1f ms, çizim çağrısı %d" % ["[OK]        " if ok else "[HEDEF ALTI]", i + 1, r[0], r[1], r[2], r[3]])
	print("Harita açık: ortalama FPS %.1f, en düşük %.1f (hedef ≥ %.0f)" % [sum / results.size(), low, TARGET])
	print("SONUÇ: hata sayısı = 0; hedef altında kalan ölçüm = %d/%d" % [below, RUNS])
	return true
