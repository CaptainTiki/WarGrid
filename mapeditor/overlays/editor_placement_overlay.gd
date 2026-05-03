extends Node3D
class_name EditorPlacementOverlay

@export var vertical_offset := 0.09
@export var blocked_radius_cells := 5

var terrain: Terrain
var placement_controller: Node

var _enabled := false
var _hover_entity_id: StringName = &""
var _hover_position := Vector3.ZERO
var _hover_cell := Vector2i(-999999, -999999)
var _hover_rotation_y := INF
var _ignored_placement_index := -1

var _candidate_mesh: MeshInstance3D
var _occupied_mesh: MeshInstance3D
var _non_buildable_mesh: MeshInstance3D
var _non_walkable_mesh: MeshInstance3D
var _candidate_valid_material: StandardMaterial3D
var _candidate_invalid_material: StandardMaterial3D
var _occupied_material: StandardMaterial3D
var _non_buildable_material: StandardMaterial3D
var _non_walkable_material: StandardMaterial3D

func _ready() -> void:
	_ensure_meshes()

func setup(terrain_ref: Terrain, placement_controller_ref: Node) -> void:
	terrain = terrain_ref
	placement_controller = placement_controller_ref
	_ensure_meshes()
	hide_overlay()

func set_enabled(enabled: bool) -> void:
	_enabled = enabled
	if not _enabled:
		hide_overlay()
		return
	rebuild()

func set_hover_entity(
		entity_id: StringName,
		local_position: Vector3,
		rotation_y: float,
		ignored_placement_index: int = -1
) -> void:
	if terrain == null or terrain.map_data == null or placement_controller == null:
		hide_overlay()
		return
	var snapped_position: Vector3 = placement_controller.get_snapped_or_original_position(local_position, entity_id)
	var hover_cell := terrain.get_visual_cell_from_local_position(snapped_position)
	if (
			entity_id == _hover_entity_id
			and hover_cell == _hover_cell
			and is_equal_approx(rotation_y, _hover_rotation_y)
			and ignored_placement_index == _ignored_placement_index
			and _candidate_mesh != null
			and _candidate_mesh.visible
	):
		return
	_hover_entity_id = entity_id
	_hover_position = snapped_position
	_hover_cell = hover_cell
	_hover_rotation_y = rotation_y
	_ignored_placement_index = ignored_placement_index
	rebuild()

func clear_hover() -> void:
	_hover_entity_id = &""
	_hover_cell = Vector2i(-999999, -999999)
	_hover_rotation_y = INF
	_ignored_placement_index = -1
	hide_overlay()

func rebuild() -> void:
	_ensure_meshes()
	if not _enabled or terrain == null or terrain.map_data == null or placement_controller == null:
		hide_overlay()
		return
	if _hover_entity_id == &"" or not terrain.map_data.is_visual_cell_in_playable_area(_hover_cell):
		hide_overlay()
		return

	var validation: RefCounted = placement_controller.get_current_hover_validation(
		_hover_entity_id,
		_hover_position,
		_hover_rotation_y,
		_ignored_placement_index
	)
	var candidate_cells: Array[Vector2i] = placement_controller.get_entity_footprint_cells(
		_hover_entity_id,
		_hover_position,
		_hover_rotation_y
	)
	var blocked: Dictionary = placement_controller.get_blocked_cells_near(
		_hover_entity_id,
		_hover_position,
		_hover_rotation_y,
		blocked_radius_cells,
		_ignored_placement_index
	)

	_set_cells_mesh(_occupied_mesh, blocked.get("occupied", []))
	_set_cells_mesh(_non_buildable_mesh, blocked.get("non_buildable", []))
	_set_cells_mesh(_non_walkable_mesh, blocked.get("non_walkable", []))
	_candidate_mesh.material_override = _candidate_valid_material if validation != null and validation.is_valid else _candidate_invalid_material
	_set_cells_mesh(_candidate_mesh, candidate_cells)

func hide_overlay() -> void:
	for mesh_instance in [_candidate_mesh, _occupied_mesh, _non_buildable_mesh, _non_walkable_mesh]:
		if mesh_instance != null:
			mesh_instance.visible = false

func _ensure_meshes() -> void:
	if _candidate_mesh != null:
		return
	_candidate_valid_material = _create_material(Color(0.15, 1.0, 0.35, 0.42))
	_candidate_invalid_material = _create_material(Color(1.0, 0.12, 0.08, 0.48))
	_occupied_material = _create_material(Color(1.0, 0.32, 0.05, 0.48))
	_non_buildable_material = _create_material(Color(0.55, 0.04, 0.06, 0.34))
	_non_walkable_material = _create_material(Color(0.55, 0.02, 0.16, 0.34))
	_non_buildable_mesh = _create_mesh_instance("NonBuildableCells", _non_buildable_material)
	_non_walkable_mesh = _create_mesh_instance("NonWalkableCells", _non_walkable_material)
	_occupied_mesh = _create_mesh_instance("OccupiedCells", _occupied_material)
	_candidate_mesh = _create_mesh_instance("CandidateFootprint", _candidate_valid_material)

func _create_mesh_instance(node_name: String, material: StandardMaterial3D) -> MeshInstance3D:
	var mesh_instance := MeshInstance3D.new()
	mesh_instance.name = node_name
	mesh_instance.material_override = material
	mesh_instance.visible = false
	add_child(mesh_instance)
	return mesh_instance

func _create_material(color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.albedo_color = color
	return material

func _set_cells_mesh(mesh_instance: MeshInstance3D, cells_value: Variant) -> void:
	var cells: Array[Vector2i] = []
	if cells_value is Array:
		for value in cells_value:
			if value is Vector2i:
				cells.append(value)
	if cells.is_empty():
		mesh_instance.visible = false
		return
	var vertices := PackedVector3Array()
	for cell in cells:
		if terrain.map_data.is_visual_cell_in_playable_area(cell):
			_append_cell_quad(vertices, cell)
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	mesh_instance.mesh = mesh
	mesh_instance.visible = not vertices.is_empty()

func _append_cell_quad(vertices: PackedVector3Array, cell: Vector2i) -> void:
	var a := _cell_corner(cell.x, cell.y)
	var b := _cell_corner(cell.x + 1, cell.y)
	var c := _cell_corner(cell.x + 1, cell.y + 1)
	var d := _cell_corner(cell.x, cell.y + 1)
	vertices.append(a)
	vertices.append(b)
	vertices.append(c)
	vertices.append(a)
	vertices.append(c)
	vertices.append(d)

func _cell_corner(cell_x: int, cell_z: int) -> Vector3:
	var cell_size := terrain.map_data.cell_size
	var local := Vector3(float(cell_x) * cell_size, 0.0, float(cell_z) * cell_size)
	local.y = terrain.get_height_at_local_position(local) + vertical_offset
	return local
