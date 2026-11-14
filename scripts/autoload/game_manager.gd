extends Node
## Oyunun merkezi durumu: süre, eserler, keşifler, altın ve açık artırma ekonomisi.
## Sahneler bu düğümün sinyallerini dinler; durum yalnızca buradan değiştirilir.

signal state_changed(new_state: State)
signal time_changed(time_left: float)
signal wreck_discovered(wreck_id: StringName)
signal artifact_collected(artifact_id: StringName)
signal gold_changed(gold: int)
signal mission_won
signal mission_lost

enum State { MENU, SAILING, AUCTION, RESULT }

const MISSION_TIME := 120.0

## Batık ve eser verileri. Sıra, açık artırmadaki satış sırasıdır.
const ARTIFACTS: Array[Dictionary] = [
	{
		"id": &"compass",
		"name": "Kayıp Pusula",
		"wreck_id": &"coral_cove",
		"wreck_name": "Mercan Koyu",
		"base_offer": 100,
	},
	{
		"id": &"crown",
		"name": "Kraliyet Tacı",
		"wreck_id": &"misty_pass",
		"wreck_name": "Sisli Geçit",
		"base_offer": 180,
	},
	{
		"id": &"sapphire",
		"name": "Okyanus Safiri",
		"wreck_id": &"deep_blue",
		"wreck_name": "Derin Mavi",
		"base_offer": 300,
	},
]

## Açık artırma: her beklemede teklifin yükselme olasılığı (%70; vazgeçme %30).
const RAISE_CHANCE := 0.7
## Taban teklife göre çarpanlar, yüzde olarak: 1. başarılı bekleme ×1,5,
## 2. başarılı bekleme ×2,2. Kayan nokta hatası olmasın diye tam sayı tutulur.
const WAIT_MULTIPLIER_PERCENTS: Array[int] = [150, 220]
const MAX_WAITS := 2
## Teklifler bu sayının en yakın katına yuvarlanır.
const OFFER_STEP := 5

## Unvan eşikleri (toplam altın), yüksekten düşüğe.
const TITLES: Array[Dictionary] = [
	{"min_gold": 1000, "title": "Denizlerin Efsanesi"},
	{"min_gold": 650, "title": "Usta Hazine Avcısı"},
	{"min_gold": 0, "title": "Acemi Korsan"},
]

var state: State = State.MENU
var time_left: float = MISSION_TIME
var gold: int = 0
var collected: Array[StringName] = []
var discovered: Array[StringName] = []
## Eser kimliği -> satış tutarı (0 = satılamadı).
var sales: Dictionary = {}
## true ise deniz sahnesi bir sonraki açılışta ana menüyü atlayıp görevi
## doğrudan başlatır ("Yeniden Başlat" için).
var skip_menu_once := false


func _process(delta: float) -> void:
	if state != State.SAILING:
		return
	time_left = maxf(time_left - delta, 0.0)
	time_changed.emit(time_left)
	if time_left <= 0.0:
		_lose()


## Tüm ilerlemeyi sıfırlar; yeni bir deniz görevi başlatmadan önce çağrılır.
func reset() -> void:
	time_left = MISSION_TIME
	gold = 0
	collected.clear()
	discovered.clear()
	sales.clear()
	time_changed.emit(time_left)
	gold_changed.emit(gold)
	_set_state(State.MENU)


func start_mission() -> void:
	reset()
	_set_state(State.SAILING)


func is_sailing() -> bool:
	return state == State.SAILING


func discover_wreck(wreck_id: StringName) -> bool:
	if not is_sailing() or wreck_id in discovered:
		return false
	discovered.append(wreck_id)
	wreck_discovered.emit(wreck_id)
	return true


## Eseri envantere ekler. Aynı eser ikinci kez verilmez.
func collect_artifact(artifact_id: StringName) -> bool:
	if not is_sailing() or artifact_id in collected:
		return false
	collected.append(artifact_id)
	artifact_collected.emit(artifact_id)
	return true


func has_all_artifacts() -> bool:
	return collected.size() == ARTIFACTS.size()


## Liman alanına girişte çağrılır. Süre tam sıfırken giriş başarısızdır.
func try_finish_at_port() -> bool:
	if not is_sailing() or time_left <= 0.0 or not has_all_artifacts():
		return false
	mission_won.emit()
	_set_state(State.AUCTION)
	return true


## Taban teklif ve başarılı bekleme sayısına (0, 1, 2) göre teklif tutarı.
## Sonuç en yakın 5'in katına yuvarlanır (eşitlikte yukarı); hesap tamamen tam
## sayıyla yapılır. Örnek: 180 × 2,2 = 396 → 395 (395'e uzaklık 1, 400'e 4).
## Tablo: Pusula 100/150/220, Taç 180/270/395, Safir 300/450/660.
func get_offer(artifact_id: StringName, waits: int) -> int:
	var base := int(get_artifact(artifact_id).get("base_offer", 0))
	if waits <= 0:
		return base
	var raw_x100 := base * WAIT_MULTIPLIER_PERCENTS[mini(waits, MAX_WAITS) - 1]
	var step_x100 := OFFER_STEP * 100
	return (raw_x100 + step_x100 / 2) / step_x100 * OFFER_STEP


## Bir eserin satış sonucunu kaydeder ve altını ekler; toplam altının TEK kaynağı
## budur. Yalnızca açık artırma sırasında, toplanmış ve henüz satılmamış bir
## eser için kabul edilir; aksi hâlde hiçbir şey değişmez ve false döner.
## amount = 0, alıcıların vazgeçtiği (satılamayan) eser demektir.
func record_sale(artifact_id: StringName, amount: int) -> bool:
	if state != State.AUCTION or not artifact_id in collected or sales.has(artifact_id) or amount < 0:
		return false
	sales[artifact_id] = amount
	gold += amount
	gold_changed.emit(gold)
	return true


func finish_auction() -> void:
	if state == State.AUCTION:
		_set_state(State.RESULT)


func get_title() -> String:
	for entry in TITLES:
		if gold >= int(entry["min_gold"]):
			return entry["title"]
	return TITLES[-1]["title"]


func get_artifact(artifact_id: StringName) -> Dictionary:
	for entry in ARTIFACTS:
		if entry["id"] == artifact_id:
			return entry
	return {}


func _lose() -> void:
	mission_lost.emit()
	_set_state(State.RESULT)


func _set_state(new_state: State) -> void:
	if state == new_state:
		return
	state = new_state
	state_changed.emit(state)
