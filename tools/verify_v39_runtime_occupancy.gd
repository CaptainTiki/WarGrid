extends SceneTree

const LevelScene := preload("res://level/level.tscn")
const TerrainMapDataScript := preload("res://terrain/terrain_map_data.gd")
const TerrainSerializerScript := preload("res://terrain/terrain_serializer.gd")
const EntityPlacementDataScript := preload("res://game/entities/placement/entity_placement_data.gd")
const MovementQueryScript := preload("res://game/entities/movement/movement_query.gd")

const TEMP_MAP_PATH := "res://tools/v39_runtime_occupancy_temp.res"

var _failures := 0
var _ran := false

func _process(_delta: float) -> bool:
	if _ran:
		return false
	_ran = true
	_run()
	return true

func _run() -> void:
	var wallet := root.get_node_or_null("ResourceManager")
	if wallet != null:
		wallet.reset_to_starting_resources()

	var map_data = TerrainMapDataScript.new()
	map_data.create_flat_grass_map(Vector2i(2, 2), 0.0)
	map_data.entity_placements = [
		_make_placement(&"infantry", Vector3(88.0, 0.0, 96.0), 1),
		_make_placement(&"test_hq", Vector3(96.0, 0.0, 96.0), 1),
		_make_placement(&"enemy_test_hq", Vector3(112.0, 0.0, 96.0), 2),
	]
	var base_walkable := map_data.walkable_data.duplicate()
	var base_buildable := map_data.buildable_data.duplicate()
	_expect(TerrainSerializerScript.save(map_data, TEMP_MAP_PATH, "v39 Runtime Occupancy"), "temporary map saves")

	var level := LevelScene.instantiate() as Level
	root.add_child(level)
	_expect(level.load_map(TEMP_MAP_PATH), "level loads temporary map")
	var state := level.runtime_map_state
	var entities_root: Node = level.get_node("Entities")
	var infantry := _find_child_by_name(entities_root, "Infantry") as EntityBase
	var hq := _find_child_by_name(entities_root, "TestHQ") as EntityBase
	var enemy_hq := _find_child_by_name(entities_root, "EnemyHQ") as EntityBase
	if enemy_hq == null:
		enemy_hq = _find_display_name(entities_root, "Enemy Test HQ")

	_expect(state != null, "RuntimeMapState exists")
	_expect(infantry != null, "infantry spawned")
	_expect(hq != null, "player HQ spawned")
	_expect(enemy_hq != null, "enemy HQ spawned")
	_expect(level.terrain.map_data.walkable_data == base_walkable, "runtime occupancy does not mutate base walkable data")
	_expect(level.terrain.map_data.buildable_data == base_buildable, "runtime occupancy does not mutate base buildable data")

	if state != null and infantry != null and hq != null and enemy_hq != null:
		_verify_buildings_register_occupancy(state, hq, enemy_hq, infantry)
		_verify_effective_queries(state, hq)
		_verify_pathing_avoids_occupancy(level, infantry, hq)
		_verify_production_avoids_occupancy(level, entities_root, hq, wallet)
		_verify_building_death_clears_occupancy(state, level, enemy_hq)

	level.free()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(TEMP_MAP_PATH))
	if _failures == 0:
		print("v39 runtime occupancy verification passed.")
		quit(0)
	else:
		push_error("v39 runtime occupancy verification failed with %d failure(s)." % _failures)
		quit(1)

func _verify_buildings_register_occupancy(state: RuntimeMapState, hq: EntityBase, enemy_hq: EntityBase, infantry: EntityBase) -> void:
	var hq_cells := state.get_footprint_cells_for_entity(hq)
	var enemy_cells := state.get_footprint_cells_for_entity(enemy_hq)
	var infantry_cells := state.get_footprint_cells_for_entity(infantry)
	_expect(not hq_cells.is_empty(), "HQ footprint cells computed")
	_expect(not enemy_cells.is_empty(), "enemy HQ footprint cells computed")
	_expect(_all_cells_occupied_by(state, hq_cells, hq), "HQ cells registered as occupied")
	_expect(_all_cells_occupied_by(state, enemy_cells, enemy_hq), "enemy HQ cells registered as occupied")
	_expect(not _any_cells_occupied_by(state, infantry_cells, infantry), "unit cells are not runtime occupancy blockers")

func _verify_effective_queries(state: RuntimeMapState, hq: EntityBase) -> void:
	var hq_cell := state.world_to_cell(hq.global_position)
	_expect(state.is_cell_base_walkable(hq_cell), "HQ cell remains base walkable")
	_expect(state.is_cell_base_buildable(hq_cell), "HQ cell remains base buildable")
	_expect(state.is_cell_occupied(hq_cell), "HQ cell is occupied in runtime overlay")
	_expect(not state.is_cell_effectively_walkable(hq_cell), "occupied HQ cell is not effectively walkable")
	_expect(not state.is_cell_effectively_buildable(hq_cell), "occupied HQ cell is not effectively buildable")

