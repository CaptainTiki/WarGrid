extends SceneTree

const LevelScene := preload("res://level/level.tscn")
const InfantryScene := preload("res://game/entities/units/infantry/infantry.tscn")
const TerrainMapDataScript := preload("res://terrain/terrain_map_data.gd")
const TerrainSerializerScript := preload("res://terrain/terrain_serializer.gd")
const EntityPlacementDataScript := preload("res://game/entities/placement/entity_placement_data.gd")

const TEMP_MAP_PATH := "res://tools/v36_spawn_placement_temp.res"

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
		_make_placement(&"test_hq", Vector3(128.0, 0.0, 128.0), 1),
	])
	var entities_root: Node = level.get_node("Entities")
	var hq := _find_child_by_name(entities_root, "TestHQ") as EntityBase
	_expect(hq != null, "player Test HQ spawned")

	if hq != null:
		var production := hq.get_component(&"ProductionComponent")
		_verify_blocked_offset_searches_nearby(level, entities_root, hq, production, wallet)
		_clear_units(entities_root)
		if wallet != null:
			wallet.reset_to_starting_resources()
		_verify_failed_search_refunds(entities_root, hq, production, wallet)

	level.free()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(TEMP_MAP_PATH))
	if _failures == 0:
		print("v36 spawn placement search verification passed.")
		quit(0)
	else:
		push_error("v36 spawn placement search verification failed with %d failure(s)." % _failures)
		quit(1)

func _verify_blocked_offset_searches_nearby(
		level: Level,
		entities_root: Node,
		hq: EntityBase,
		production: ProductionComponent,
		wallet: Node
) -> void:
	var desired_spawn := hq.global_position + production.spawn_offset
	var blocker := InfantryScene.instantiate() as EntityBase
	blocker.name = "SpawnBlocker"
	blocker.team_id = 1
	entities_root.add_child(blocker)
	blocker.global_position = desired_spawn
	if blocker.has_method("set_terrain"):
		blocker.set_terrain(level.terrain)

	_expect(hq.execute_command(&"train_infantry", {}), "production queues with desired spawn blocked")
	_advance_production(production, 3.2)
	var spawned := _find_child_by_name(entities_root, "Infantry") as EntityBase
	_expect(spawned != null, "production spawns infantry at alternate position")
	if spawned != null:
		_expect(spawned.global_position.distance_to(desired_spawn) > 0.1, "alternate spawn is not the blocked desired point")
		_expect(_entities_have_clearance(spawned, blocker), "alternate spawn avoids blocker footprint")
	_expect(wallet == null or wallet.get_amount(&"crystals") == 450, "successful alternate spawn keeps spent crystals")

func _verify_failed_search_refunds(
		entities_root: Node,
		hq: EntityBase,
		production: ProductionComponent,
		wallet: Node
) -> void:
	production.spawn_offset = Vector3.ZERO
	production.spawn_search_radius = 0.1
	_expect(hq.execute_command(&"train_infantry", {}), "production queues when future spawn is blocked")
	_advance_production(production, 3.2)
	_expect(_find_child_by_name(entities_root, "Infantry") == null, "blocked production does not spawn infantry")
	_expect(wallet == null or wallet.get_amount(&"crystals") == 500, "failed spawn refunds crystals")

func _advance_production(production: Node, seconds: float) -> void:
	var elapsed := 0.0
	while elapsed < seconds:
		production._process(0.1)
		elapsed += 0.1

func _entities_have_clearance(a: EntityBase, b: EntityBase) -> bool:
	var a_radius := a.get_footprint_radius()
	var b_radius := b.get_footprint_radius()
	var distance := Vector2(a.global_position.x - b.global_position.x, a.global_position.z - b.global_position.z).length()
	return distance >= a_radius + b_radius

func _clear_units(entities_root: Node) -> void:
	for child in entities_root.get_children():
		if child is UnitBase:
			child.free()

func _make_level(placements: Array) -> Level:
	var map_data = TerrainMapDataScript.new()
	map_data.create_flat_grass_map(Vector2i(2, 2), 0.0)
	map_data.entity_placements = placements
	_expect(TerrainSerializerScript.save(map_data, TEMP_MAP_PATH, "v36 Spawn Placement"), "temporary map saves")
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
