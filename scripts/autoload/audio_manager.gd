extends Node
## Ses yönetimi: müzik (yumuşak geçişli), sürekli döngüler (dalga, rüzgâr, gemi
## suyu), efektler, ses ayarları ve kaydı. Sesler isimle çağrılır
## ("res://assets/audio/<isim>.wav"; bkz. tools/generate_audio.py).
##
## Birikmeye karşı önlemler:
## - Aynı isimli efekt yeniden çalınırsa önceki durdurulur (aynı ses üst üste binmez).
## - Bazı efektlerin bekleme süresi vardır (ör. kaya çarpması 0,3 sn içinde bir kez).
## - Sık tekrarlanan efektlerin perdesi her çalışta hafifçe değişir (tekdüzelik olmaz).
## - Efekt havuzu sınırlıdır; Master bus'taki limiter kırpılmayı önler.
## - Fanfar çalarken müzik kısa süre kısılır.
## Bus'lar: Master ← Music, Master ← SFX ← Ambient (ortam sesleri Efektler ayarına uyar).

## Bir efekt istendiğinde (dosyası olmasa ya da bekleme süresine takılsa bile).
signal sfx_requested(sound_name: StringName)
## Bir efekt gerçekten çalmaya başladığında.
signal sfx_played(sound_name: StringName)

const AUDIO_DIR := "res://assets/audio/"
const SETTINGS_PATH := "user://settings.cfg"
const SFX_POOL_SIZE := 10
const MUSIC_FADE := 1.2
## Döngüsel çalınan sesler (WAV döngü noktaları yüklenirken ayarlanır).
const LOOPS: Array[StringName] = [&"music_main", &"music_auction", &"amb_waves", &"amb_waves_beach", &"amb_wind", &"ship_water"]
## Oyunda çalan deniz dalgası: gerçek CC0 kayıttan hazırlanan kıyı dalgası döngüsü
## (bkz. assets/audio/KAYNAKLAR.md). Eski sentetik amb_waves dosyası korunur ama çalınmaz.
const SEA_AMBIENCE := &"amb_waves_beach"
## Ses başına seviye düzeltmesi (dB); sesler arası dengeyi sağlar.
const GAIN_DB := {
	# ship_water 12 dB kısıldı (−3 → −15): gerçek dalganın altında hafif bir eşlik kalsın.
	&"amb_waves": -4.0, &"amb_waves_beach": -4.0, &"amb_wind": -6.0, &"ship_water": -15.0, &"ship_creak": -8.0, &"rock_hit": -2.0,
	&"extract_loop": -4.0, &"timer_tick": -3.0, &"ui_click": -2.0, &"ui_move": -4.0, &"ui_denied": -2.0,
	&"music_main": -3.0, &"music_auction": -3.0,
}
## Aynı efektin yeniden çalabilmesi için gereken en kısa süre (sn).
const COOLDOWN := {
	&"rock_hit": 0.3, &"ship_creak": 2.5, &"ui_move": 0.05, &"ui_click": 0.04, &"ui_denied": 0.3, &"timer_tick": 0.5,
}
## Her çalışta rastgele perde sapması (± oran).
const PITCH_JITTER := {&"rock_hit": 0.06, &"ui_click": 0.05, &"ui_move": 0.05, &"ship_creak": 0.08, &"auction_new_offer": 0.03}
## Çalarken müziği kısan sesler.
const DUCKING := [&"mission_win", &"mission_lose", &"auction_rank", &"treasure_success"]

var sound_enabled: bool = true
var music_volume: float = 0.7
var sfx_volume: float = 0.8

var _music_players: Array[AudioStreamPlayer] = []
var _music_index := 0
var _music_name: StringName = &""
var _loops: Dictionary = {}
var _sfx_players: Array[AudioStreamPlayer] = []
## Efekt ismi -> o efekti çalan oyuncu.
var _active: Dictionary = {}
var _last_played: Dictionary = {}
var _cache: Dictionary = {}
var _missing_warned: Dictionary = {}
var _duck_db := 0.0
var _pause_db := 0.0
var _duck_tween: Tween
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_rng.randomize()
	for i in 2:
		var player := AudioStreamPlayer.new()
		player.bus = &"Music"
		add_child(player)
		_music_players.append(player)
	for i in SFX_POOL_SIZE:
		var player := AudioStreamPlayer.new()
		player.bus = &"SFX"
		add_child(player)
		_sfx_players.append(player)
	load_settings()


