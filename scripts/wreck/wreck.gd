@tool
class_name Wreck
extends Node3D
## Su altındaki batık: eskimiş ahşap gemi silueti, keşif göstergeleri ve E ile
## 3 saniyelik hazine çıkarma.
## Göstergeler gemi yaklaştıkça belirginleşir: parıltı ve kabarcıklar her
## batıkta vardır; Mercan Koyu'nda altın halka, Derin Mavi'de safir ışıltı,
## Sisli Geçit'te yoğun altın parıltı ve kabarcık öne çıkar.

signal discovered(wreck: Wreck)
signal extraction_progress(wreck: Wreck, ratio: float)
signal extraction_failed(wreck: Wreck, reason: String)
signal extracted(wreck: Wreck)
signal hint(wreck: Wreck, text: String)

enum Style { CORAL, MIST, DEEP }

const EXTRACT_TIME := 3.0
## Bu hızın altındaki gemi "durmuş" sayılır.
const STOP_SPEED := 0.4
## Keşfedilen batık uzaktan da en az bu kadar belirgin kalır.
const DISCOVERED_REVEAL := 0.45
const GOLD := Color("#FFD45A")
const SAPPHIRE := Color("#6FA8FF")

@export var wreck_id: StringName
@export var artifact_id: StringName
@export var style := Style.MIST
@export var discover_radius := 12.0
@export var extract_radius := 5.0
## Göstergeler bu uzaklıktan itibaren belirmeye başlar.
@export var reveal_distance := 20.0
@export var decoration_seed := 1
@export_tool_button("Yeniden Oluştur", "Reload") var rebuild_action: Callable = rebuild

## 0 = neredeyse görünmez, 1 = tam belirgin.
var reveal := 0.0
## Basılı tutulan süre (sn); 0 = çıkarma yapılmıyor.
var progress := 0.0

var _ship: Ship
var _time := 0.0
var _model_material: ShaderMaterial
var _sparkles: CPUParticles3D
var _bubbles: CPUParticles3D
var _sparkle_material: StandardMaterial3D
var _bubble_material: StandardMaterial3D
var _accent: MeshInstance3D
var _accent_material: StandardMaterial3D

static var _dot_texture: Texture2D
static var _bubble_texture: Texture2D


func _ready() -> void:
	rebuild()
	if Engine.is_editor_hint():
		reveal = 0.8
		_apply_reveal()
		return
	_ship = get_tree().get_first_node_in_group(&"player_ship") as Ship


func is_discovered() -> bool:
	return wreck_id in GameManager.discovered


func is_looted() -> bool:
	return artifact_id in GameManager.collected


func wreck_name() -> String:
	return GameManager.get_artifact(artifact_id).get("wreck_name", "")


func artifact_name() -> String:
	return GameManager.get_artifact(artifact_id).get("name", "")


func _physics_process(delta: float) -> void:
	if Engine.is_editor_hint() or _ship == null:
		return
	var dist := _distance_to_ship()
	if dist <= discover_radius and not is_discovered() and GameManager.discover_wreck(wreck_id):
		AudioManager.play_sfx(&"discovery_bell")
		discovered.emit(self)
	_update_extraction(dist, delta)


func _process(delta: float) -> void:
	_time += delta
	if Engine.is_editor_hint():
		return
	var target := 0.0
	if _ship:
		target = 1.0 - smoothstep(extract_radius, reveal_distance, _distance_to_ship())
	if is_discovered():
		target = maxf(target, DISCOVERED_REVEAL)
	reveal = move_toward(reveal, target, delta * 1.5)
	_apply_reveal()
	if _accent and style == Style.CORAL:
		_accent.rotation.y = _time * 0.8
		_accent.position.y = 2.4 + sin(_time * 2.0) * 0.15


func _update_extraction(dist: float, delta: float) -> void:
	var pressed := Input.is_action_pressed(&"extract")
	var in_range := dist <= extract_radius
	var stopped := absf(_ship.speed) < STOP_SPEED
	if progress > 0.0:
		if not GameManager.is_sailing():
			_cancel()
		elif not pressed:
			_fail("E erken bırakıldı")
		elif not in_range:
			_fail("batıktan uzaklaştın")
		elif not stopped:
			_fail("gemi hareket etti")
		else:
			progress += delta
			extraction_progress.emit(self, minf(progress / EXTRACT_TIME, 1.0))
			if progress >= EXTRACT_TIME:
				_complete()
		return
	if not pressed or dist > discover_radius or not GameManager.is_sailing():
		return
	if is_looted():
		if Input.is_action_just_pressed(&"extract"):
			hint.emit(self, "Bu batığın hazinesi zaten alındı.")
	elif not in_range:
		if Input.is_action_just_pressed(&"extract"):
			hint.emit(self, "Batığa daha çok yaklaş!")
	elif not stopped:
		if Input.is_action_just_pressed(&"extract"):
			hint.emit(self, "Önce gemiyi durdur!")
	else:
		progress = delta
		AudioManager.play_sfx(&"extract_loop")
		extraction_progress.emit(self, progress / EXTRACT_TIME)


