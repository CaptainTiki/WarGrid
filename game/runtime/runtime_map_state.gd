extends Node
class_name RuntimeMapState

const OccupancyGridScript := preload("res://game/runtime/occupancy_grid.gd")

var terrain: Terrain = null
var map_data: TerrainMapData = null
var occupancy_grid: OccupancyGrid = OccupancyGridScript.new()

var _registered_owner_cells: Dictionary = {}

func initialize_from_map(new_map_data: TerrainMapData, new_terrain: Terrain = null) -> void:
	map_data = new_map_data
	terrain = new_terrain
	occupancy_grid.clear()
	_registered_owner_cells.clear()
	print("RuntimeMapState initialized.")

func world_to_cell(world_position: Vector3) -> Vector2i:
	if map_data == null:
		return Vector2i.ZERO
	var local := _world_to_local(world_position)
	return Vector2i(
		int(floor(local.x / map_data.cell_size)),
		int(floor(local.z / map_data.cell_size))
	)

func cell_to_world(cell: Vector2i) -> Vector3:
	if map_data == null:
		return Vector3.ZERO
	var local := Vector3(
		(float(cell.x) + 0.5) * map_data.cell_size,
		0.0,
		(float(cell.y) + 0.5) * map_data.cell_size
	)
	local.y = map_data.get_height(map_data.local_to_grid(local))
	return terrain.to_global(local) if terrain != null else local

func is_cell_base_walkable(cell: Vector2i) -> bool:
	if map_data == null:
		return false
	return map_data.get_walkable_value_for_visual_cell(cell) == TerrainMapData.Walkable.ALL

func is_cell_base_buildable(cell: Vector2i) -> bool:
	if map_data == null:
		return false
	return map_data.get_buildable_value_for_visual_cell(cell) == TerrainMapData.Buildable.OPEN

func is_cell_occupied(cell: Vector2i) -> bool:
	return occupancy_grid.is_occupied(cell)

func is_cell_effectively_walkable(cell: Vector2i) -> bool:
	return is_cell_base_walkable(cell) and not is_cell_occupied(cell)

func is_cell_effectively_buildable(cell: Vector2i) -> bool:
	return is_cell_base_buildable(cell) and not is_cell_occupied(cell)

func can_ground_unit_stand_at(world_position: Vector3, radius: float = 0.0) -> bool:
	for cell in get_circle_footprint_cells(world_position, radius):
		if not is_cell_effectively_walkable(cell):
			return false
	return true

func can_build_at_cells(cells: Array[Vector2i]) -> bool:
	for cell in cells:
		if not is_cell_effectively_buildable(cell):
			return false
	return true

func register_entity_occupancy(entity: EntityBase) -> bool:
	if entity == null or not is_instance_valid(entity):
		return false
	if not entity is BuildingBase:
		return false
	if entity.has_method("is_alive") and not entity.is_alive():
		return false
	var footprint := entity.get_footprint_component() as EntityFootprintComponent
	if footprint == null or not footprint.blocks_pathfinding:
		return false
	var cells := get_footprint_cells_for_entity(entity)
	if cells.is_empty():
		return false
	if not occupancy_grid.occupy_cells(cells, entity):
		push_warning("Failed to register occupancy for %s." % _get_entity_display_name(entity))
		return false
	_registered_owner_cells[entity.get_instance_id()] = cells
	_connect_entity_clear_signals(entity)
	print("Registered occupancy for %s: %d cells." % [_get_entity_display_name(entity), cells.size()])
	return true

func clear_entity_occupancy(entity: Node) -> void:
	if entity == null:
		return
	var owner_id := entity.get_instance_id()
	if _registered_owner_cells.has(owner_id):
		var cells: Array[Vector2i] = []
		cells.assign(_registered_owner_cells[owner_id])
		occupancy_grid.clear_cells(cells, entity)
		_registered_owner_cells.erase(owner_id)
		print("Cleared occupancy for %s." % _get_entity_display_name(entity))
	else:
		if not _has_occupancy_for_owner(entity):
			return
		occupancy_grid.clear_owner(entity)
		print("Cleared occupancy for %s." % _get_entity_display_name(entity))