# --- Efektler ---------------------------------------------------------------------------

func play_sfx(sound_name: StringName, pitch: float = 1.0) -> void:
	sfx_requested.emit(sound_name)
	var now := Time.get_ticks_msec() / 1000.0
	if COOLDOWN.has(sound_name) and now - _last_played.get(sound_name, -100.0) < COOLDOWN[sound_name]:
		return
	var stream := _get_stream(sound_name)
	if stream == null:
		return
	stop_sfx(sound_name)
	var player := _free_player()
	player.stream = stream
	var jitter: float = PITCH_JITTER.get(sound_name, 0.0)
	player.pitch_scale = pitch * (1.0 + _rng.randf_range(-jitter, jitter))
	player.volume_db = GAIN_DB.get(sound_name, 0.0)
	player.play()
	_active[sound_name] = player
	_last_played[sound_name] = now
	sfx_played.emit(sound_name)
	if sound_name in DUCKING:
		duck_music(-9.0, stream.get_length() * 0.8)


func stop_sfx(sound_name: StringName) -> void:
	var player: AudioStreamPlayer = _active.get(sound_name)
	if player and player.playing:
		player.stop()
	_active.erase(sound_name)


func is_sfx_playing(sound_name: StringName) -> bool:
	var player: AudioStreamPlayer = _active.get(sound_name)
	return player != null and player.playing


func active_sfx_count() -> int:
	var n := 0
	for player in _sfx_players:
		if player.playing:
			n += 1
	return n


func stop_all_sfx() -> void:
	for player in _sfx_players:
		player.stop()
	_active.clear()


# --- Müzik ----------------------------------------------------------------------------------

## Müziği değiştirir; aynı parça zaten çalıyorsa hiçbir şey yapmaz (yeniden
## başlatmada müzik kesilmez). Eski parça yavaşça kısılır, yenisi yükselir.
func play_music(sound_name: StringName, fade: float = MUSIC_FADE) -> void:
	if sound_name == _music_name and _music_players[_music_index].playing:
		return
	var stream := _get_stream(sound_name)
	if stream == null:
		return
	var old := _music_players[_music_index]
	_music_index = 1 - _music_index
	var player := _music_players[_music_index]
	player.stream = stream
	var target: float = GAIN_DB.get(sound_name, 0.0)
	player.volume_db = target - 40.0
	player.play()
	_music_name = sound_name
	var tween := create_tween().set_parallel()
	tween.tween_property(player, "volume_db", target, fade)
	if old.playing:
		tween.tween_property(old, "volume_db", old.volume_db - 40.0, fade)
		tween.chain().tween_callback(old.stop)


func stop_music() -> void:
	for player in _music_players:
		player.stop()
	_music_name = &""


func current_music() -> StringName:
	return _music_name if _music_players[_music_index].playing else &""


## Müziği kısa süre kısar (fanfarların duyulması için), sonra eski seviyeye döndürür.
func duck_music(db: float, hold: float) -> void:
	if _duck_tween:
		_duck_tween.kill()
	_duck_tween = create_tween()
	_duck_tween.tween_method(_set_duck, _duck_db, db, 0.15)
	_duck_tween.tween_interval(hold)
	_duck_tween.tween_method(_set_duck, db, 0.0, 0.6)


func _set_duck(db: float) -> void:
	_duck_db = db
	_apply_settings()


# --- Döngüler (ortam, gemi suyu) ------------------------------------------------------------

## Döngüyü başlatır (zaten çalıyorsa dokunmaz). volume: 0..1 doğrusal.
func play_loop(sound_name: StringName, bus: StringName = &"Ambient", volume: float = 1.0) -> void:
	var player: AudioStreamPlayer = _loops.get(sound_name)
	if player == null:
		var stream := _get_stream(sound_name)
		if stream == null:
			return
		player = AudioStreamPlayer.new()
		player.stream = stream
		player.bus = bus
		add_child(player)
		_loops[sound_name] = player
	set_loop_volume(sound_name, volume)
	if not player.playing:
		player.play()


func set_loop_volume(sound_name: StringName, volume: float, pitch: float = 1.0) -> void:
	var player: AudioStreamPlayer = _loops.get(sound_name)
	if player == null:
		return
	player.volume_db = GAIN_DB.get(sound_name, 0.0) + linear_to_db(maxf(volume, 0.0001))
	player.pitch_scale = clampf(pitch, 0.5, 2.0)


