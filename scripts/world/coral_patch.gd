@tool
extends Node3D
## Mercan Koyu'nun sığ resifi: açık kum taban, pembe mercanlar ve küçük taşlar.
## Ortadaki boş alan batık için ayrılmıştır.

@export var radius := 6.0
@export var count := 10
@export var clear_radius := 2.8
@export var decoration_seed := 5
@export_tool_button("Yeniden Oluştur", "Reload") var rebuild_action: Callable = rebuild


func _ready() -> void:
	rebuild()


func rebuild() -> void:
	PropLibrary.clear_generated(self)
	var rng := RandomNumberGenerator.new()
	rng.seed = decoration_seed
	var batch := MeshBatcher.new()
	var shallow := MeshBatcher.new()
	shallow.add(PropLibrary.ring(radius * 0.5, radius * 0.45, radius * 0.9), Transform3D(Basis.IDENTITY, Vector3(0.0, 0.02, 0.0)))
	shallow.add(PropLibrary.ring(radius * 0.05, radius * 0.05, radius * 0.5), Transform3D(Basis.IDENTITY, Vector3(0.0, 0.021, 0.0)))
	for i in count:
		var angle := TAU * i / count + rng.randf_range(-0.25, 0.25)
		var distance := rng.randf_range(clear_radius, radius)
		var pos := Vector3(cos(angle) * distance, -1.1, sin(angle) * distance)
		PropLibrary.add_coral(batch, pos, rng.randf_range(1.2, 1.7), rng)
	for i in 5:
		var angle := rng.randf_range(0.0, TAU)
		var distance := rng.randf_range(clear_radius, radius)
		PropLibrary.add_rock(batch, Vector3(cos(angle) * distance, -0.95, sin(angle) * distance), rng.randf_range(0.35, 0.6), 0.8, rng)
	PropLibrary.add_mesh(self, "_Gorsel", batch.commit(PropLibrary.toon_material()), false)
	PropLibrary.add_mesh(self, "_SigSu", shallow.commit(PropLibrary.shallow_material()), false)
