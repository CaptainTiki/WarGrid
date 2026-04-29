class_name TerrainSerializer

static func save(map_data: TerrainMapData, path: String, map_name: String = "Authored Map") -> bool:
	if map_data == null:
		push_error("Cannot save: map_data is null")
		return false

	var resource := TerrainMapResource.new()
	resource.map_name = map_name
	resource.chunk_size_meters = map_data.chunk_size_meters
	resource.cell_size = map_data.cell_size
	resource.playable_chunks = map_data.playable_chunks
	resource.border_chunks = map_data.border_chunks
	resource.base_heights = map_data.base_heights.duplicate()
	if map_data.splat_map != null:
		resource.splat_map = map_data.splat_map.duplicate()
	resource.walkable_data = map_data.walkable_data.duplicate()
	resource.buildable_data = map_data.buildable_data.duplicate()
	resource.fow_height_data = map_data.fow_height_data.duplicate()
	resource.entity_placements = map_data.entity_placements.duplicate()

	var error := ResourceSaver.save(resource, path)
	if error == OK:
		print("Map saved: %s" % path)
		return true
	else:
		push_error("Failed to save map: error code %d" % error)
		return false

static func load(path: String) -> TerrainMapData:
	var resource := ResourceLoader.load(path) as TerrainMapResource
	if resource == null:
		push_error("Failed to load map from: %s" % path)
		return null

	var map_data := TerrainMapData.new()
	map_data.chunk_size_meters = resource.chunk_size_meters
	map_data.cell_size = resource.cell_size
	map_data.playable_chunks = resource.playable_chunks
	map_data.border_chunks = resource.border_chunks
	map_data.refresh_cached_sizes()

	map_data.base_heights = resource.base_heights.duplicate()
	map_data.entity_placements = resource.entity_placements.duplicate()
	map_data.material_ids.resize(map_data.get_total_cell_count().x * map_data.get_total_cell_count().y)
	for i in map_data.material_ids.size():
		map_data.material_ids[i] = TerrainMapData.GRASS_MATERIAL_ID

	if resource.splat_map != null:
		map_data.splat_map = resource.splat_map.duplicate()
	else:
		var size := map_data.get_total_cell_count()
		map_data.splat_map = Image.create(size.x, size.y, false, Image.FORMAT_RGBA8)
		map_data.splat_map.fill(Color(1.0, 0.0, 0.0, 0.0))

	_restore_or_default_gameplay_data(map_data, resource)

	print("Map loaded: %s" % path)
	return map_data

static func _restore_or_default_gameplay_data(map_data: TerrainMapData, resource: TerrainMapResource) -> void:
	var playable_cells: Vector2i = map_data.get_playable_cell_count()
	var cell_count: int = playable_cells.x * playable_cells.y

	if resource.walkable_data.size() == cell_count:
		map_data.walkable_data = resource.walkable_data.duplicate()
	else:
		map_data.walkable_data.resize(cell_count)
		for i in range(cell_count):
			map_data.walkable_data[i] = TerrainMapData.Walkable.ALL

	if resource.buildable_data.size() == cell_count:
		map_data.buildable_data = resource.buildable_data.duplicate()
	else:
		map_data.buildable_data.resize(cell_count)
		for i in range(cell_count):
			map_data.buildable_data[i] = TerrainMapData.Buildable.OPEN

	if resource.fow_height_data.size() == cell_count:
		map_data.fow_height_data = resource.fow_height_data.duplicate()
	else:
		map_data.fow_height_data.resize(cell_count)
		for i in range(cell_count):
			map_data.fow_height_data[i] = 0
