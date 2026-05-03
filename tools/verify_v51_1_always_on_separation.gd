extends SceneTree

const LevelScene := preload("res://level/level.tscn")
const TerrainMapDataScript := preload("res://terrain/terrain_map_data.gd")
const TerrainSerializerScript := preload("res://terrain/terrain_serializer.gd")
const EntityPlacementDataScript := preload("res://game/entities/placement/entity_placement_data.gd")
const MovementSpaceQueryScript := preload("res://game/entities/movement/movement_space_query.gd")

const TEMP_MAP_PATH := "res://tools/v51_1_always_on_separation_temp.res"

var _failures := 0
var _ran := false

func _process(_delta: float) -> bool:
	if _ran:
		return false
	_ran = true
	_run()
	return true

func _run() -> void:
	var level := _make_level()
	var workers := _get_workers(level)
	_expect(workers.size() == 5, "five workers spawned")
	if workers.size() == 5:
		_verify_idle_workers_spread(level, workers)
		_verify_moving_workers_keep_personal_space(level, workers)
	level.free()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(TEMP_MAP_PATH))
	if _failures == 0:
		print("v51.1 always-on separation verification passed.")
		quit(0)
	else:
		push_error("v51.1 always-on separation failed with %d failure(s)." % _failures)
		quit(1)

func _verify_idle_workers_spread(level: Level, workers: Array[EntityBase]) -> void:
	for worker in workers:
		_reset_worker(worker, Vector3(124.0, 0.0, 128.0), level.terrain)
	_drive_all_workers(workers, 1.5)
	_expect(_max_distance_from(workers, Vector3(124.0, 0.0, 128.0)) > 0.35, "stacked idle workers spread apart")
	_expect(_min_pair_distance(workers) > 0.65, "idle workers leave visible air space")
	_expect(_all_workers_clear_of_hard_blockers(level, workers), "idle separation keeps workers out of hard blockers")

func _verify_moving_workers_keep_personal_space(level: Level, workers: Array[EntityBase]) -> void:
	for index in range(workers.size()):
		_reset_worker(workers[index], Vector3(120.0 + float(index) * 0.1, 0.0, 124.0), level.terrain)
	var target := Vector3(136.0, 0.0, 128.0)
	for worker in workers:
		_expect(worker.execute_command(&"move", {
			"target_position": target,
			"terrain": level.terrain,
		}), "worker move command to shared target succeeds")
	_drive_all_workers(workers, 3.0)
	_expect(_min_pair_distance(workers) > 0.55, "moving workers retain visible personal space")
	_expect(_all_workers_clear_of_hard_blockers(level, workers), "moving separation keeps workers out of hard blockers")
	for worker in workers:
		var movement := worker.get_movement_component()
		_expect(movement != null, "worker still has movement component")

func _drive_all_workers(workers: Array[EntityBase], seconds: float) -> void:
	var elapsed := 0.0
	while elapsed < seconds:
		for worker in workers:
			var movement := worker.get_movement_component()
			if movement != null:
				movement._process(0.05)
		elapsed += 0.05

func _reset_worker(worker: EntityBase, position: Vector3, terrain: Terrain) -> void:
	worker.global_position = position
	worker.global_position.y = terrain.get_height_at_local_position(terrain.to_local(position))
	var movement := worker.get_movement_component()
	if movement != null:
		movement.clear_path()
		movement.set_terrain(terrain)

func _all_workers_clear_of_hard_blockers(level: Level, workers: Array[EntityBase]) -> bool:
	for worker in workers:
		if not MovementSpaceQueryScript.is_circle_space_clear(worker.global_position, worker.get_footprint_radius(), level.terrain, worker, false):
			return false
	return true

func _min_pair_distance(workers: Array[EntityBase]) -> float:
	var min_distance := INF
	for i in range(workers.size()):
		for j in range(i + 1, workers.size()):
			var a := workers[i].global_position
			var b := workers[j].global_position
			var distance := Vector2(a.x - b.x, a.z - b.z).length()
			min_distance = minf(min_distance, distance)
	return min_distance

func _max_distance_from(workers: Array[EntityBase], origin: Vector3) -> float:
	var max_distance := 0.0
	for worker in workers:
		var position := worker.global_position
		max_distance = maxf(max_distance, Vector2(position.x - origin.x, position.z - origin.z).length())
	return max_distance

func _get_workers(level: Level) -> Array[EntityBase]:
	var workers: Array[EntityBase] = []
	var entities_root: Node = level.get_node("Entities")
	for child in entities_root.get_children():
		var entity := child as EntityBase
		if entity != null and entity.display_name == "Worker":
			workers.append(entity)
	return workers

func _make_level() -> Level:
	var map_data = TerrainMapDataScript.new()
	map_data.create_flat_grass_map(Vector2i(2, 2), 0.0)
	map_data.entity_placements = [
		_make_placement(&"worker", Vector3(124.0, 0.0, 128.0), 1),
		_make_placement(&"worker", Vector3(124.0, 0.0, 128.0), 1),
		_make_placement(&"worker", Vector3(124.0, 0.0, 128.0), 1),
		_make_placement(&"worker", Vector3(124.0, 0.0, 128.0), 1),
		_make_placement(&"worker", Vector3(124.0, 0.0, 128.0), 1),
		_make_placement(&"test_hq", Vector3(128.0, 0.0, 128.0), 1),
		_make_placement(&"tritanium_crystal_node", Vector3(136.0, 0.0, 128.0), 0),
	]
	_expect(TerrainSerializerScript.save(map_data, TEMP_MAP_PATH, "v51.1 Always-On Separation"), "temporary map saves")
	var level := LevelScene.instantiate() as Level
	root.add_child(level)
	_expect(level.load_map(TEMP_MAP_PATH), "level loads temporary map")
	return level

func _make_placement(entity_id: StringName, position: Vector3, team_id: int) -> Resource:
	var placement = EntityPlacementDataScript.new()
	placement.entity_id = entity_id
	placement.position = position
	placement.team_id = team_id
	return placement

func _expect(condition: bool, message: String) -> void:
	if condition:
		print("PASS: %s" % message)
	else:
		_failures += 1
		push_error("FAIL: %s" % message)