func _fail(reason: String) -> void:
	progress = 0.0
	AudioManager.stop_sfx(&"extract_loop")
	AudioManager.play_sfx(&"extract_fail")
	extraction_failed.emit(self, reason)


func _cancel() -> void:
	progress = 0.0
	AudioManager.stop_sfx(&"extract_loop")
	extraction_progress.emit(self, 0.0)


func _complete() -> void:
	progress = 0.0
	AudioManager.stop_sfx(&"extract_loop")
	if GameManager.collect_artifact(artifact_id):
		AudioManager.play_sfx(&"treasure_success")
		_burst()
		extracted.emit(self)


func _distance_to_ship() -> float:
	var d := _ship.global_position - global_position
	return Vector2(d.x, d.z).length()


func _apply_reveal() -> void:
	if _model_material == null:
		return
	var looted := not Engine.is_editor_hint() and is_looted()
	_model_material.set_shader_parameter("reveal", minf(reveal, 0.55) if looted else reveal)
	var effect := 0.0 if looted else lerpf(0.12, 1.0, reveal)
	_set_alpha(_sparkle_material, effect)
	_set_alpha(_bubble_material, effect * 0.9)
	_sparkles.emitting = not looted
	_bubbles.emitting = not looted
	if _accent_material:
		var pulse := 0.85 + 0.15 * sin(_time * 3.0)
		_set_alpha(_accent_material, effect * pulse * (0.9 if style == Style.CORAL else 0.6))


static func _set_alpha(material: StandardMaterial3D, alpha: float) -> void:
	var c := material.albedo_color
	c.a = alpha
	material.albedo_color = c


# --- Görsel kurulum --------------------------------------------------------------

func rebuild() -> void:
	PropLibrary.clear_generated(self)
	var rng := RandomNumberGenerator.new()
	rng.seed = decoration_seed
	_model_material = ShaderMaterial.new()
	_model_material.shader = load("res://shaders/wreck.gdshader")
	_model_material.render_priority = 1
	var model := PropLibrary.add_mesh(self, "_Model", _build_model(rng).commit(_model_material), false)
	model.rotation.z = 0.22

	var accent_color := SAPPHIRE if style == Style.DEEP else GOLD
	var sparkle_count: int = {Style.CORAL: 12, Style.MIST: 28, Style.DEEP: 16}[style]
	var bubble_count: int = {Style.CORAL: 6, Style.MIST: 18, Style.DEEP: 7}[style]
	_sparkle_material = _particle_material(_dot(), true)
	_sparkles = _particles("_Parilti", _sparkle_material, sparkle_count, accent_color, 0.9)
	_sparkles.emission_box_extents = Vector3(1.8, 0.4, 3.0)
	_sparkles.position.y = 0.3
	_sparkles.lifetime = 1.6
	_sparkles.initial_velocity_min = 0.3
	_sparkles.initial_velocity_max = 0.9
	_bubble_material = _particle_material(_bubble(), false)
	_bubbles = _particles("_Kabarcik", _bubble_material, bubble_count, Color(0.85, 0.97, 1.0), 0.5)
	_bubbles.emission_box_extents = Vector3(1.0, 0.2, 2.2)
	_bubbles.position.y = -0.6
	_bubbles.lifetime = 2.4
	_bubbles.initial_velocity_min = 0.8
	_bubbles.initial_velocity_max = 1.4

	_accent = null
	_accent_material = null
	if style == Style.CORAL:
		var torus := TorusMesh.new()
		torus.inner_radius = 1.45
		torus.outer_radius = 1.75
		torus.rings = 32
		torus.ring_segments = 8
		_accent_material = _glow_material(null, GOLD, false)
		_accent = PropLibrary.add_mesh(self, "_Halka", torus, false)
		_accent.material_override = _accent_material
		_accent.position.y = 2.4
	elif style == Style.DEEP:
		var plane := PlaneMesh.new()
		plane.size = Vector2(10.0, 10.0)
		_accent_material = _glow_material(_dot(), SAPPHIRE, true)
		_accent = PropLibrary.add_mesh(self, "_Isilti", plane, false)
		_accent.material_override = _accent_material
		_accent.position.y = 0.05
	_apply_reveal()


