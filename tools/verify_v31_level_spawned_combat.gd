extends SceneTree

const LevelScene := preload("res://level/level.tscn")
const TerrainMapDataScript := preload("res://terrain/terrain_map_data.gd")
const TerrainSerializerScript := preload("res://terrain/terrain_serializer.gd")
const EntityPlacementDataScript := preload("res://game/entities/placement/entity_placement_data.gd")

const TEMP_MAP_PATH := "res://tools/v31_level_spawned_combat_temp.res"

var _failures := 0
var _ran := false

func _process(_delta: float) -> bool:
	if _ran:
		return false
	_ran = true
	_run()
	return true

func _run() -> void:
	var map_data = TerrainMapDataScript.new()
	map_data.create_flat_grass_map(Vector2i(2, 2), 0.0)
	var placements: Array[Resource] = []
	placements.append(_make_placement(&"infantry", Vector3(128.0, 0.0, 128.0), 1))
	placements.append(_make_placement(&"enemy_dummy_unit", Vector3(131.0, 0.0, 128.0), 2))
	map_data.entity_placements = placements
	_expect(TerrainSerializerScript.save(map_data, TEMP_MAP_PATH, "v31 Level Spawned Combat"), "temporary map saves")

	var level = LevelScene.instantiate()
	root.add_child(level)
	_expect(level.load_map(TEMP_MAP_PATH), "level loads temporary map")
	var entities_root: Node = level.get_node("Entities")
	_expect(entities_root.get_child_count() == 2, "level spawns two placements")

	var infantry := _find_entity(entities_root, "Infantry", 1)
	var enemy := _find_entity(entities_root, "Enemy Dummy Unit", 2)
	_expect(infantry != null, "level-spawned infantry exists as team 1")
	_expect(enemy != null, "level-spawned enemy dummy exists as team 2")
	if infantry != null:
		_expect(infantry.has_command(&"attack"), "level-spawned infantry has attack command")
		var command_panel = level.get_node("UI/CommandPanel")
		var selected: Array[EntityBase] = [infantry]
		command_panel.set_selected_entities(selected)
		_expect(command_panel._command_list.get_child_count() == 3, "command panel shows attack-capable infantry commands")
	if infantry != null and enemy != null:
		var infantry_combat := infantry.get_component(&"CombatComponent") as CombatComponent
		var enemy_combat := enemy.get_component(&"CombatComponent") as CombatComponent
		_expect(infantry_combat != null, "level-spawned infantry has combat")
		_expect(enemy_combat != null, "level-spawned enemy dummy has combat")
		infantry_combat.scan_interval = 0.1
		enemy_combat.scan_interval = 0.1
		infantry_combat._physics_process(0.1)
		enemy_combat._physics_process(0.1)
		_expect(infantry_combat.current_target == enemy, "level-spawned infantry auto-acquires enemy")
		_expect(enemy_combat.current_target == infantry, "level-spawned enemy auto-acquires infantry")
		infantry_combat.clear_attack_target(true)
		_expect(infantry.execute_command(&"attack", {"target_entity": enemy}), "level-spawned infantry accepts right-click-style attack command")
		_expect(infantry_combat.current_target == enemy, "right-click-style attack stores target")

	level.free()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(TEMP_MAP_PATH))
	if _failures == 0:
		print("v31 level-spawned combat verification passed.")
		quit(0)
	else:
		push_error("v31 level-spawned combat verification failed with %d failure(s)." % _failures)
		quit(1)

func _make_placement(entity_id: StringName, position: Vector3, team_id: int) -> Resource:
	var placement = EntityPlacementDataScript.new()
	placement.entity_id = entity_id
	placement.position = position
	placement.team_id = team_id
	return placement

func _find_entity(root_node: Node, display_name: String, team_id: int) -> EntityBase:
	for child in root_node.get_children():
		var entity := child as EntityBase
		if entity != null and entity.display_name == display_name and entity.team_id == team_id:
			return entity
	return null

func _expect(condition: bool, message: String) -> void:
	if condition:
		print("PASS: %s" % message)
	else:
		_failures += 1
		push_error("FAIL: %s" % message)
