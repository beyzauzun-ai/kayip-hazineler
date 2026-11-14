@tool
extends Node3D
## Denizdeki bağımsız kayalıklar. Gemi çarpınca kısa süre yavaşlayacağı için
## ayrı "kayalik" fizik katmanındadır. Konumlar düğüme göre yereldir.

## Kaya: (x, z, boyut, dikey_uzama)
@export var rocks := PackedVector4Array()
@export var decoration_seed := 3
@export_tool_button("Yeniden Oluştur", "Reload") var rebuild_action: Callable = rebuild


func _ready() -> void:
	rebuild()


func rebuild() -> void:
	PropLibrary.clear_generated(self)
	var rng := RandomNumberGenerator.new()
	rng.seed = decoration_seed
	var body := PropLibrary.add_static_body(self, PropLibrary.LAYER_ROCKS)
	var batch := MeshBatcher.new()
	var foam := MeshBatcher.new()
	var shallow := MeshBatcher.new()
	for r in rocks:
		var center := Vector3(r.x, 0.0, r.y)
		PropLibrary.add_rock(batch, center + Vector3(0.0, -0.15 * r.z, 0.0), r.z, r.w, rng)
		shallow.add(PropLibrary.ring(r.z * 0.9, r.z * 0.85, r.z * 1.2), Transform3D(Basis.IDENTITY, center + Vector3(0.0, 0.02, 0.0)))
		foam.add(PropLibrary.ring(r.z * 0.9, r.z * 0.85, 0.7), Transform3D(Basis.IDENTITY, center + Vector3(0.0, 0.04, 0.0)))
		PropLibrary.add_cylinder_shape(body, center, r.z * 0.85)
	PropLibrary.add_mesh(self, "_Gorsel", batch.commit(PropLibrary.rock_material()), true)
	PropLibrary.add_mesh(self, "_SigSu", shallow.commit(PropLibrary.shallow_material()), false)
	PropLibrary.add_mesh(self, "_Kopuk", foam.commit(PropLibrary.foam_material()), false)
