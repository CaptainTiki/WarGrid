extends RefCounted
class_name TerrainMeshBuilder

static func build_chunk_mesh(map_data: TerrainMapData, chunk_coord: Vector2i, pretty_normals: bool = false) -> ArrayMesh:
	var profile_start := TerrainProfiler.begin()
	var cells_per_chunk := map_data.get_cells_per_chunk()
	var start_x := chunk_coord.x * cells_per_chunk
	var start_z := chunk_coord.y * cells_per_chunk
	var vertices_per_side := cells_per_chunk + 1
	var vertex_count := vertices_per_side * vertices_per_side
	var index_count := cells_per_chunk * cells_per_chunk * 6
	var cell_size := map_data.cell_size
	var total_cell_count := map_data.get_total_cell_count()
	var total_vertex_width := total_cell_count.x + 1
	var total_vertex_height := total_cell_count.y + 1
	var total_size_x := float(total_cell_count.x) * cell_size
	var total_size_z := float(total_cell_count.y) * cell_size
	var heights := map_data.base_heights
	var default_height := map_data.default_height
	var vertices := PackedVector3Array()
	var normals := PackedVector3Array()
	var uvs := PackedVector2Array()
	var indices := PackedInt32Array()
	vertices.resize(vertex_count)
	normals.resize(vertex_count)
	uvs.resize(vertex_count)
	indices.resize(index_count)

	var vertex_write := 0
	for z in range(vertices_per_side):
		var grid_z := start_z + z
		var world_z := float(grid_z) * cell_size
		for x in range(vertices_per_side):
			var grid_x := start_x + x
			var world_x := float(grid_x) * cell_size
			var height := heights[grid_z * total_vertex_width + grid_x]
			vertices[vertex_write] = Vector3(world_x, height, world_z)
			if pretty_normals:
				normals[vertex_write] = _get_grid_normal(
					heights,
					total_vertex_width,
					total_vertex_height,
					grid_x,
					grid_z,
					default_height,
					cell_size
				)
			else:
				normals[vertex_write] = Vector3.UP
			uvs[vertex_write] = Vector2(world_x / total_size_x, world_z / total_size_z)
			vertex_write += 1

	var index_write := 0
	for z in range(cells_per_chunk):
		for x in range(cells_per_chunk):
			var i00 := z * vertices_per_side + x
			var i10 := i00 + 1
			var i01 := i00 + vertices_per_side
			var i11 := i01 + 1

			indices[index_write] = i00
			indices[index_write + 1] = i10
			indices[index_write + 2] = i11
			indices[index_write + 3] = i00
			indices[index_write + 4] = i11
			indices[index_write + 5] = i01
			index_write += 6

	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_INDEX] = indices

	var mesh := ArrayMesh.new()
	var add_surface_start := TerrainProfiler.begin()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	TerrainProfiler.log_timing(
		"ArrayMesh.add_surface_from_arrays",
		add_surface_start,
		"chunk=%s vertices=%d indices=%d surfaces=%d" % [chunk_coord, vertex_count, index_count, mesh.get_surface_count()]
	)
	TerrainProfiler.log_timing(
		"TerrainMeshBuilder.build_chunk_mesh",
		profile_start,
		"chunk=%s pretty=%s cells=%d vertices=%d triangles=%d" % [
			chunk_coord,
			pretty_normals,
			cells_per_chunk,
			vertex_count,
			cells_per_chunk * cells_per_chunk * 2,
		]
	)
	return mesh

static func _get_grid_normal(
		heights: PackedFloat32Array,
		vertex_width: int,
		vertex_height: int,
		x: int,
		z: int,
		default_height: float,
		cell_size: float
) -> Vector3:
	var left := _height_at(heights, vertex_width, vertex_height, x - 1, z, default_height)
	var right := _height_at(heights, vertex_width, vertex_height, x + 1, z, default_height)
	var down := _height_at(heights, vertex_width, vertex_height, x, z + 1, default_height)
	var up := _height_at(heights, vertex_width, vertex_height, x, z - 1, default_height)
	return Vector3(left - right, cell_size * 2.0, up - down).normalized()

static func _height_at(
		heights: PackedFloat32Array,
		vertex_width: int,
		vertex_height: int,
		x: int,
		z: int,
		default_height: float
) -> float:
	if x < 0 or z < 0 or x >= vertex_width or z >= vertex_height:
		return default_height
	return heights[z * vertex_width + x]
