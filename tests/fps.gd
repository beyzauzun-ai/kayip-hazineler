extends SceneTree
## 9. aşama performans: ses açıkken HUD, harita ve açık artırma ekranlarında 15'er sn FPS.

var scene: Node
var gm: Node
var am: Node
var phase := -1
var frames := 0
var t0 := 0
var names := ["HUD (müzik + ortam + gemi suyu)", "HUD + hazine haritası", "açık artırma ekranı (açık artırma müziği)"]


func _initialize() -> void:
	scene = (load("res://scenes/sea_level.tscn") as PackedScene).instantiate()
	root.add_child(scene)
	current_scene = scene
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)


func _process(_delta: float) -> bool:
	frames += 1
	if phase == -1:
		if frames == 5:
			gm = root.get_node("GameManager")
			am = root.get_node("AudioManager")
			scene.start_game()
			Input.action_press(&"ship_forward")
			Input.action_press(&"ship_left")
			phase = 0
			frames = 0
		return false
	gm.time_left = 999.0 if gm.is_sailing() else gm.time_left
	if frames == 60:
		t0 = Time.get_ticks_msec()
	if frames < 60 + 900:
		return false
	var fps := 900.0 / ((Time.get_ticks_msec() - t0) / 1000.0)
	print("%-44s FPS: %.1f  çizim çağrısı: %d  çalan efekt: %d  müzik: %s" % [names[phase], fps,
		RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME), am.active_sfx_count(), am.current_music()])
	phase += 1
	frames = 0
	match phase:
		1:
			scene.get_node("Arayuz/HazineHaritasi").toggle()
		2:
			scene.get_node("Arayuz/HazineHaritasi").close()
			Input.action_release(&"ship_forward")
			Input.action_release(&"ship_left")
			for a in [&"compass", &"crown", &"sapphire"]:
				gm.collect_artifact(a)
			gm.time_left = 60.0
			gm.try_finish_at_port()
		_:
			return true
	return false
