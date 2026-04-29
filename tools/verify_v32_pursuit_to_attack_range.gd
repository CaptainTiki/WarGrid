extends SceneTree

const LevelScene := preload("res://level/level.tscn")
const TerrainMapDataScript := preload("res://terrain/terrain_map_data.gd")
const TerrainSerializerScript := preload("res://terrain/terrain_serializer.gd")
const EntityPlacementDataScript := preload("res://game/entities/placement/entity_placement_data.gd")

const TEMP_MAP_PATH := "res://tools/v32_pursuit_temp.res"

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
		_make_placement(&"infantry", Vector3(128.0, 0.0, 128.0), 1),
		_make_placement(&"enemy_dummy_unit", Vector3(148.0, 0.0, 128.0), 2),
		_make_placement(&"enemy_test_hq", Vector3(152.0, 0.0, 132.0), 2),
	])
	var entities_root: Node = level.get_node("Entities")
	var infantry := _find_entity(entities_root, "Infantry", 1)
	var enemy := _find_entity(entities_root, "Enemy Dummy Unit", 2)
	var enemy_hq := _find_entity(entities_root, "Enemy Test HQ", 2)
	_expect(infantry != null, "infantry spawned")
	_expect(enemy != null, "enemy dummy spawned")
	_expect(enemy_hq != null, "enemy HQ spawned")

	if infantry != null and enemy != null and enemy_hq != null:
		_configure_combat(infantry)
		_configure_combat(enemy)
		_configure_combat(enemy_hq)
		_verify_commanded_attack_in_range(infantry, enemy)
		_verify_commanded_attack_out_of_range(infantry, enemy)
		_verify_stop_cancels_pursuit(infantry, enemy)
		_verify_move_overrides_pursuit(infantry, enemy, level.terrain)
		_verify_attack_replaces_target(infantry, enemy, enemy_hq)
		_verify_auto_acquire_does_not_chase(infantry, enemy)
		_verify_dead_target_clears_pursuit(infantry, enemy)

	level.free()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(TEMP_MAP_PATH))
	if _failures == 0:
		print("v32 pursuit to attack range verification passed.")
		quit(0)
	else:
		push_error("v32 pursuit to attack range verification failed with %d failure(s)." % _failures)
		quit(1)

func _verify_commanded_attack_in_range(infantry: EntityBase, enemy: EntityBase) -> void:
	_reset_entity(infantry, Vector3(128.0, 0.0, 128.0))
	_reset_entity(enemy, Vector3(132.0, 0.0, 128.0))
	var combat := infantry.get_component(&"CombatComponent") as CombatComponent
	var movement := infantry.get_component(&"MovementComponent") as MovementComponent
	var projectile_count := get_nodes_in_group(&"combat_projectiles").size()
	_expect(infantry.execute_command(&"attack", {"target_entity": enemy}), "in-range attack command executes")
	_expect(combat.current_target == enemy, "in-range attack stores commanded target")
	_expect(not movement.has_path(), "in-range attack does not start movement")
	_expect(get_nodes_in_group(&"combat_projectiles").size() > projectile_count, "in-range attack fires immediately")
	_clear_projectiles()

func _verify_commanded_attack_out_of_range(infantry: EntityBase, enemy: EntityBase) -> void:
	_reset_entity(infantry, Vector3(128.0, 0.0, 128.0))
	_reset_entity(enemy, Vector3(148.0, 0.0, 128.0))
	var combat := infantry.get_component(&"CombatComponent") as CombatComponent
	var movement := infantry.get_component(&"MovementComponent") as MovementComponent
	var projectile_count := get_nodes_in_group(&"combat_projectiles").size()
	_expect(infantry.execute_command(&"attack", {"target_entity": enemy}), "out-of-range attack command executes")
	combat._physics_process(0.5)
	_expect(movement.has_path(), "out-of-range command target starts pursuit")
	_expect(get_nodes_in_group(&"combat_projectiles").size() == projectile_count, "out-of-range target does not fire immediately")
	_drive_until_in_range(infantry, enemy)
	combat._physics_process(0.5)
	_expect(combat.is_target_in_attack_range(enemy), "pursuit reaches attack range")
	_expect(not movement.has_path(), "pursuit movement stops in attack range")
	_expect(get_nodes_in_group(&"combat_projectiles").size() > projectile_count, "unit fires after reaching attack range")
	_clear_projectiles()

func _verify_stop_cancels_pursuit(infantry: EntityBase, enemy: EntityBase) -> void:
	_reset_entity(infantry, Vector3(128.0, 0.0, 128.0))
	_reset_entity(enemy, Vector3(148.0, 0.0, 128.0))
	var combat := infantry.get_component(&"CombatComponent") as CombatComponent
	var movement := infantry.get_component(&"MovementComponent") as MovementComponent
	_expect(infantry.execute_command(&"attack", {"target_entity": enemy}), "attack command starts before stop")
	combat._physics_process(0.5)
	_expect(movement.has_path(), "unit is pursuing before stop")
	_expect(infantry.execute_command(&"stop", {}), "stop command executes during pursuit")
	_expect(combat.current_target == null, "stop clears pursuit target")
	_expect(not movement.has_path(), "stop clears pursuit path")