func stop_loop(sound_name: StringName) -> void:
	var player: AudioStreamPlayer = _loops.get(sound_name)
	if player:
		player.stop()


func is_loop_playing(sound_name: StringName) -> bool:
	var player: AudioStreamPlayer = _loops.get(sound_name)
	return player != null and player.playing and not player.stream_paused


func loop_volume_db(sound_name: StringName) -> float:
	var player: AudioStreamPlayer = _loops.get(sound_name)
	return player.volume_db if player else -80.0


## Oyun duraklatılınca: gemi suyu ve çıkarma sesi durur, müzik ve ortam kısılır.
func set_game_paused(paused: bool) -> void:
	var water: AudioStreamPlayer = _loops.get(&"ship_water")
	if water:
		water.stream_paused = paused
	if paused:
		stop_sfx(&"extract_loop")
	_pause_db = -8.0 if paused else 0.0
	_apply_settings()


# --- Ayarlar --------------------------------------------------------------------------------

func set_sound_enabled(enabled: bool) -> void:
	sound_enabled = enabled
	_apply_settings()
	save_settings()


func set_music_volume(value: float) -> void:
	music_volume = clampf(value, 0.0, 1.0)
	_apply_settings()
	save_settings()


func set_sfx_volume(value: float) -> void:
	sfx_volume = clampf(value, 0.0, 1.0)
	_apply_settings()
	save_settings()


func load_settings() -> void:
	var config := ConfigFile.new()
	if config.load(SETTINGS_PATH) == OK:
		sound_enabled = config.get_value("audio", "sound_enabled", sound_enabled)
		music_volume = config.get_value("audio", "music_volume", music_volume)
		sfx_volume = config.get_value("audio", "sfx_volume", sfx_volume)
	_apply_settings()


func save_settings() -> void:
	var config := ConfigFile.new()
	config.set_value("audio", "sound_enabled", sound_enabled)
	config.set_value("audio", "music_volume", music_volume)
	config.set_value("audio", "sfx_volume", sfx_volume)
	config.save(SETTINGS_PATH)


func _apply_settings() -> void:
	AudioServer.set_bus_mute(AudioServer.get_bus_index(&"Master"), not sound_enabled)
	_set_bus_linear(&"Music", music_volume, _duck_db + _pause_db)
	_set_bus_linear(&"SFX", sfx_volume, 0.0)
	var ambient := AudioServer.get_bus_index(&"Ambient")
	if ambient != -1:
		AudioServer.set_bus_volume_db(ambient, _pause_db)


func _set_bus_linear(bus_name: StringName, value: float, offset_db: float) -> void:
	var index := AudioServer.get_bus_index(bus_name)
	if index == -1:
		return
	AudioServer.set_bus_mute(index, value <= 0.0)
	AudioServer.set_bus_volume_db(index, linear_to_db(maxf(value, 0.0001)) + offset_db)


# --- İç yardımcılar --------------------------------------------------------------------

## Boşta olan bir oyuncu döndürür; hepsi meşgulse en eski efekti keser.
func _free_player() -> AudioStreamPlayer:
	for player in _sfx_players:
		if not player.playing:
			_forget(player)
			return player
	var oldest := _sfx_players.pop_front() as AudioStreamPlayer
	_sfx_players.append(oldest)
	oldest.stop()
	_forget(oldest)
	return oldest


func _forget(player: AudioStreamPlayer) -> void:
	for key in _active.keys():
		if _active[key] == player:
			_active.erase(key)


func _get_stream(sound_name: StringName) -> AudioStream:
	if _cache.has(sound_name):
		return _cache[sound_name]
	var path := AUDIO_DIR + String(sound_name) + ".wav"
	if not ResourceLoader.exists(path):
		if not _missing_warned.has(sound_name):
			_missing_warned[sound_name] = true
			push_warning("Ses dosyası bulunamadı: %s" % path)
		return null
	var stream := load(path) as AudioStream
	var wav := stream as AudioStreamWAV
	if wav and sound_name in LOOPS:
		# Döngü dosyaları uçtan uca kesintisiz üretildi; tüm dosya döngülenir.
		wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
		wav.loop_begin = 0
		wav.loop_end = int(round(wav.get_length() * wav.mix_rate))
	_cache[sound_name] = stream
	return stream
