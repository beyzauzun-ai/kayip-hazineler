extends Node3D
## Deniz görevi sahnesi ve oyun akışı. Açılışta ana menü gösterilir (gemi
## kilitli, sayaç akmaz); Oyna ile görev başlar. Esc duraklatma menüsü, M hazine
## haritası; görev bitince (süre doldu ya da limana varıldı) gemi kilitlenir ve
## ardından üç eserle zamanında dönüldüyse açık artırma, sonra rütbeli sonuç
## ekranı açılır; süre dolduysa doğrudan "Süre doldu" ekranı. "Yeniden Başlat"
## sahneyi menüsüz, "Ana Menü" menüyle yeniden yükler.
## Ses: menüde ve denizde ana müzik ile gerçek kıyı dalgası döngüsü; 20 sn kala uyarı
## çanı, son 10 saniyede her saniye tık; ipuçlarında kısa "olmaz" sesi.

## Süre uyarısının başladığı ve tıkların başladığı kalan saniyeler.
const WARNING_SECOND := 20
const TICK_FROM_SECOND := 10

@onready var _ship: Ship = $Gemi
@onready var _port: PortZone = $OyunNoktalari/LimanAlani
@onready var _hud: Hud = $Arayuz/HUD
@onready var _map: TreasureMap = $Arayuz/HazineHaritasi
@onready var _result: MissionOverlay = $Arayuz/GorevSonucu
@onready var _pause: PauseMenu = $Arayuz/DuraklatmaMenusu
@onready var _menu: MainMenu = $Arayuz/AnaMenu
@onready var _auction: AuctionScreen = $Arayuz/AcikArtirma

## Son işlenen tam saniye (süre uyarıları her saniye yalnızca bir kez çalsın).
var _last_second := -1


func _ready() -> void:
	AudioManager.set_game_paused(false)
	AudioManager.play_music(&"music_main")
	AudioManager.play_loop(AudioManager.SEA_AMBIENCE)
	# Sentetik rüzgâr (amb_wind) gerçek dalga kaydının üstüne yapay bir hışırtı
	# eklediği için çalınmıyor; dosyası korunuyor.
	AudioManager.stop_loop(&"amb_wind")
	AudioManager.play_loop(&"ship_water", &"SFX", 0.0)
	for wreck in $Batiklar.get_children():
		wreck.hint.connect(_on_wreck_hint)
	GameManager.state_changed.connect(_on_state_changed)
	GameManager.mission_won.connect(_on_mission_won)
	GameManager.mission_lost.connect(_on_mission_lost)
	_port.hint.connect(_on_port_hint)
	_menu.play_requested.connect(start_game)
	_pause.restart_requested.connect(restart)
	_pause.menu_requested.connect(go_to_main_menu)
	_result.restart_requested.connect(restart)
	_result.menu_requested.connect(go_to_main_menu)
	_auction.auction_finished.connect(_on_auction_finished)
	_map.setup($Adalar.get_children().filter(func(n): return n is Island), $Kayaliklar.rocks, _port, _ship, $Batiklar.get_children())

	GameManager.reset()
	_on_state_changed(GameManager.state)
	if GameManager.skip_menu_once:
		GameManager.skip_menu_once = false
		start_game()
	else:
		_menu.open()


func start_game() -> void:
	_menu.close()
	GameManager.start_mission()
	_last_second = ceili(GameManager.time_left)


func _process(_delta: float) -> void:
	if not GameManager.is_sailing():
		return
	var second := ceili(GameManager.time_left)
	if second == _last_second:
		return
	_last_second = second
	if second == WARNING_SECOND:
		AudioManager.play_sfx(&"timer_warning")
	elif second >= 1 and second <= TICK_FROM_SECOND:
		AudioManager.play_sfx(&"timer_tick")


func restart() -> void:
	GameManager.skip_menu_once = true
	_reload()


func go_to_main_menu() -> void:
	GameManager.skip_menu_once = false
	_reload()


func _reload() -> void:
	get_tree().paused = false
	# Efektler kesilir; müzik ve ortam döngüleri yeniden yüklemede sürer (aynı
	# parça yeniden başlatılmaz, böylece sesler birikmez).
	AudioManager.stop_all_sfx()
	AudioManager.set_game_paused(false)
	AudioManager.set_loop_volume(&"ship_water", 0.0)
	get_tree().reload_current_scene()


func _on_mission_won() -> void:
	AudioManager.play_sfx(&"mission_win")
	_auction.open(AuctionSession.new(GameManager))


func _on_auction_finished(session: AuctionSession) -> void:
	GameManager.finish_auction()
	AudioManager.play_sfx(&"auction_rank")
	_auction.hide()
	_result.show_auction_results(session)


func _on_mission_lost() -> void:
	AudioManager.play_sfx(&"mission_lose")
	_result.show_lost()


func _on_port_hint(text: String) -> void:
	AudioManager.play_sfx(&"ui_denied")
	_hud.show_message(text, UiTheme.WARN)


func _on_wreck_hint(_wreck: Wreck, _text: String) -> void:
	AudioManager.play_sfx(&"ui_denied")


func _on_state_changed(state: GameManager.State) -> void:
	var sailing := state == GameManager.State.SAILING
	_ship.set_controls_enabled(sailing)
	# HUD görev sırasında ve "Süre doldu" ekranının altında görünür; menüde,
	# açık artırmada ve açık artırma sonucunda gizlidir.
	var lost := state == GameManager.State.RESULT and GameManager.sales.is_empty()
	_hud.visible = sailing or lost
	if sailing:
		_port.reset()
	else:
		_map.close()
