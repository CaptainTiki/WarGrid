extends SceneTree

const LevelScene := preload("res://level/level.tscn")
const MAP_PATH := "res://levels/test_map/map_data.res"

var _failures := 0
var _ran := false

func _process(_delta: float) -> bool:
	if _ran:
		return false
	_ran = true
	_run()
	return true

func _run() -> void:
	var level = LevelScene.instantiate()
	root.add_child(level)
	_expect(level.load_map(MAP_PATH), "mountain test map loads")
	var entities_root: Node = level.get_node("Entities")
	var attackers: Array[EntityBase] = [
		_find_entity(entities_root, "Infantry", 1),
		_find_entity(entities_root, "Scout Bike", 1),
		_find_entity(entities_root, "Scout Buggy", 1),
	]
	var enemy_hq := _find_entity(entities_root, "Enemy Test HQ", 2)
	_expect(enemy_hq != null, "enemy HQ exists on mountain test map")
	for attacker in attackers:
		_expect(attacker != null, "friendly attacker exists on mountain test map")
		if attacker == null or enemy_hq == null:
			continue
		_configure_combat(attacker)
		var combat := attacker.get_component(&"CombatComponent") as CombatComponent
		var movement := attacker.get_component(&"MovementComponent") as MovementComponent
		_expect(attacker.execute_command(&"attack", {"target_entity": enemy_hq}), "%s accepts cross-map attack" % attacker.display_name)
		combat._physics_process(0.5)
		_expect(movement.has_path(), "%s starts pathing toward enemy HQ" % attacker.display_name)
		_drive_until_in_range(attacker, enemy_hq)
		combat._physics_process(0.5)
		_expect(combat.is_target_in_attack_range(enemy_hq), "%s reaches enemy HQ attack range" % attacker.display_name)

	level.free()
	if _failures == 0:
		print("v32 mountain map pursuit verification passed.")
		quit(0)
	else:
		push_error("v32 mountain map pursuit verification failed with %d failure(s)." % _failures)
		quit(1)

func _drive_until_in_range(attacker: EntityBase, target: EntityBase, max_steps: int = 240) -> void:
	var combat := attacker.get_component(&"CombatComponent") as CombatComponent
	var movement := attacker.get_component(&"MovementComponent") as MovementComponent
	for i in range(max_steps):
		if combat.is_target_in_attack_range(target):
			return
		combat._physics_process(0.25)
		movement._process(0.25)

func _configure_combat(entity: EntityBase) -> void:
	var combat := entity.get_component(&"CombatComponent") as CombatComponent
	if combat == null:
		return
	combat.attack_range = 6.0
	combat.acquisition_range = 6.0
	combat.pursue_stop_distance = 5.0
	combat.pursuit_repath_interval = 0.25
	combat.scan_interval = 0.1

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