func _build_model(rng: RandomNumberGenerator) -> MeshBatcher:
	# Referanstaki sıcak, eskimiş kahverengi ahşap; Derin Mavi hafif mavimsi kalır.
	var wood: Color = {Style.CORAL: Color("#A8703F"), Style.MIST: Color("#9A6438"), Style.DEEP: Color("#7E6A74")}[style]
	var dark := wood.darkened(0.32)
	var moss := Color("#6F8A5E") if style != Style.DEEP else Color("#5A6F8A")
	var gold := Color("#E8B04A")
	var b := MeshBatcher.new()
	var sphere := PropLibrary.sphere()
	var cylinder := PropLibrary.cylinder()
	b.add(sphere, Transform3D(Basis.from_scale(Vector3(3.0, 1.5, 6.4)), Vector3(0.0, -1.0, 0.0)), wood, 0.35)
	# Gövde kenarında altın süs şeritleri ve lombozlar.
	for side in [-1.0, 1.0]:
		b.add(PropLibrary.box(), Transform3D(Basis(Vector3.UP, side * 0.06) * Basis.from_scale(Vector3(0.1, 0.1, 4.6)), Vector3(side * 1.36, -0.32, 0.1)), gold)
		for z in [-1.4, 0.0, 1.4]:
			b.add(sphere, Transform3D(Basis.from_scale(Vector3.ONE * 0.26), Vector3(side * 1.42, -0.62, z)), gold.darkened(0.15))
	# Yarı görünen hazine sandığı: ahşap gövde, altın bant, aralık kapaktan sızan ışık.
	var chest := Vector3(0.35, -0.38, 0.9)
	b.add(PropLibrary.box(), Transform3D(Basis(Vector3.UP, 0.4) * Basis.from_scale(Vector3(1.0, 0.6, 0.7)), chest), Color("#7A4A26"))
	b.add(PropLibrary.box(), Transform3D(Basis(Vector3.UP, 0.4) * Basis.from_scale(Vector3(1.04, 0.12, 0.74)), chest + Vector3(0.0, 0.12, 0.0)), gold)
	b.add(PropLibrary.box(), Transform3D(Basis(Vector3.UP, 0.4) * Basis(Vector3.RIGHT, -0.35) * Basis.from_scale(Vector3(1.0, 0.14, 0.7)), chest + Vector3(0.0, 0.42, -0.12)), Color("#8A5530"))
	b.add(PropLibrary.box(), Transform3D(Basis(Vector3.UP, 0.4) * Basis.from_scale(Vector3(0.86, 0.08, 0.5)), chest + Vector3(0.0, 0.33, 0.02)), Color(1.0, 0.82, 0.35, 0.0))
	b.add(sphere, Transform3D(Basis.from_scale(Vector3(2.3, 0.24, 5.2)), Vector3(0.0, -0.35, 0.2)), dark)
	b.add(sphere, Transform3D(Basis.from_scale(Vector3(1.6, 1.0, 2.2)), Vector3(0.0, -0.55, -2.4)), wood)
	for z in [-1.8, -0.6, 0.6, 1.8]:
		var rib := Basis(Vector3.BACK, PI * 0.5) * Basis(Vector3.RIGHT, rng.randf_range(-0.15, 0.15))
		b.add(cylinder, Transform3D(rib * Basis.from_scale(Vector3(0.1, 2.9, 0.1)), Vector3(0.0, -0.35, z)), wood.lightened(0.1))
	for i in 3:
		var tilt := Basis(Vector3.UP, rng.randf_range(0.0, TAU)) * Basis(Vector3.RIGHT, rng.randf_range(0.3, 0.7))
		b.add(PropLibrary.box(), Transform3D(tilt * Basis.from_scale(Vector3(0.28, 0.08, 1.5)), Vector3(rng.randf_range(-0.7, 0.7), -0.2, rng.randf_range(-1.5, 1.5))), wood.lightened(0.15))
	var mast_dir := Vector3(0.55, 1.0, -0.2).normalized()
	var mast_base := Vector3(0.0, -0.5, -0.8)
	b.add(cylinder, Transform3D(Basis(Quaternion(Vector3.UP, mast_dir)) * Basis.from_scale(Vector3(0.14, 3.2, 0.14)), mast_base + mast_dir * 1.6), dark)
	b.add(sphere, Transform3D(Basis(Quaternion(Vector3.UP, mast_dir)) * Basis.from_scale(Vector3(1.2, 0.9, 0.12)), mast_base + mast_dir * 2.5 + Vector3(0.0, 0.0, 0.25)), Color("#B9B2A0"))
	b.add(cylinder, Transform3D(Basis.from_scale(Vector3(0.15, 1.6, 0.15)), Vector3(0.1, 0.1, 1.3)), dark)
	b.add(cylinder, Transform3D(Basis(Vector3.BACK, PI * 0.5) * Basis.from_scale(Vector3(0.07, 1.6, 0.07)), Vector3(0.1, 0.75, 1.3)), dark)
	for i in 5:
		var pos := Vector3(rng.randf_range(-1.2, 1.2), -0.45, rng.randf_range(-2.6, 2.6))
		b.add(sphere, Transform3D(Basis.from_scale(Vector3(0.6, 0.25, 0.8) * rng.randf_range(0.7, 1.2)), pos), moss)
	if style == Style.CORAL:
		for i in 4:
			PropLibrary.add_coral(b, Vector3(rng.randf_range(-1.2, 1.2), -0.7, rng.randf_range(-2.4, 2.4)), 0.55, rng)
	return b


