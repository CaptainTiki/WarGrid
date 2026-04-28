class_name TerrainPaintBrushes

static func apply_material(map_data: TerrainMapData, local_center: Vector3, radius: float, strength: float, falloff_power: float, selected_channel: int) -> Array[Vector2i]:
	if map_data.splat_map == null:
		map_data.create_default_splat_map()

	var dirty_chunks: Array[Vector2i] = []
	var dirty_lookup := {}
	var radius_cells := int(ceil(radius / map_data.cell_size))
	var center_pixel := map_data.local_to_splat_pixel(local_center)
	var radius_squared := radius * radius
	var channel := clampi(selected_channel, 0, TerrainMapData.SPLAT_CHANNEL_COUNT - 1)
	var paint_strength := clampf(strength, 0.0, 1.0)
	var image_size := map_data.get_splat_map_size()

	for z in range(center_pixel.y - radius_cells, center_pixel.y + radius_cells + 1):
		if z < 0 or z >= image_size.y:
			continue
		for x in range(center_pixel.x - radius_cells, center_pixel.x + radius_cells + 1):
			if x < 0 or x >= image_size.x:
				continue

			var point_x := (float(x) + 0.5) * map_data.cell_size
			var point_z := (float(z) + 0.5) * map_data.cell_size
			var distance_squared := Vector2(point_x, point_z).distance_squared_to(Vector2(local_center.x, local_center.z))
			if distance_squared > radius_squared:
				continue

			var normalized_falloff : float = 1.0 - sqrt(distance_squared) / max(radius, 0.001)
			var shaped_falloff := pow(smoothstep(0.0, 1.0, normalized_falloff), falloff_power)
			var blend_amount := clampf(paint_strength * shaped_falloff, 0.0, 1.0)
			var weights := _color_to_weights(map_data.splat_map.get_pixel(x, z))
			for i in weights.size():
				weights[i] = lerpf(weights[i], 1.0 if i == channel else 0.0, blend_amount)
			_normalize_weights(weights)
			map_data.splat_map.set_pixel(x, z, Color(weights[0], weights[1], weights[2], weights[3]))
			map_data.add_dirty_chunks_for_grid(Vector2i(x, z), dirty_chunks, dirty_lookup)

	return dirty_chunks


static func apply_walkable(map_data: TerrainMapData, local_center: Vector3, radius: float, walkable_value: int) -> Array[Vector2i]:
	var dirty_chunks: Array[Vector2i] = []
	var dirty_lookup := {}
	var radius_cells := int(ceil(radius / map_data.cell_size))
	var center_cell := map_data.local_to_splat_pixel(local_center)
	var radius_squared := radius * radius
	var value := clampi(walkable_value, TerrainMapData.Walkable.ALL, TerrainMapData.Walkable.NONE)
	var playable_min: Vector2i = map_data.get_playable_cell_min()
	var playable_max: Vector2i = map_data.get_playable_cell_max_exclusive()

	for z in range(center_cell.y - radius_cells, center_cell.y + radius_cells + 1):
		if z < playable_min.y or z >= playable_max.y:
			continue
		for x in range(center_cell.x - radius_cells, center_cell.x + radius_cells + 1):
			if x < playable_min.x or x >= playable_max.x:
				continue

			var point_x := (float(x) + 0.5) * map_data.cell_size
			var point_z := (float(z) + 0.5) * map_data.cell_size
			var distance_squared := Vector2(point_x, point_z).distance_squared_to(Vector2(local_center.x, local_center.z))
			if distance_squared > radius_squared:
				continue

			var index: int = map_data.playable_index_for_visual_cell(Vector2i(x, z))
			if index < 0 or index >= map_data.walkable_data.size():
				continue
			map_data.walkable_data[index] = value
			map_data.add_dirty_chunks_for_grid(Vector2i(x, z), dirty_chunks, dirty_lookup)

	return dirty_chunks


static func apply_buildable(map_data: TerrainMapData, local_center: Vector3, radius: float, buildable_value: int) -> Array[Vector2i]:
	var dirty_chunks: Array[Vector2i] = []
	var dirty_lookup := {}
	var radius_cells := int(ceil(radius / map_data.cell_size))
	var center_cell := map_data.local_to_splat_pixel(local_center)
	var radius_squared := radius * radius
	var value := clampi(buildable_value, TerrainMapData.Buildable.OPEN, TerrainMapData.Buildable.BLOCKED)
	var playable_min: Vector2i = map_data.get_playable_cell_min()
	var playable_max: Vector2i = map_data.get_playable_cell_max_exclusive()

	for z in range(center_cell.y - radius_cells, center_cell.y + radius_cells + 1):
		if z < playable_min.y or z >= playable_max.y:
			continue
		for x in range(center_cell.x - radius_cells, center_cell.x + radius_cells + 1):
			if x < playable_min.x or x >= playable_max.x:
				continue

			var point_x := (float(x) + 0.5) * map_data.cell_size
			var point_z := (float(z) + 0.5) * map_data.cell_size
			var distance_squared := Vector2(point_x, point_z).distance_squared_to(Vector2(local_center.x, local_center.z))
			if distance_squared > radius_squared:
				continue

			var index: int = map_data.playable_index_for_visual_cell(Vector2i(x, z))
			if index < 0 or index >= map_data.buildable_data.size():
				continue
			map_data.buildable_data[index] = value
			map_data.add_dirty_chunks_for_grid(Vector2i(x, z), dirty_chunks, dirty_lookup)

	return dirty_chunks


static func apply_fow_height(map_data: TerrainMapData, local_center: Vector3, radius: float, fow_height: int) -> Array[Vector2i]:
	var dirty_chunks: Array[Vector2i] = []
	var dirty_lookup := {}
	var radius_cells := int(ceil(radius / map_data.cell_size))
	var center_cell := map_data.local_to_splat_pixel(local_center)
	var radius_squared := radius * radius
	var value := clampi(fow_height, 0, 3)
	var playable_min: Vector2i = map_data.get_playable_cell_min()
	var playable_max: Vector2i = map_data.get_playable_cell_max_exclusive()

	for z in range(center_cell.y - radius_cells, center_cell.y + radius_cells + 1):
		if z < playable_min.y or z >= playable_max.y:
			continue
		for x in range(center_cell.x - radius_cells, center_cell.x + radius_cells + 1):
			if x < playable_min.x or x >= playable_max.x:
				continue

			var point_x := (float(x) + 0.5) * map_data.cell_size
			var point_z := (float(z) + 0.5) * map_data.cell_size
			var distance_squared := Vector2(point_x, point_z).distance_squared_to(Vector2(local_center.x, local_center.z))
			if distance_squared > radius_squared:
				continue

			var index: int = map_data.playable_index_for_visual_cell(Vector2i(x, z))
			if index < 0 or index >= map_data.fow_height_data.size():
				continue
			map_data.fow_height_data[index] = value
			map_data.add_dirty_chunks_for_grid(Vector2i(x, z), dirty_chunks, dirty_lookup)

	return dirty_chunks


static func _color_to_weights(color: Color) -> Array[float]:
	return [color.r, color.g, color.b, color.a]


static func _normalize_weights(weights: Array[float]) -> void:
	var total := 0.0
	for i in weights.size():
		weights[i] = maxf(weights[i], 0.0)
		total += weights[i]
	if total <= 0.0001:
		weights[0] = 1.0
		weights[1] = 0.0
		weights[2] = 0.0
		weights[3] = 0.0
		return
	for i in weights.size():
		weights[i] /= total
