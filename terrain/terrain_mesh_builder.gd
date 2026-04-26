extends RefCounted
class_name TerrainMeshBuilder

static func build_chunk_mesh(map_data: TerrainMapData, chunk_coord: Vector2i) -> ArrayMesh:
	var cells_per_chunk := map_data.get_cells_per_chunk()
	var start_grid := chunk_coord * cells_per_chunk
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)

	for z in range(cells_per_chunk):
		for x in range(cells_per_chunk):
			var g00 := start_grid + Vector2i(x, z)
			var g10 := g00 + Vector2i.RIGHT
			var g01 := g00 + Vector2i.DOWN
			var g11 := g00 + Vector2i(1, 1)

			_add_vertex(st, map_data, g00)
			_add_vertex(st, map_data, g11)
			_add_vertex(st, map_data, g10)

			_add_vertex(st, map_data, g00)
			_add_vertex(st, map_data, g01)
			_add_vertex(st, map_data, g11)

	st.generate_normals()
	return st.commit()

static func _add_vertex(st: SurfaceTool, map_data: TerrainMapData, grid: Vector2i) -> void:
	var position := map_data.get_position_for_grid(grid)
	var total_size := map_data.get_total_size()
	st.set_uv(Vector2(position.x / total_size.x, position.z / total_size.y))
	st.add_vertex(position)
