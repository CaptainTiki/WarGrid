extends Node3D
class_name EditorGridOverlay

@export var radius_cells := 12
@export var vertical_offset := 0.06

var terrain: Terrain
var _mesh_instance: MeshInstance3D
var _enabled := false
var _hover_cell := Vector2i(-999999, -999999)

func _ready() -> void:
	_ensure_mesh_instance()

func setup(terrain_ref: Terrain) -> void:
	terrain = terrain_ref
	_ensure_mesh_instance()
	hide_grid()

func set_enabled(enabled: bool) -> void:
	_enabled = enabled
	if not _enabled:
		hide_grid()
		return
	rebuild()

func set_hover_position(local_position: Vector3) -> void:
	if terrain == null or terrain.map_data == null:
		hide_grid()
		return
	set_hover_cell(terrain.get_visual_cell_from_local_position(local_position))

func set_hover_cell(cell: Vector2i) -> void:
	if terrain == null or terrain.map_data == null or not terrain.map_data.is_visual_cell_in_playable_area(cell):
		hide_grid()
		return
	if cell == _hover_cell and _mesh_instance != null and _mesh_instance.visible:
		return
	_hover_cell = cell
	rebuild()

func set_radius_cells(radius: int) -> void:
	radius_cells = maxi(radius, 1)
	rebuild()

func rebuild() -> void:
	_ensure_mesh_instance()
	if not _enabled or terrain == null or terrain.map_data == null:
		hide_grid()
		return
	if not terrain.map_data.is_visual_cell_in_playable_area(_hover_cell):
		hide_grid()
		return

	var playable_min := terrain.map_data.get_playable_cell_min()
	var playable_max := terrain.map_data.get_playable_cell_max_exclusive()
	var min_cell := Vector2i(
		maxi(_hover_cell.x - radius_cells, playable_min.x),
		maxi(_hover_cell.y - radius_cells, playable_min.y)
	)
	var max_cell_exclusive := Vector2i(
		mini(_hover_cell.x + radius_cells + 1, playable_max.x),
		mini(_hover_cell.y + radius_cells + 1, playable_max.y)
	)
	var vertices := PackedVector3Array()
	for x in range(min_cell.x, max_cell_exclusive.x + 1):
		vertices.append(_grid_vertex(x, min_cell.y))
		vertices.append(_grid_vertex(x, max_cell_exclusive.y))
	for z in range(min_cell.y, max_cell_exclusive.y + 1):
		vertices.append(_grid_vertex(min_cell.x, z))
		vertices.append(_grid_vertex(max_cell_exclusive.x, z))

	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_LINES, arrays)
	_mesh_instance.mesh = mesh
	_mesh_instance.visible = true

func hide_grid() -> void:
	if _mesh_instance != null:
		_mesh_instance.visible = false

func _ensure_mesh_instance() -> void:
	if _mesh_instance != null:
		return
	_mesh_instance = MeshInstance3D.new()
	_mesh_instance.name = "GridMesh"
	_mesh_instance.material_override = _create_material()
	add_child(_mesh_instance)

func _grid_vertex(cell_x: int, cell_z: int) -> Vector3:
	var cell_size := terrain.map_data.cell_size
	var local := Vector3(float(cell_x) * cell_size, 0.0, float(cell_z) * cell_size)
	local.y = terrain.get_height_at_local_position(local) + vertical_offset
	return local

func _create_material() -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.albedo_color = Color(0.55, 0.9, 1.0, 0.32)
	return material