func _verify_move_overrides_pursuit(infantry: EntityBase, enemy: EntityBase, terrain: Terrain) -> void:
	_reset_entity(infantry, Vector3(128.0, 0.0, 128.0))
	_reset_entity(enemy, Vector3(148.0, 0.0, 128.0))
	var combat := infantry.get_component(&"CombatComponent") as CombatComponent
	var movement := infantry.get_component(&"MovementComponent") as MovementComponent
	_expect(infantry.execute_command(&"attack", {"target_entity": enemy}), "attack command starts before move override")
	combat._physics_process(0.5)
	_expect(infantry.execute_command(&"move", {"target_position": Vector3(124.0, 0.0, 128.0), "terrain": terrain}), "move command executes during pursuit")
	_expect(combat.current_target == null, "move clears pursuit target")
	_expect(movement.has_path(), "move replaces pursuit with move path")

func _verify_attack_replaces_target(infantry: EntityBase, enemy: EntityBase, enemy_hq: EntityBase) -> void:
	_reset_entity(infantry, Vector3(128.0, 0.0, 128.0))
	_reset_entity(enemy, Vector3(148.0, 0.0, 128.0))
	_reset_entity(enemy_hq, Vector3(152.0, 0.0, 132.0))
	var combat := infantry.get_component(&"CombatComponent") as CombatComponent
	_expect(infantry.execute_command(&"attack", {"target_entity": enemy}), "attack command starts before replacement")
	combat._physics_process(0.5)
	_expect(infantry.execute_command(&"attack", {"target_entity": enemy_hq}), "replacement attack command executes")
	_expect(combat.current_target == enemy_hq, "attack command replaces pursuit target")
	_expect(combat.target_source == CombatComponent.TargetSource.COMMAND, "replacement target remains command-sourced")

func _verify_auto_acquire_does_not_chase(infantry: EntityBase, enemy: EntityBase) -> void:
	_reset_entity(infantry, Vector3(128.0, 0.0, 128.0))
	_reset_entity(enemy, Vector3(132.0, 0.0, 128.0))
	var combat := infantry.get_component(&"CombatComponent") as CombatComponent
	var movement := infantry.get_component(&"MovementComponent") as MovementComponent
	combat.clear_attack_target()
	combat._physics_process(0.25)
	_expect(combat.current_target == enemy, "idle unit auto-acquires hostile in range")
	_expect(combat.target_source == CombatComponent.TargetSource.AUTO, "auto target source is AUTO")
	enemy.global_position = Vector3(148.0, 0.0, 128.0)
	combat._physics_process(0.25)
	_expect(combat.current_target == null, "auto target clears after leaving range")
	_expect(not movement.has_path(), "auto target does not start pursuit")

func _verify_dead_target_clears_pursuit(infantry: EntityBase, enemy: EntityBase) -> void:
	_reset_entity(infantry, Vector3(128.0, 0.0, 128.0))
	_reset_entity(enemy, Vector3(148.0, 0.0, 128.0))
	var combat := infantry.get_component(&"CombatComponent") as CombatComponent
	var movement := infantry.get_component(&"MovementComponent") as MovementComponent
	var health := enemy.get_health_component() as HealthComponent
	health.set_current_health(health.max_health)
	_expect(infantry.execute_command(&"attack", {"target_entity": enemy}), "attack command starts before target death")
	combat._physics_process(0.5)
	_expect(movement.has_path(), "unit is pursuing before target death")
	enemy.apply_damage(health.max_health, infantry)
	_expect(combat.current_target == null, "dead target clears combat target")
	_expect(not movement.has_path(), "dead target clears pursuit path")

func _drive_until_in_range(infantry: EntityBase, enemy: EntityBase, max_steps: int = 80) -> void:
	var combat := infantry.get_component(&"CombatComponent") as CombatComponent
	var movement := infantry.get_component(&"MovementComponent") as MovementComponent
	for i in range(max_steps):
		if combat.is_target_in_attack_range(enemy):
			return
		combat._physics_process(0.25)
		movement._process(0.25)

func _reset_entity(entity: EntityBase, position: Vector3) -> void:
	entity.global_position = position
	var movement := entity.get_component(&"MovementComponent") as MovementComponent
	if movement != null:
		movement.clear_path()
	var combat := entity.get_component(&"CombatComponent") as CombatComponent
	if combat != null:
		combat.clear_attack_target()
	var health := entity.get_health_component() as HealthComponent
	if health != null:
		health.destroy_on_death = false
		health.set_current_health(health.max_health)

func _configure_combat(entity: EntityBase) -> void:
	var combat := entity.get_component(&"CombatComponent") as CombatComponent
	if combat == null:
		return
	combat.attack_range = 6.0
	combat.acquisition_range = 6.0
	combat.pursue_stop_distance = 5.0
	combat.pursuit_repath_interval = 0.25
	combat.scan_interval = 0.1

func _make_level(placements: Array) -> Level:
	var map_data = TerrainMapDataScript.new()
	map_data.create_flat_grass_map(Vector2i(2, 2), 0.0)
	map_data.entity_placements = placements
	_expect(TerrainSerializerScript.save(map_data, TEMP_MAP_PATH, "v32 Pursuit"), "temporary map saves")
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

func _find_entity(root_node: Node, display_name: String, team_id: int) -> EntityBase:
	for child in root_node.get_children():
		var entity := child as EntityBase
		if entity != null and entity.display_name == display_name and entity.team_id == team_id:
			return entity
	return null

func _clear_projectiles() -> void:
	for projectile in get_nodes_in_group(&"combat_projectiles"):
		if is_instance_valid(projectile):
			projectile.free()

func _expect(condition: bool, message: String) -> void:
	if condition:
		print("PASS: %s" % message)
	else:
		_failures += 1
		push_error("FAIL: %s" % message)
