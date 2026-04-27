extends RefCounted
class_name TerrainColliderBuilder

static func build_chunk_collision_shape(map_data: TerrainMapData, chunk_coord: Vector2i) -> ConcavePolygonShape3D:
	var profile_start := TerrainProfiler.begin()
	var cells_per_chunk := map_data.get_cells_per_chunk()
	var start_x := chunk_coord.x * cells_per_chunk
	var start_z := chunk_coord.y * cells_per_chunk
	var max_x := start_x + cells_per_chunk
	var max_z := start_z + cells_per_chunk
	var cell_size := map_data.cell_size
	var vertex_width := map_data.get_vertex_count().x
	var heights := map_data.base_heights
	var triangles := PackedVector3Array()
	triangles.resize(cells_per_chunk * cells_per_chunk * 6)
	var write_index := 0

	for z in range(start_z, max_z):
		var z0 := float(z) * cell_size
		var z1 := float(z + 1) * cell_size
		var row := z * vertex_width
		var next_row := (z + 1) * vertex_width
		for x in range(start_x, max_x):
			var x0 := float(x) * cell_size
			var x1 := float(x + 1) * cell_size
			var h00 := heights[row + x]
			var h10 := heights[row + x + 1]
			var h01 := heights[next_row + x]
			var h11 := heights[next_row + x + 1]
			triangles[write_index] = Vector3(x0, h00, z0)
			triangles[write_index + 1] = Vector3(x1, h10, z0)
			triangles[write_index + 2] = Vector3(x1, h11, z1)
			triangles[write_index + 3] = triangles[write_index]
			triangles[write_index + 4] = triangles[write_index + 2]
			triangles[write_index + 5] = Vector3(x0, h01, z1)
			write_index += 6

	var shape := ConcavePolygonShape3D.new()
	var set_faces_start := TerrainProfiler.begin()
	shape.set_faces(triangles)
	TerrainProfiler.log_timing(
		"ConcavePolygonShape3D.set_faces",
		set_faces_start,
		"chunk=%s faces=%d vertices=%d" % [chunk_coord, triangles.size() / 3, triangles.size()]
	)
	TerrainProfiler.log_timing(
		"TerrainColliderBuilder.build_chunk_collision_shape",
		profile_start,
		"chunk=%s cells=%d faces=%d" % [chunk_coord, cells_per_chunk, triangles.size() / 3]
	)
	return shape
