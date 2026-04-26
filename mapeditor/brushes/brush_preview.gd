extends Node3D
class_name BrushPreview

var radius := 6.0
var _fill: MeshInstance3D
var _ring: MeshInstance3D

func _ready() -> void:
	_fill = MeshInstance3D.new()
	_fill.name = "Fill"
	add_child(_fill)
	_ring = MeshInstance3D.new()
	_ring.name = "Ring"
	add_child(_ring)
	set_radius(radius)

func set_radius(new_radius: float) -> void:
	radius = new_radius
	if _ring == null:
		return
	_fill.mesh = _build_fill_mesh(radius)
	_fill.material_override = _create_fill_material()
	_ring.mesh = _build_ring_mesh(radius)
	_ring.material_override = _create_ring_material()

func show_at(local_position: Vector3) -> void:
	position = local_position + Vector3.UP * 0.12
	visible = true

func hide_preview() -> void:
	visible = false

func _build_ring_mesh(ring_radius: float) -> ArrayMesh:
	var mesh := ArrayMesh.new()
	var vertices := PackedVector3Array()
	var segments := 96
	for i in range(segments):
		var a := TAU * float(i) / float(segments)
		var b := TAU * float(i + 1) / float(segments)
		vertices.append(Vector3(cos(a) * ring_radius, 0.0, sin(a) * ring_radius))
		vertices.append(Vector3(cos(b) * ring_radius, 0.0, sin(b) * ring_radius))

	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_LINES, arrays)
	return mesh

func _build_fill_mesh(fill_radius: float) -> ArrayMesh:
	var mesh := ArrayMesh.new()
	var vertices := PackedVector3Array()
	var segments := 96
	for i in range(segments):
		var angle := TAU * float(i) / float(segments)
		var next_angle := TAU * float(i + 1) / float(segments)
		vertices.append(Vector3.ZERO)
		vertices.append(Vector3(cos(angle) * fill_radius, 0.0, sin(angle) * fill_radius))
		vertices.append(Vector3(cos(next_angle) * fill_radius, 0.0, sin(next_angle) * fill_radius))

	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh

func _create_ring_material() -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = Color(1.0, 1.0, 1.0, 0.85)
	return material

func _create_fill_material() -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.albedo_color = Color(0.45, 0.9, 0.35, 0.22)
	material.no_depth_test = true
	return material
