class_name AuctionSession
extends RefCounted
## Açık artırmanın arayüzden bağımsız mantığı. Üç eser GameManager.ARTIFACTS
## sırasıyla satışa çıkar. Her eser için:
##   accept() → mevcut teklif satılır.
##   wait()   → %70 teklif yükselir (×1,5, sonra ×2,2), %30 alıcılar vazgeçer (0 altın).
##              En fazla 2 bekleme; ikinci başarılı beklemede teklif otomatik satılır.
## Satış bitince eser ITEM_DONE olur; next_item() sıradakine geçer, üçü bitince
## `finished` yayınlanır. Altın yalnızca GameManager.record_sale() ile eklenir
## (tek kaynak), o da aynı eserin ikinci kez kaydedilmesini reddeder.
## Rastgelelik dışarıdan kontrol edilebilir: `rng` tohumlanabilir, testler
## `forced_outcomes` ile sonuçları sırayla belirleyebilir.

signal item_started(artifact_id: StringName, offer: int)
signal offer_raised(artifact_id: StringName, offer: int, waits_used: int)
signal sold(artifact_id: StringName, amount: int, automatic: bool)
signal buyers_left(artifact_id: StringName)
signal finished(total_gold: int)

enum Phase { IDLE, OFFER, ITEM_DONE, FINISHED }

var rng := RandomNumberGenerator.new()
## Doluysa wait() sonuçları rastgele yerine bu listeden sırayla alınır
## (true = teklif yükseldi). Yalnızca testler içindir.
var forced_outcomes: Array[bool] = []

var phase := Phase.IDLE
var index := -1
var waits_used := 0
var offer := 0
## Her eser için {id, amount, waits, automatic} kaydı (satış sırasıyla).
var results: Array[Dictionary] = []

var _game: Node


func _init(game: Node, seed_value: int = -1) -> void:
	_game = game
	if seed_value >= 0:
		rng.seed = seed_value
	else:
		rng.randomize()


## Açık artırmayı başlatır. Yalnızca GameManager AUCTION durumundayken ve üç eser
## de toplanmışken mümkündür (başarısız görevden açık artırmaya geçilemez).
func start() -> bool:
	if phase != Phase.IDLE or _game.state != _game.State.AUCTION or not _game.has_all_artifacts():
		return false
	index = 0
	_begin_item()
	return true


func current_artifact_id() -> StringName:
	return _game.ARTIFACTS[index]["id"] if index >= 0 and index < _game.ARTIFACTS.size() else &""


func can_accept() -> bool:
	return phase == Phase.OFFER


func can_wait() -> bool:
	return phase == Phase.OFFER and waits_used < _game.MAX_WAITS


## Bir sonraki beklemede teklif yükselirse ulaşılacak tutar (bekleme hakkı yoksa 0).
func next_offer() -> int:
	return _game.get_offer(current_artifact_id(), waits_used + 1) if can_wait() else 0


func raise_chance() -> float:
	return _game.RAISE_CHANCE


func accept() -> bool:
	if not can_accept():
		return false
	return _sell(offer, false)


func wait() -> bool:
	if not can_wait():
		return false
	waits_used += 1
	var id := current_artifact_id()
	if not _roll():
		if not _record(id, 0, false):
			return false
		buyers_left.emit(id)
		return true
	offer = _game.get_offer(id, waits_used)
	offer_raised.emit(id, offer, waits_used)
	if waits_used >= _game.MAX_WAITS:
		_sell(offer, true)
	return true


## Satışı biten eserden sıradakine geçer; son eserden sonra açık artırma biter.
func next_item() -> bool:
	if phase != Phase.ITEM_DONE:
		return false
	index += 1
	if index >= _game.ARTIFACTS.size():
		phase = Phase.FINISHED
		finished.emit(_game.gold)
		return true
	_begin_item()
	return true


func total_gold() -> int:
	return _game.gold


func _begin_item() -> void:
	waits_used = 0
	offer = _game.get_offer(current_artifact_id(), 0)
	phase = Phase.OFFER
	item_started.emit(current_artifact_id(), offer)


func _sell(amount: int, automatic: bool) -> bool:
	var id := current_artifact_id()
	if not _record(id, amount, automatic):
		return false
	sold.emit(id, amount, automatic)
	return true


func _record(id: StringName, amount: int, automatic: bool) -> bool:
	phase = Phase.ITEM_DONE
	if not _game.record_sale(id, amount):
		return false
	results.append({"id": id, "amount": amount, "waits": waits_used, "automatic": automatic})
	return true


func _roll() -> bool:
	if not forced_outcomes.is_empty():
		return forced_outcomes.pop_front()
	return rng.randf() < _game.RAISE_CHANCE
