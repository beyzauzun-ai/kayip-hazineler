@tool
class_name MeshBatcher
extends RefCounted
## Çok sayıda küçük parçayı tek bir ArrayMesh'te birleştirir; böylece bir ada
## tek çizim çağrısıyla çizilir (entegre ekran kartları için önemli).
## Her parçanın rengi vertex rengine yazılır.

var _verts := PackedVector3Array()
var _norms := PackedVector3Array()
var _colors := PackedColorArray()
var _uvs := PackedVector2Array()
var _indices := PackedInt32Array()


## `shade` > 0 ise renk parçanın kendi yüksekliği boyunca değişir: taban
## (1 - shade) kadar koyu, tepe biraz açık. Işıktan bağımsız, maliyetsiz bir
## ortam gölgesi etkisi verir (kaya, çalı, çimen).
func add(mesh: Mesh, xform: Transform3D, color: Color = Color.WHITE, shade: float = 0.0) -> void:
	var arrays := mesh.surface_get_arrays(0)
	var bottom := 0.0
	var height := 1.0
	if shade > 0.0:
		var aabb := mesh.get_aabb()
		bottom = aabb.position.y
		height = maxf(aabb.size.y, 0.001)
	var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var norms: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
	var uvs: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV] if arrays[Mesh.ARRAY_TEX_UV] != null else PackedVector2Array()
	var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX] if arrays[Mesh.ARRAY_INDEX] != null else PackedInt32Array()
	var base := _verts.size()
	var normal_basis := xform.basis.inverse().transposed()
	var has_uv := uvs.size() == verts.size()
	for i in verts.size():
		_verts.append(xform * verts[i])
		_norms.append((normal_basis * norms[i]).normalized())
		if shade > 0.0:
			var t := clampf((verts[i].y - bottom) / height, 0.0, 1.0)
			var k := lerpf(1.0 - shade, 1.0 + shade * 0.25, t)
			_colors.append(Color(color.r * k, color.g * k, color.b * k, color.a))
		else:
			_colors.append(color)
		_uvs.append(uvs[i] if has_uv else Vector2.ZERO)
	if indices.is_empty():
		for i in verts.size():
			_indices.append(base + i)
	else:
		for i in indices:
			_indices.append(base + i)


func is_empty() -> bool:
	return _verts.is_empty()


func commit(material: Material) -> ArrayMesh:
	var mesh := ArrayMesh.new()
	if is_empty():
		return mesh
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = _verts
	arrays[Mesh.ARRAY_NORMAL] = _norms
	arrays[Mesh.ARRAY_COLOR] = _colors
	arrays[Mesh.ARRAY_TEX_UV] = _uvs
	arrays[Mesh.ARRAY_INDEX] = _indices
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	mesh.surface_set_material(0, material)
	return mesh
