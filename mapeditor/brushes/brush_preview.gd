extends Node3D
class_name BrushPreview

var radius := 6.0
var _ring: MeshInstance3D

func _ready() -> void:
	_ring = MeshInstance3D.new()
	_ring.name = "Ring"
	add_child(_ring)
	set_radius(radius)

func set_radius(new_radius: float) -> void:
	radius = new_radius
	if _ring == null:
		return
	_ring.mesh = _build_ring_mesh(radius)
	_ring.material_override = _create_material()

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

func _create_material() -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = Color(1.0, 1.0, 1.0, 0.85)
	return material
