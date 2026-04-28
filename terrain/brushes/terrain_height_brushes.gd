class_name TerrainHeightBrushes

static func apply_height(map_data: TerrainMapData, local_center: Vector3, radius: float, amount: float, falloff_power: float = 1.0) -> Array[Vector2i]:
	var profile_start := TerrainProfiler.begin()
	var dirty_chunks: Array[Vector2i] = []
	var dirty_lookup := {}
	var radius_cells := int(ceil(radius / map_data.cell_size))
	var center_grid := map_data.local_to_grid(local_center)
	var radius_squared := radius * radius
	var modified_points := 0

	for z in range(center_grid.y - radius_cells, center_grid.y + radius_cells + 1):
		for x in range(center_grid.x - radius_cells, center_grid.x + radius_cells + 1):
			var grid := Vector2i(x, z)
			if not map_data.is_grid_point_valid(grid):
				continue

			var point_x := float(x) * map_data.cell_size
			var point_z := float(z) * map_data.cell_size
			var distance_squared := Vector2(point_x, point_z).distance_squared_to(Vector2(local_center.x, local_center.z))
			if distance_squared > radius_squared:
				continue

			var normalized_falloff : float = 1.0 - sqrt(distance_squared) / max(radius, 0.001)
			var shaped_falloff := pow(smoothstep(0.0, 1.0, normalized_falloff), falloff_power)
			map_data.set_height(grid, map_data.get_height(grid) + amount * shaped_falloff)
			modified_points += 1
			map_data.add_dirty_chunks_for_grid(grid, dirty_chunks, dirty_lookup)

	TerrainProfiler.log_timing(
		"TerrainHeightBrushes.apply_height",
		profile_start,
		"center=%s radius=%.2f amount=%.3f falloff=%.2f points=%d dirty_chunks=%d" % [
			local_center, radius, amount, falloff_power, modified_points, dirty_chunks.size(),
		]
	)
	return dirty_chunks


static func apply_smooth(map_data: TerrainMapData, local_center: Vector3, radius: float, strength: float, falloff_power: float = 1.0) -> Array[Vector2i]:
	var profile_start := TerrainProfiler.begin()
	var dirty_chunks: Array[Vector2i] = []
	var dirty_lookup := {}
	var radius_cells := int(ceil(radius / map_data.cell_size))
	var center_grid := map_data.local_to_grid(local_center)
	var radius_squared := radius * radius
	var modified_points := 0
	var center_x := local_center.x
	var center_z := local_center.z
	var height_updates := {}

	for z in range(center_grid.y - radius_cells, center_grid.y + radius_cells + 1):
		for x in range(center_grid.x - radius_cells, center_grid.x + radius_cells + 1):
			var grid := Vector2i(x, z)
			if not map_data.is_grid_point_valid(grid):
				continue

			var point_x := float(x) * map_data.cell_size
			var point_z := float(z) * map_data.cell_size
			var distance_squared := (point_x - center_x) * (point_x - center_x) + (point_z - center_z) * (point_z - center_z)
			if distance_squared > radius_squared:
				continue

			var kernel_sum := 0.0
			var kernel_count := 0
			for kz in range(-1, 2):
				for kx in range(-1, 2):
					var kernel_grid := Vector2i(x + kx, z + kz)
					if map_data.is_grid_point_valid(kernel_grid):
						kernel_sum += map_data.get_height(kernel_grid)
						kernel_count += 1

			if kernel_count == 0:
				continue

			var normalized_falloff : float = 1.0 - sqrt(distance_squared) / max(radius, 0.001)
			var shaped_falloff := pow(smoothstep(0.0, 1.0, normalized_falloff), falloff_power)
			var new_height : float = lerp(map_data.get_height(grid), kernel_sum / float(kernel_count), strength * shaped_falloff)
			height_updates[grid] = new_height
			modified_points += 1

	for grid in height_updates.keys():
		map_data.set_height(grid, height_updates[grid])
		map_data.add_dirty_chunks_for_grid(grid, dirty_chunks, dirty_lookup)

	TerrainProfiler.log_timing(
		"TerrainHeightBrushes.apply_smooth",
		profile_start,
		"center=%s radius=%.2f strength=%.3f falloff=%.2f points=%d dirty_chunks=%d" % [
			local_center, radius, strength, falloff_power, modified_points, dirty_chunks.size(),
		]
	)
	return dirty_chunks


static func apply_flatten(map_data: TerrainMapData, local_center: Vector3, radius: float, strength: float, falloff_power: float, target_height: float) -> Array[Vector2i]:
	var profile_start := TerrainProfiler.begin()
	var dirty_chunks: Array[Vector2i] = []
	var dirty_lookup := {}
	var radius_cells := int(ceil(radius / map_data.cell_size))
	var center_grid := map_data.local_to_grid(local_center)
	var radius_squared := radius * radius
	var modified_points := 0
	var center_x := local_center.x
	var center_z := local_center.z

	for z in range(center_grid.y - radius_cells, center_grid.y + radius_cells + 1):
		for x in range(center_grid.x - radius_cells, center_grid.x + radius_cells + 1):
			var grid := Vector2i(x, z)
			if not map_data.is_grid_point_valid(grid):
				continue

			var point_x := float(x) * map_data.cell_size
			var point_z := float(z) * map_data.cell_size
			var distance_squared := (point_x - center_x) * (point_x - center_x) + (point_z - center_z) * (point_z - center_z)
			if distance_squared > radius_squared:
				continue

			var normalized_falloff : float = 1.0 - sqrt(distance_squared) / max(radius, 0.001)
			var shaped_falloff := pow(smoothstep(0.0, 1.0, normalized_falloff), falloff_power)
			var new_height : float = lerp(map_data.get_height(grid), target_height, strength * shaped_falloff)
			map_data.set_height(grid, new_height)
			modified_points += 1
			map_data.add_dirty_chunks_for_grid(grid, dirty_chunks, dirty_lookup)

	TerrainProfiler.log_timing(
		"TerrainHeightBrushes.apply_flatten",
		profile_start,
		"center=%s radius=%.2f strength=%.3f falloff=%.2f target=%.2f points=%d dirty_chunks=%d" % [
			local_center, radius, strength, falloff_power, target_height, modified_points, dirty_chunks.size(),
		]
	)
	return dirty_chunks
