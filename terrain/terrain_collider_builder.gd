extends RefCounted
class_name TerrainColliderBuilder

static func build_playable_collision_shape(map_data: TerrainMapData) -> ConcavePolygonShape3D:
	var playable_min := map_data.get_playable_min()
	var playable_max := map_data.get_playable_max()
	var min_grid := Vector2i(
		int(round(playable_min.x / map_data.cell_size)),
		int(round(playable_min.y / map_data.cell_size))
	)
	var max_grid := Vector2i(
		int(round(playable_max.x / map_data.cell_size)),
		int(round(playable_max.y / map_data.cell_size))
	)
	var triangles := PackedVector3Array()

	for z in range(min_grid.y, max_grid.y):
		for x in range(min_grid.x, max_grid.x):
			var g00 := Vector2i(x, z)
			var g10 := g00 + Vector2i.RIGHT
			var g01 := g00 + Vector2i.DOWN
			var g11 := g00 + Vector2i(1, 1)

			triangles.append(map_data.get_position_for_grid(g00))
			triangles.append(map_data.get_position_for_grid(g11))
			triangles.append(map_data.get_position_for_grid(g10))

			triangles.append(map_data.get_position_for_grid(g00))
			triangles.append(map_data.get_position_for_grid(g01))
			triangles.append(map_data.get_position_for_grid(g11))

	var shape := ConcavePolygonShape3D.new()
	shape.set_faces(triangles)
	return shape
