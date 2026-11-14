@tool
class_name PortZone
extends Area3D
## Başlangıç/bitiş limanının varış alanı (suda altın halka ile işaretli).
## Gemi üç eserle ve süre bitmeden girerse deniz görevi tamamlanır; eksik
## eserle girerse görev sürer ve yalnızca uyarı verilir. Gemi oyuna bu alanın
## içinde başladığı için alan, gemi bir kez dışarı çıkana kadar girişleri yok sayar.

signal hint(text: String)
signal arrived

@export var radius := 7.0

var _armed := false


func _ready() -> void:
	_build_marker()
	if Engine.is_editor_hint():
		return
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)


## Yeni görevde gemi yine alanın içinden başlar.
func reset() -> void:
	_armed = false


func _on_body_exited(body: Node3D) -> void:
	if body is Ship:
		_armed = true


func _on_body_entered(body: Node3D) -> void:
	if not body is Ship or not _armed or not GameManager.is_sailing():
		return
	if not GameManager.has_all_artifacts():
		hint.emit("Limana dönmek için 3/3 eser gerekli! (Şu an %d/3)" % GameManager.collected.size())
	elif GameManager.try_finish_at_port():
		arrived.emit()


func _build_marker() -> void:
	PropLibrary.clear_generated(self)
	var material := PropLibrary.foam_material().duplicate() as ShaderMaterial
	material.set_shader_parameter("foam_color", Color(1.0, 0.82, 0.3, 0.95))
	material.set_shader_parameter("fade_start", 0.55)
	material.set_shader_parameter("edge_noise", 0.15)
	var b := MeshBatcher.new()
	b.add(PropLibrary.ring(radius - 0.9, radius - 0.9, 1.2, 64), Transform3D(Basis.IDENTITY, Vector3(0.0, 0.06, 0.0)))
	b.add(PropLibrary.ring(radius - 2.4, radius - 2.4, 0.5, 64), Transform3D(Basis.IDENTITY, Vector3(0.0, 0.065, 0.0)))
	PropLibrary.add_mesh(self, "_Isaret", b.commit(material), false)
