extends SceneTree

const LevelScene := preload("res://level/level.tscn")
const TerrainMapDataScript := preload("res://terrain/terrain_map_data.gd")
const TerrainSerializerScript := preload("res://terrain/terrain_serializer.gd")
const EntityPlacementDataScript := preload("res://game/entities/placement/entity_placement_data.gd")

const TEMP_MAP_PATH := "res://tools/v35_production_ui_rally_temp.res"

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
		var panel: CommandPanel = level.get_node("UI/CommandPanel")
		panel.set_selected_entities([hq])

		_expect(panel.get_node("ResourceLabel").text == "Crystals: 500\nHe3: 0", "command panel shows crystals and he3")
		_expect(panel.get_node("ProductionCommandsLabel").text.contains("Train Infantry"), "command panel shows production command summary")
		_expect(panel.get_node("ActiveProductionLabel").text == "Active: Idle", "command panel shows idle production")
		_expect(panel.get_node("ProductionQueueLabel").text == "Queue: 0 / 5", "command panel shows empty queue count")

		var rally_point := Vector3(138.0, 0.0, 128.0)
		_expect(hq.execute_command(&"set_rally_point", {
			"target_position": rally_point,
			"terrain": level.terrain,
		}), "Set Rally Point command stores terrain point")
		_expect(production.has_rally_point, "production component records rally point")
		_expect(panel.get_node("RallyPointLabel").text.contains("138.0"), "command panel shows rally point")

		_expect(hq.execute_command(&"train_infantry", {}), "Train Infantry queues production")
		_expect(wallet == null or wallet.get_amount(&"crystals") == 450, "queue spends crystals")
		_expect(panel.get_node("ActiveProductionLabel").text == "Active: Train Infantry", "command panel shows active item")
		_expect(panel.get_node("ProductionQueueLabel").text == "Queue: 1 / 5", "command panel shows active queue count")

		_advance_production(production, 3.2)
		var infantry := _find_child_by_name(entities_root, "Infantry") as EntityBase
		_expect(infantry != null, "completed production spawns infantry near building")
		if infantry != null:
			var movement := infantry.get_component(&"MovementComponent") as MovementComponent
			_expect(movement != null and movement.has_path(), "produced infantry receives move command to rally")
			_expect(infantry.global_position.distance_to(hq.global_position) <= 4.0, "produced infantry spawns near producer")

	level.free()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(TEMP_MAP_PATH))
	if _failures == 0:
		print("v35 production UI + rally verification passed.")
		quit(0)
	else:
		push_error("v35 production UI + rally verification failed with %d failure(s)." % _failures)
		quit(1)

func _advance_production(production: Node, seconds: float) -> void:
	var elapsed := 0.0
	while elapsed < seconds:
		production._process(0.1)
		elapsed += 0.1

func _make_level(placements: Array) -> Level:
	var map_data = TerrainMapDataScript.new()
	map_data.create_flat_grass_map(Vector2i(2, 2), 0.0)
	map_data.entity_placements = placements
	_expect(TerrainSerializerScript.save(map_data, TEMP_MAP_PATH, "v35 Production UI Rally"), "temporary map saves")
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
