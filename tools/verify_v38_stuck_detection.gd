extends SceneTree

const LevelScene := preload("res://level/level.tscn")
const TerrainMapDataScript := preload("res://terrain/terrain_map_data.gd")
const TerrainSerializerScript := preload("res://terrain/terrain_serializer.gd")
const EntityPlacementDataScript := preload("res://game/entities/placement/entity_placement_data.gd")

const TEMP_MAP_PATH := "res://tools/v38_stuck_detection_temp.res"

var _failures := 0
var _ran := false

func _process(_delta: float) -> bool:
	if _ran:
		return false
	_ran = true
	_run()
	return true

func _run() -> void:
	var level := _make_level([
		_make_placement(&"infantry", Vector3(124.0, 0.0, 128.0), 1),
	])
	var entities_root: Node = level.get_node("Entities")
	var infantry := _find_child_by_name(entities_root, "Infantry") as EntityBase
	_expect(infantry != null, "infantry spawned")

	if infantry != null:
		_verify_temporary_pause_does_not_trip_stuck(level, infantry)
		_verify_sustained_no_movement_retries_then_clears(level, infantry)

	level.free()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(TEMP_MAP_PATH))
	if _failures == 0:
		print("v38 stuck detection verification passed.")
		quit(0)
	else:
		push_error("v38 stuck detection verification failed with %d failure(s)." % _failures)
		quit(1)

func _verify_temporary_pause_does_not_trip_stuck(level: Level, infantry: EntityBase) -> void:
	_reset_unit(infantry, Vector3(124.0, 0.0, 128.0))
	var movement := _get_movement(infantry)
	movement.speed = 0.0
	movement.stuck_check_interval = 0.2
	movement.stuck_timeout_seconds = 0.6
	movement.stuck_min_movement = 0.05
	movement.stuck_min_progress = 0.05
	_expect(infantry.execute_command(&"move", {
		"target_position": Vector3(130.0, 0.0, 128.0),
		"terrain": level.terrain,
	}), "pause test move command succeeds")
	_drive_movement(movement, 0.45)
	_expect(movement.has_path(), "short pause below stuck timeout keeps path")

func _verify_sustained_no_movement_retries_then_clears(level: Level, infantry: EntityBase) -> void:
	_reset_unit(infantry, Vector3(124.0, 0.0, 128.0))
	var movement := _get_movement(infantry)
	movement.speed = 0.0
	movement.stuck_check_interval = 0.2
	movement.stuck_timeout_seconds = 0.4
	movement.stuck_min_movement = 0.05
	movement.stuck_min_progress = 0.05
	_expect(infantry.execute_command(&"move", {
		"target_position": Vector3(130.0, 0.0, 128.0),
		"terrain": level.terrain,
	}), "sustained stuck move command succeeds")
	_drive_movement(movement, 0.45)
	_expect(movement.has_path(), "first stuck timeout retries and keeps path")
	_drive_movement(movement, 0.45)
	_expect(not movement.has_path(), "second stuck timeout clears path")

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

func _make_level(placements: Array) -> Level:
	var map_data = TerrainMapDataScript.new()
	map_data.create_flat_grass_map(Vector2i(2, 2), 0.0)
	map_data.entity_placements = placements
	_expect(TerrainSerializerScript.save(map_data, TEMP_MAP_PATH, "v38 Stuck Detection"), "temporary map saves")
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
