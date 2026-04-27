extends RefCounted
class_name TerrainOverlayMeshBuilder

const OVERLAY_ALPHA := 45.0 / 255.0

static func build_chunk_overlay_mesh(map_data: TerrainMapData, chunk_coord: Vector2i, overlay_mode: int, normal_offset: float) -> ArrayMesh:
	var mesh := ArrayMesh.new()
	if map_data == null or overlay_mode == TerrainMapData.OverlayMode.NONE:
		return mesh

	var cells_per_chunk: int = map_data.get_cells_per_chunk()
	var chunk_start_x: int = chunk_coord.x * cells_per_chunk
	var chunk_start_z: int = chunk_coord.y * cells_per_chunk
	var chunk_end_x: int = chunk_start_x + cells_per_chunk
	var chunk_end_z: int = chunk_start_z + cells_per_chunk
	var playable_min: Vector2i = map_data.get_playable_cell_min()
	var playable_max: Vector2i = map_data.get_playable_cell_max_exclusive()
	var start_x: int = maxi(chunk_start_x, playable_min.x)
	var start_z: int = maxi(chunk_start_z, playable_min.y)
	var end_x: int = mini(chunk_end_x, playable_max.x)
	var end_z: int = mini(chunk_end_z, playable_max.y)
	if start_x >= end_x or start_z >= end_z:
		return mesh

	var cell_count: int = (end_x - start_x) * (end_z - start_z)
	var vertices := PackedVector3Array()
	var normals := PackedVector3Array()
	var colors := PackedColorArray()
	var indices := PackedInt32Array()
	vertices.resize(cell_count * 4)
	normals.resize(cell_count * 4)
	colors.resize(cell_count * 4)
	indices.resize(cell_count * 6)

	var vertex_write: int = 0
	var index_write: int = 0
	for z in range(start_z, end_z):
		for x in range(start_x, end_x):
			var cell_color: Color = _get_overlay_color(map_data, Vector2i(x, z), overlay_mode)
			var grid_00 := Vector2i(x, z)
			var grid_10 := Vector2i(x + 1, z)
			var grid_01 := Vector2i(x, z + 1)
			var grid_11 := Vector2i(x + 1, z + 1)
			_write_vertex(map_data, grid_00, normal_offset, vertex_write, vertices, normals)
			_write_vertex(map_data, grid_10, normal_offset, vertex_write + 1, vertices, normals)
			_write_vertex(map_data, grid_11, normal_offset, vertex_write + 2, vertices, normals)
			_write_vertex(map_data, grid_01, normal_offset, vertex_write + 3, vertices, normals)
			for i in range(4):
				colors[vertex_write + i] = cell_color

			indices[index_write] = vertex_write
			indices[index_write + 1] = vertex_write + 1
			indices[index_write + 2] = vertex_write + 2
			indices[index_write + 3] = vertex_write
			indices[index_write + 4] = vertex_write + 2
			indices[index_write + 5] = vertex_write + 3
			vertex_write += 4
			index_write += 6

	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_COLOR] = colors
	arrays[Mesh.ARRAY_INDEX] = indices
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh

static func _write_vertex(
		map_data: TerrainMapData,
		grid: Vector2i,
		normal_offset: float,
		write_index: int,
		vertices: PackedVector3Array,
		normals: PackedVector3Array
) -> void:
	var normal: Vector3 = _get_grid_normal(map_data, grid)
	normals[write_index] = normal
	vertices[write_index] = map_data.get_position_for_grid(grid) + normal * normal_offset

static func _get_grid_normal(map_data: TerrainMapData, grid: Vector2i) -> Vector3:
	var left: float = map_data.get_height_at(grid.x - 1, grid.y)
	var right: float = map_data.get_height_at(grid.x + 1, grid.y)
	var down: float = map_data.get_height_at(grid.x, grid.y + 1)
	var up: float = map_data.get_height_at(grid.x, grid.y - 1)
	return Vector3(left - right, map_data.cell_size * 2.0, up - down).normalized()

static func _get_overlay_color(map_data: TerrainMapData, visual_cell: Vector2i, overlay_mode: int) -> Color:
	match overlay_mode:
		TerrainMapData.OverlayMode.WALKABLE:
			return _get_walkable_color(map_data.get_walkable_value_for_visual_cell(visual_cell))
		TerrainMapData.OverlayMode.BUILDABLE:
			return _get_buildable_color(map_data.get_buildable_value_for_visual_cell(visual_cell))
		TerrainMapData.OverlayMode.FOW_HEIGHT:
			return _get_fow_height_color(map_data.get_fow_height_value_for_visual_cell(visual_cell))
		_:
			return Color(0.0, 0.0, 0.0, 0.0)

static func _get_walkable_color(value: int) -> Color:
	match value:
		TerrainMapData.Walkable.ALL:
			return Color(1.0, 1.0, 1.0, OVERLAY_ALPHA)
		TerrainMapData.Walkable.AIR:
			return Color(0.1, 0.45, 1.0, OVERLAY_ALPHA)
		TerrainMapData.Walkable.NONE:
			return Color(0.0, 0.0, 0.0, OVERLAY_ALPHA)
		_:
			return Color(1.0, 0.0, 1.0, OVERLAY_ALPHA)

static func _get_buildable_color(value: int) -> Color:
	match value:
		TerrainMapData.Buildable.OPEN:
			return Color(0.2, 1.0, 0.25, OVERLAY_ALPHA)
		TerrainMapData.Buildable.BLOCKED:
			return Color(1.0, 0.0, 0.0, OVERLAY_ALPHA)
		_:
			return Color(1.0, 0.0, 1.0, OVERLAY_ALPHA)

static func _get_fow_height_color(value: int) -> Color:
	match clampi(value, 0, 3):
		0:
			return Color(0.05, 0.05, 0.08, OVERLAY_ALPHA)
		1:
			return Color(0.15, 0.35, 0.8, OVERLAY_ALPHA)
		2:
			return Color(0.3, 0.8, 0.45, OVERLAY_ALPHA)
		3:
			return Color(1.0, 0.95, 0.35, OVERLAY_ALPHA)
		_:
			return Color(1.0, 1.0, 1.0, OVERLAY_ALPHA)