func _particles(node_name: String, material: StandardMaterial3D, count: int, color: Color, size: float) -> CPUParticles3D:
	var quad := QuadMesh.new()
	quad.size = Vector2(size, size)
	quad.material = material
	var p := CPUParticles3D.new()
	p.name = node_name
	p.set_meta(&"generated", true)
	p.mesh = quad
	p.amount = count
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	p.direction = Vector3.UP
	p.spread = 25.0
	p.gravity = Vector3.ZERO
	p.scale_amount_min = 0.6
	p.scale_amount_max = 1.4
	p.color = color
	var ramp := Gradient.new()
	ramp.set_color(0, Color(1, 1, 1, 0))
	ramp.set_color(1, Color(1, 1, 1, 0))
	ramp.add_point(0.3, Color.WHITE)
	ramp.add_point(0.7, Color.WHITE)
	p.color_ramp = ramp
	add_child(p)
	return p


static func _particle_material(texture: Texture2D, additive: bool) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD if additive else BaseMaterial3D.BLEND_MODE_MIX
	m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	m.vertex_color_use_as_albedo = true
	m.albedo_texture = texture
	m.render_priority = 2
	m.no_depth_test = false
	return m


static func _glow_material(texture: Texture2D, color: Color, additive: bool) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD if additive else BaseMaterial3D.BLEND_MODE_MIX
	m.albedo_color = color
	m.albedo_texture = texture
	m.render_priority = 2
	return m


## Yumuşak kenarlı parlak nokta (parıltı ve ışıltı için).
static func _dot() -> Texture2D:
	if _dot_texture == null:
		var g := Gradient.new()
		g.set_color(0, Color.WHITE)
		g.set_color(1, Color(1, 1, 1, 0))
		g.add_point(0.25, Color(1, 1, 1, 0.9))
		_dot_texture = _radial(g)
	return _dot_texture


## Ortası saydam, kenarı parlak halka (kabarcık için).
static func _bubble() -> Texture2D:
	if _bubble_texture == null:
		var g := Gradient.new()
		g.set_color(0, Color(1, 1, 1, 0.15))
		g.set_color(1, Color(1, 1, 1, 0))
		g.add_point(0.7, Color(1, 1, 1, 0.35))
		g.add_point(0.85, Color(1, 1, 1, 1.0))
		_bubble_texture = _radial(g)
	return _bubble_texture


static func _radial(g: Gradient) -> Texture2D:
	var t := GradientTexture2D.new()
	t.gradient = g
	t.fill = GradientTexture2D.FILL_RADIAL
	t.fill_from = Vector2(0.5, 0.5)
	t.fill_to = Vector2(1.0, 0.5)
	t.width = 64
	t.height = 64
	return t


func _burst() -> void:
	var p := _particles("_Patlama", _particle_material(_dot(), true), 40, GOLD if style != Style.DEEP else SAPPHIRE, 0.6)
	p.one_shot = true
	p.explosiveness = 1.0
	p.lifetime = 1.4
	p.spread = 70.0
	p.initial_velocity_min = 2.0
	p.initial_velocity_max = 4.5
	p.gravity = Vector3(0.0, -2.0, 0.0)
	p.position.y = 0.5
	p.emitting = true
	get_tree().create_timer(2.0).timeout.connect(p.queue_free)