func _verify_pathing_avoids_occupancy(level: Level, infantry: EntityBase, hq: EntityBase) -> void:
	var movement := infantry.get_component(&"MovementComponent") as MovementComponent
	movement.clear_path()
	infantry.global_position = Vector3(88.0, 0.0, 96.0)
	var target := Vector3(104.0, 0.0, 96.0)
	_expect(not MovementQueryScript.is_direct_route_walkable(level.terrain, infantry.global_position, target, 1.0, infantry.get_footprint_radius(), infantry), "direct route crossing HQ occupancy is blocked")
	_expect(infantry.execute_command(&"move", {
		"target_position": target,
		"terrain": level.terrain,
	}), "move around HQ occupancy succeeds")
	_expect(movement.has_path(), "A* provides path around occupied HQ cells")
	_expect(not level.runtime_map_state.can_ground_unit_stand_at(hq.global_position, infantry.get_footprint_radius()), "unit cannot stand inside occupied HQ")

func _verify_production_avoids_occupancy(level: Level, entities_root: Node, hq: EntityBase, wallet: Node) -> void:
	if wallet != null:
		wallet.reset_to_starting_resources()
	var production := hq.get_component(&"ProductionComponent") as ProductionComponent
	production.spawn_offset = Vector3.ZERO
	_expect(hq.execute_command(&"train_infantry", {}), "production queues with spawn origin inside HQ")
	_advance_production(production, 3.2)
	var spawned := _find_latest_infantry(entities_root)
	_expect(spawned != null, "production spawns infantry outside occupied HQ")
	if spawned != null:
		_expect(level.runtime_map_state.can_ground_unit_stand_at(spawned.global_position, spawned.get_footprint_radius()), "produced infantry spawn position is effectively standable")
		_expect(spawned.global_position.distance_to(hq.global_position) > 2.0, "produced infantry does not spawn inside HQ footprint")

func _verify_building_death_clears_occupancy(state: RuntimeMapState, level: Level, enemy_hq: EntityBase) -> void:
	var enemy_cells := state.get_footprint_cells_for_entity(enemy_hq)
	_expect(_all_cells_occupied_by(state, enemy_cells, enemy_hq), "enemy HQ occupied before death")
	enemy_hq.apply_damage(9999.0, null)
	_expect(not _any_cells_occupied(state, enemy_cells), "enemy HQ occupancy clears on death")
	var enemy_cell := state.world_to_cell(enemy_hq.global_position)
	_expect(state.is_cell_base_walkable(enemy_cell), "dead building cell is still base walkable")
	_expect(state.is_cell_effectively_walkable(enemy_cell), "dead building cell becomes effectively walkable again")
	_expect(MovementQueryScript.is_direct_route_walkable(level.terrain, Vector3(108.0, 0.0, 96.0), Vector3(116.0, 0.0, 96.0), 1.0, 0.4, null), "route through destroyed building area becomes valid")

func _advance_production(production: Node, seconds: float) -> void:
	var elapsed := 0.0
	while elapsed < seconds:
		production._process(0.1)
		elapsed += 0.1

func _all_cells_occupied_by(state: RuntimeMapState, cells: Array[Vector2i], owner: Node) -> bool:
	for cell in cells:
		if state.occupancy_grid.get_owner(cell) != owner:
			return false
	return true

func _any_cells_occupied_by(state: RuntimeMapState, cells: Array[Vector2i], owner: Node) -> bool:
	for cell in cells:
		if state.occupancy_grid.get_owner(cell) == owner:
			return true
	return false

func _any_cells_occupied(state: RuntimeMapState, cells: Array[Vector2i]) -> bool:
	for cell in cells:
		if state.is_cell_occupied(cell):
			return true
	return false

func _find_latest_infantry(entities_root: Node) -> EntityBase:
	var latest: EntityBase = null
	for child in entities_root.get_children():
		if child is Infantry:
			latest = child
	return latest

func _make_placement(entity_id: StringName, position: Vector3, team_id: int) -> Resource:
	var placement = EntityPlacementDataScript.new()
	placement.entity_id = entity_id
	placement.position = position
	placement.team_id = team_id
	return placement

func _find_child_by_name(parent: Node, child_name: String) -> Node:
	for child in parent.get_children():
		if child.name == child_name:
			return child
	return null

func _find_display_name(parent: Node, display_name: String) -> EntityBase:
	for child in parent.get_children():
		var entity := child as EntityBase
		if entity != null and entity.display_name == display_name:
			return entity
	return null

func _expect(condition: bool, message: String) -> void:
	if condition:
		print("PASS: %s" % message)
	else:
		_failures += 1
		push_error("FAIL: %s" % message)
