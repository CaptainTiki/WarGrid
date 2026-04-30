extends SceneTree

const LevelScene := preload("res://level/level.tscn")
const InfantryScene := preload("res://game/entities/units/infantry/infantry.tscn")
const TerrainMapDataScript := preload("res://terrain/terrain_map_data.gd")
const TerrainSerializerScript := preload("res://terrain/terrain_serializer.gd")
const EntityPlacementDataScript := preload("res://game/entities/placement/entity_placement_data.gd")

const TEMP_MAP_PATH := "res://tools/v37_movement_target_resolution_temp.res"

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

	var level := _make_level([
		_make_placement(&"infantry", Vector3(124.0, 0.0, 128.0), 1),
		_make_placement(&"test_hq", Vector3(128.0, 0.0, 128.0), 1),
	])
	var entities_root: Node = level.get_node("Entities")
	var infantry := _find_child_by_name(entities_root, "Infantry") as EntityBase
	var hq := _find_child_by_name(entities_root, "TestHQ") as EntityBase
	_expect(infantry != null, "infantry spawned")
	_expect(hq != null, "player Test HQ spawned")

	if infantry != null:
		_verify_open_target_preserved(level, infantry)
		_verify_occupied_target_resolves(level, entities_root, infantry)
		_verify_arrival_radius_completes(level, infantry)
		_verify_stuck_retry_then_stop(level, infantry)
	if hq != null:
		_verify_rally_uses_resolved_movement(level, entities_root, hq, wallet)

	level.free()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(TEMP_MAP_PATH))
	if _failures == 0:
		print("v37 movement target resolution verification passed.")
		quit(0)
	else:
		push_error("v37 movement target resolution failed with %d failure(s)." % _failures)
		quit(1)

func _verify_open_target_preserved(level: Level, infantry: EntityBase) -> void:
	_reset_unit(infantry, Vector3(124.0, 0.0, 128.0))
	var movement := _get_movement(infantry)
	var target := Vector3(126.0, 0.0, 128.0)
	_expect(infantry.execute_command(&"move", {
		"target_position": target,
		"terrain": level.terrain,
	}), "open move target command succeeds")
	_expect(movement.has_path(), "open move starts a path")
	_expect(movement.get_resolved_target().distance_to(target) <= 0.01, "open move preserves requested destination")

func _verify_occupied_target_resolves(level: Level, entities_root: Node, infantry: EntityBase) -> void:
	_reset_unit(infantry, Vector3(124.0, 0.0, 128.0))
	var blocker := InfantryScene.instantiate() as EntityBase
	blocker.name = "MoveTargetBlocker"
	blocker.team_id = 1
	entities_root.add_child(blocker)
	blocker.global_position = Vector3(126.0, 0.0, 128.0)
	blocker.set_terrain(level.terrain)

	var movement := _get_movement(infantry)
	_expect(infantry.execute_command(&"move", {
		"target_position": blocker.global_position,
		"terrain": level.terrain,
	}), "occupied move target command resolves and succeeds")
	_expect(movement.has_path(), "occupied move starts a path")
	_expect(movement.get_resolved_target().distance_to(blocker.global_position) > 0.1, "occupied target resolves away from blocker")
	_expect(_entities_have_clearance_at(infantry, movement.get_resolved_target(), blocker), "resolved target avoids blocker footprint")
	blocker.free()

func _verify_arrival_radius_completes(level: Level, infantry: EntityBase) -> void:
	_reset_unit(infantry, Vector3(124.0, 0.0, 128.0))
	var movement := _get_movement(infantry)
	movement.arrival_radius = 0.5
	_expect(infantry.execute_command(&"move", {
		"target_position": Vector3(124.2, 0.0, 128.0),
		"terrain": level.terrain,
	}), "nearby move command succeeds")
	_expect(not movement.has_path(), "arrival radius completes close-enough target")
	movement.arrival_radius = 0.25