func get_footprint_cells_for_entity(entity: EntityBase) -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	if entity == null:
		return cells
	var footprint := entity.get_footprint_component() as EntityFootprintComponent
	if footprint == null:
		return cells
	if footprint.shape == EntityFootprintComponent.Shape.RECTANGLE:
		return get_rectangle_footprint_cells(entity.global_position, footprint.half_extents)
	return get_circle_footprint_cells(entity.global_position, footprint.radius)

func get_circle_footprint_cells(world_position: Vector3, radius: float) -> Array[Vector2i]:
	var footprint_radius := maxf(radius, 0.0)
	var local := _world_to_local(world_position)
	var cell_size := map_data.cell_size if map_data != null else 1.0
	var min_cell := Vector2i(
		int(floor((local.x - footprint_radius) / cell_size)),
		int(floor((local.z - footprint_radius) / cell_size))
	)
	var max_cell := Vector2i(
		int(floor((local.x + footprint_radius) / cell_size)),
		int(floor((local.z + footprint_radius) / cell_size))
	)
	var cells: Array[Vector2i] = []
	for z in range(min_cell.y, max_cell.y + 1):
		for x in range(min_cell.x, max_cell.x + 1):
			var cell := Vector2i(x, z)
			if _is_visual_cell_valid(cell):
				cells.append(cell)
	return cells

func get_rectangle_footprint_cells(world_position: Vector3, half_extents: Vector2) -> Array[Vector2i]:
	var local := _world_to_local(world_position)
	var cell_size := map_data.cell_size if map_data != null else 1.0
	var min_cell := Vector2i(
		int(floor((local.x - half_extents.x) / cell_size)),
		int(floor((local.z - half_extents.y) / cell_size))
	)
	var max_cell := Vector2i(
		int(floor((local.x + half_extents.x) / cell_size)),
		int(floor((local.z + half_extents.y) / cell_size))
	)
	var cells: Array[Vector2i] = []
	for z in range(min_cell.y, max_cell.y + 1):
		for x in range(min_cell.x, max_cell.x + 1):
			var cell := Vector2i(x, z)
			if _is_visual_cell_valid(cell):
				cells.append(cell)
	return cells

func _connect_entity_clear_signals(entity: EntityBase) -> void:
	if not entity.tree_exiting.is_connected(_on_registered_entity_tree_exiting.bind(entity)):
		entity.tree_exiting.connect(_on_registered_entity_tree_exiting.bind(entity))
	var health := entity.get_health_component() as HealthComponent
	if health != null and not health.died.is_connected(_on_registered_entity_died.bind(entity)):
		health.died.connect(_on_registered_entity_died.bind(entity))

func _has_occupancy_for_owner(owner: Node) -> bool:
	for cell in occupancy_grid.occupied_cells.keys():
		if occupancy_grid.get_owner(cell) == owner:
			return true
	return false

func _on_registered_entity_tree_exiting(entity: Node) -> void:
	clear_entity_occupancy(entity)

func _on_registered_entity_died(entity: Node) -> void:
	clear_entity_occupancy(entity)

func _world_to_local(world_position: Vector3) -> Vector3:
	return terrain.to_local(world_position) if terrain != null else world_position

func _is_visual_cell_valid(cell: Vector2i) -> bool:
	if map_data == null:
		return false
	var total_cells := map_data.get_total_cell_count()
	return cell.x >= 0 and cell.y >= 0 and cell.x < total_cells.x and cell.y < total_cells.y

func _get_entity_display_name(entity: Node) -> String:
	if entity != null and "display_name" in entity and entity.display_name.strip_edges() != "":
		return entity.display_name
	return entity.name if entity != null else "Unknown Entity"
