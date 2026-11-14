class_name Ship
extends CharacterBody3D
## Arcade korsan gemisi kontrolü. W/↑ ileri; S/↓ önce frenler, gemi durunca
## geri gider; A/D ve ←/→ döndürür (dönüş hafif yumuşaktır, durgunken yavaştır).
## Kayalığa çarpınca kısa süre yavaşlar; can veya batma sistemi yoktur.

signal rock_hit

@export var max_speed := 5.5
@export var reverse_max_speed := 3.0
@export var acceleration := 8.0
@export var brake_deceleration := 14.0
@export var drag := 3.0
@export_range(30.0, 360.0) var turn_speed_degrees := 110.0
## Dönüşün hedef hıza yaklaşma hızı; büyüdükçe dönüş daha keskin olur.
@export var turn_response := 7.0
@export_range(0.05, 1.0) var rock_slow_multiplier := 0.35
@export var rock_slow_duration := 1.2

## Oyun durumu (menü, süre bitti) gemiyi bununla kilitler.
var controls_enabled := true
## İleri yöndeki işaretli hız (birim/sn); negatif = geri.
var speed := 0.0

var _turn_rate := 0.0
var _slow_left := 0.0
var _time := 0.0
var _creak_armed := true

@onready var _model: ShipModel = $Model


func _physics_process(delta: float) -> void:
	var throttle := 0.0
	var steer := 0.0
	if controls_enabled:
		throttle = Input.get_axis(&"ship_back", &"ship_forward")
		steer = Input.get_axis(&"ship_right", &"ship_left")
	_update_speed(throttle, delta)
	_update_turn(steer, delta)
	rotation.y += _turn_rate * delta
	velocity = -global_basis.z * speed
	move_and_slide()
	_handle_collisions()
	position.y = 0.0
	_slow_left = maxf(_slow_left - delta, 0.0)


func _process(delta: float) -> void:
	_time += delta
	var speed_ratio := clampf(speed / max_speed, -1.0, 1.0)
	_model.position.y = sin(_time * 1.7) * 0.08
	_model.rotation.x = sin(_time * 0.9) * 0.025
	_model.rotation.z = sin(_time * 1.2) * 0.035 - _turn_rate * 0.12 * absf(speed_ratio)
	_model.set_wake_strength(absf(speed_ratio))
	_model.wave_flag(_time)
	_update_sound(speed_ratio)


## Pruva suyu hızla yükselir ve incelir; kalkışta ve sert dönüşte ahşap gıcırdar
## (AudioManager'daki bekleme süresi gıcırtının sık tekrarlanmasını önler).
func _update_sound(speed_ratio: float) -> void:
	var moving := absf(speed_ratio)
	AudioManager.set_loop_volume(&"ship_water", moving * 0.9, 0.8 + 0.35 * moving)
	# Hız her karede küçük adımlarla değiştiği için "durgundu" bilgisi bir bayrakta tutulur.
	if moving < 0.08:
		_creak_armed = true
	var starting := _creak_armed and moving > 0.3
	var hard_turn := absf(_turn_rate) > 1.4 and moving > 0.5
	if controls_enabled and (starting or hard_turn):
		AudioManager.play_sfx(&"ship_creak")
		_creak_armed = false


## Kilitlenen gemi anında durur ve girdiye tepki vermez (süre bitti, görev bitti).
func set_controls_enabled(enabled: bool) -> void:
	controls_enabled = enabled
	if not enabled:
		speed = 0.0
		_turn_rate = 0.0
		velocity = Vector3.ZERO


func is_slowed() -> bool:
	return _slow_left > 0.0


## Gemiyi bir noktaya yerleştirir ve hareketini sıfırlar (yeniden başlatma için).
func reset_to(spawn: Transform3D) -> void:
	global_transform = spawn
	speed = 0.0
	_turn_rate = 0.0
	_slow_left = 0.0
	velocity = Vector3.ZERO


func _update_speed(throttle: float, delta: float) -> void:
	var limit := max_speed * (rock_slow_multiplier if is_slowed() else 1.0)
	if throttle > 0.0:
		var rate := brake_deceleration if speed < 0.0 else acceleration
		speed = move_toward(speed, limit * throttle, rate * delta)
	elif throttle < 0.0:
		if speed > 0.0:
			speed = move_toward(speed, 0.0, brake_deceleration * delta)
		else:
			speed = move_toward(speed, -reverse_max_speed * -throttle, acceleration * delta)
	else:
		speed = move_toward(speed, 0.0, drag * delta)
	speed = clampf(speed, -reverse_max_speed, limit)


func _update_turn(steer: float, delta: float) -> void:
	var speed_factor := clampf(absf(speed) / max_speed, 0.0, 1.0)
	var target := steer * deg_to_rad(turn_speed_degrees) * lerpf(0.45, 1.0, speed_factor)
	_turn_rate = lerpf(_turn_rate, target, 1.0 - exp(-turn_response * delta))


func _handle_collisions() -> void:
	var delta := get_physics_process_delta_time()
	for i in get_slide_collision_count():
		var collision := get_slide_collision(i)
		var body := collision.get_collider() as CollisionObject3D
		if body == null:
			continue
		if body.collision_layer & PropLibrary.LAYER_ROCKS:
			if not is_slowed():
				_slow_left = rock_slow_duration
				speed *= rock_slow_multiplier
				AudioManager.play_sfx(&"rock_hit")
				rock_hit.emit()
		else:
			# Kıyıya önden çarpınca hız kesilir, yandan sürtünürken az etkilenir.
			var head_on := absf(collision.get_normal().dot(global_basis.z))
			speed *= 1.0 - minf(head_on * 6.0 * delta, 1.0)