func _verify_stuck_retry_then_stop(level: Level, infantry: EntityBase) -> void:
	_reset_unit(infantry, Vector3(124.0, 0.0, 128.0))
	var movement := _get_movement(infantry)
	movement.speed = 0.0
	movement.stuck_check_interval = 0.2
	movement.stuck_timeout_seconds = 0.2
	movement.stuck_min_movement = 0.05
	movement.stuck_min_progress = 0.05
	_expect(infantry.execute_command(&"move", {
		"target_position": Vector3(130.0, 0.0, 128.0),
		"terrain": level.terrain,
	}), "stuck test move command succeeds")
	_drive_movement(movement, 0.25)
	_expect(movement.has_path(), "first stuck event retries and keeps a path")
	_drive_movement(movement, 0.25)
	_expect(not movement.has_path(), "second stuck event gives up and clears path")
	movement.speed = 5.0
	movement.stuck_check_interval = 0.5
	movement.stuck_timeout_seconds = 1.5
	movement.stuck_min_movement = 0.05
	movement.stuck_min_progress = 0.1

func _verify_rally_uses_resolved_movement(level: Level, entities_root: Node, hq: EntityBase, wallet: Node) -> void:
	if wallet != null:
		wallet.reset_to_starting_resources()
	var rally_blocker := InfantryScene.instantiate() as EntityBase
	rally_blocker.name = "RallyBlocker"
	rally_blocker.team_id = 1
	entities_root.add_child(rally_blocker)
	rally_blocker.global_position = Vector3(136.0, 0.0, 128.0)
	rally_blocker.set_terrain(level.terrain)

	var production := hq.get_component(&"ProductionComponent")
	_expect(hq.execute_command(&"set_rally_point", {
		"target_position": rally_blocker.global_position,
		"terrain": level.terrain,
	}), "rally target command accepts occupied point")
	_expect(hq.execute_command(&"train_infantry", {}), "production queues for rally movement regression")
	_advance_production(production, 3.2)
	var spawned := _find_latest_infantry(entities_root, rally_blocker)
	_expect(spawned != null, "rally regression spawns infantry")
	if spawned != null:
		var movement := _get_movement(spawned)
		_expect(movement.has_path(), "rally produced infantry receives resolved move path")
		_expect(movement.get_resolved_target().distance_to(rally_blocker.global_position) > 0.1, "rally move resolves occupied rally point")
	rally_blocker.free()

func _advance_production(production: Node, seconds: float) -> void:
	var elapsed := 0.0
	while elapsed < seconds:
		production._process(0.1)
		elapsed += 0.1

func _drive_movement(movement: MovementComponent, seconds: float) -> void:
	var elapsed := 0.0
	while elapsed < seconds:
		movement._process(0.05)
		elapsed += 0.05

func _reset_unit(entity: EntityBase, position: Vector3) -> void:
	entity.global_position = position
	var movement := _get_movement(entity)
	movement.clear_path()
	movement.speed = 5.0
	movement.arrival_radius = 0.25
	movement.stuck_check_interval = 0.5
	movement.stuck_timeout_seconds = 1.5
	movement.stuck_min_movement = 0.05
	movement.stuck_min_progress = 0.1

func _get_movement(entity: EntityBase) -> MovementComponent:
	return entity.get_component(&"MovementComponent") as MovementComponent

func _entities_have_clearance_at(entity: EntityBase, position: Vector3, blocker: EntityBase) -> bool:
	var entity_radius := entity.get_footprint_radius()
	var blocker_radius := blocker.get_footprint_radius()
	var distance := Vector2(position.x - blocker.global_position.x, position.z - blocker.global_position.z).length()
	return distance >= entity_radius + blocker_radius

func _find_latest_infantry(entities_root: Node, excluded: EntityBase) -> EntityBase:
	var latest: EntityBase = null
	for child in entities_root.get_children():
		if child is Infantry and child != excluded:
			latest = child
	return latest

func _make_level(placements: Array) -> Level:
	var map_data = TerrainMapDataScript.new()
	map_data.create_flat_grass_map(Vector2i(2, 2), 0.0)
	map_data.entity_placements = placements
	_expect(TerrainSerializerScript.save(map_data, TEMP_MAP_PATH, "v37 Movement Target Resolution"), "temporary map saves")
	var level = LevelScene.instantiate()
	root.add_child(level)
	_expect(level.load_map(TEMP_MAP_PATH), "level loads temporary map")
	return level

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

func _expect(condition: bool, message: String) -> void:
	if condition:
		print("PASS: %s" % message)
	else:
		_failures += 1
		push_error("FAIL: %s" % message)
