extends SceneTree

const LevelScene := preload("res://level/level.tscn")
const TerrainMapDataScript := preload("res://terrain/terrain_map_data.gd")
const TerrainSerializerScript := preload("res://terrain/terrain_serializer.gd")
const EntityPlacementDataScript := preload("res://game/entities/placement/entity_placement_data.gd")

const TEMP_MAP_PATH := "res://tools/v33_auto_pursuit_leash_temp.res"

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
		_make_placement(&"enemy_dummy_unit", Vector3(132.0, 0.0, 128.0), 2),
		_make_placement(&"enemy_test_hq", Vector3(156.0, 0.0, 128.0), 2),
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
		_verify_enemy_unit_auto_pursues(infantry, enemy)
		_verify_auto_acquire_and_local_pursuit(infantry, enemy)
		_verify_leash_break_and_return_home(infantry, enemy)
		_verify_auto_target_death_clears(infantry, enemy)
		_verify_commanded_attack_ignores_leash(infantry, enemy_hq)
		_verify_stop_cancels_auto_pursuit(infantry, enemy)
		_verify_move_updates_home_and_overrides_target(infantry, enemy, level.terrain)

	level.free()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(TEMP_MAP_PATH))
	if _failures == 0:
		print("v33 auto pursuit leash verification passed.")
		quit(0)
	else:
		push_error("v33 auto pursuit leash verification failed with %d failure(s)." % _failures)
		quit(1)

func _verify_auto_acquire_and_local_pursuit(infantry: EntityBase, enemy: EntityBase) -> void:
	_reset_entity(infantry, Vector3(128.0, 0.0, 128.0))
	_reset_entity(enemy, Vector3(132.0, 0.0, 128.0))
	var combat := infantry.get_component(&"CombatComponent") as CombatComponent
	var movement := infantry.get_component(&"MovementComponent") as MovementComponent
	combat._physics_process(0.25)
	_expect(combat.current_target == enemy, "auto-acquire still selects hostile in range")
	_expect(combat.target_source == CombatComponent.TargetSource.AUTO, "auto-acquired target source is AUTO")
	enemy.global_position = Vector3(136.0, 0.0, 128.0)
	combat._physics_process(0.25)
	_expect(combat.current_target == enemy, "auto target is kept while inside leash")
	_expect(movement.has_path(), "auto target outside attack range starts pursuit")
	_drive_until_in_range(infantry, enemy)
	combat._physics_process(0.25)
	_expect(combat.is_target_in_attack_range(enemy), "auto pursuit reaches attack range")
	_expect(not movement.has_path(), "auto pursuit stops movement once in range")

func _verify_enemy_unit_auto_pursues(infantry: EntityBase, enemy: EntityBase) -> void:
	_reset_entity(infantry, Vector3(128.0, 0.0, 128.0))
	_reset_entity(enemy, Vector3(132.0, 0.0, 128.0))
	var enemy_combat := enemy.get_component(&"CombatComponent") as CombatComponent
	var enemy_movement := enemy.get_component(&"MovementComponent") as MovementComponent
	_expect(enemy_movement != null, "enemy dummy has movement for auto pursuit")
	enemy_combat._physics_process(0.25)
	_expect(enemy_combat.current_target == infantry, "enemy dummy auto-acquires nearby player unit")
	infantry.global_position = Vector3(137.0, 0.0, 128.0)
	enemy_combat._physics_process(0.25)
	_expect(enemy_combat.current_target == infantry, "enemy dummy keeps auto target inside leash")
	_expect(enemy_movement.has_path(), "enemy dummy pursues player unit inside leash")

func _verify_leash_break_and_return_home(infantry: EntityBase, enemy: EntityBase) -> void:
	_reset_entity(infantry, Vector3(128.0, 0.0, 128.0))
	_reset_entity(enemy, Vector3(132.0, 0.0, 128.0))
	var combat := infantry.get_component(&"CombatComponent") as CombatComponent
	var movement := infantry.get_component(&"MovementComponent") as MovementComponent
	combat._physics_process(0.25)
	enemy.global_position = Vector3(136.0, 0.0, 128.0)
	_drive_steps(infantry, 8)
	_expect(infantry.global_position.distance_to(combat.home_position) > 0.5, "unit moved away from home during auto pursuit")
	enemy.global_position = Vector3(146.0, 0.0, 128.0)
	combat._physics_process(0.25)
	_expect(combat.current_target == null, "auto target clears when leash breaks")
	_expect(movement.has_path(), "leash break starts return-home movement")
	_drive_until_home(infantry)
	_expect(infantry.global_position.distance_to(combat.home_position) <= 0.35, "unit returns to home after leash break")
	_expect(not movement.has_path(), "unit idles after reaching home")

func _verify_auto_target_death_clears(infantry: EntityBase, enemy: EntityBase) -> void:
	_reset_entity(infantry, Vector3(128.0, 0.0, 128.0))
	_reset_entity(enemy, Vector3(132.0, 0.0, 128.0))
	var combat := infantry.get_component(&"CombatComponent") as CombatComponent
	var health := enemy.get_health_component() as HealthComponent
	combat._physics_process(0.25)
	_expect(combat.current_target == enemy, "auto target acquired before death")
	enemy.apply_damage(health.max_health, infantry)
	_expect(combat.current_target == null, "dead auto target clears combat target")

func _verify_commanded_attack_ignores_leash(infantry: EntityBase, enemy_hq: EntityBase) -> void:
	_reset_entity(infantry, Vector3(128.0, 0.0, 128.0))
	_reset_entity(enemy_hq, Vector3(156.0, 0.0, 128.0))
	var combat := infantry.get_component(&"CombatComponent") as CombatComponent
	var movement := infantry.get_component(&"MovementComponent") as MovementComponent
	combat.leash_range = 6.0
	_expect(not combat.is_target_within_leash(enemy_hq), "enemy HQ starts outside auto leash")
	_expect(infantry.execute_command(&"attack", {"target_entity": enemy_hq}), "commanded attack outside leash is accepted")
	combat._physics_process(0.25)
	_expect(combat.current_target == enemy_hq, "commanded target remains outside leash")
	_expect(movement.has_path(), "commanded attack outside leash still pursues")

func _verify_stop_cancels_auto_pursuit(infantry: EntityBase, enemy: EntityBase) -> void:
	_reset_entity(infantry, Vector3(128.0, 0.0, 128.0))
	_reset_entity(enemy, Vector3(132.0, 0.0, 128.0))
	var combat := infantry.get_component(&"CombatComponent") as CombatComponent
	var movement := infantry.get_component(&"MovementComponent") as MovementComponent
	combat._physics_process(0.25)
	enemy.global_position = Vector3(136.0, 0.0, 128.0)
	combat._physics_process(0.25)
	_expect(movement.has_path(), "unit is auto-pursuing before stop")
	_expect(infantry.execute_command(&"stop", {}), "stop command executes during auto pursuit")
	_expect(combat.current_target == null, "stop clears auto target")
	_expect(not movement.has_path(), "stop clears auto pursuit movement")

func _verify_move_updates_home_and_overrides_target(infantry: EntityBase, enemy: EntityBase, terrain: Terrain) -> void:
	_reset_entity(infantry, Vector3(128.0, 0.0, 128.0))
	_reset_entity(enemy, Vector3(132.0, 0.0, 128.0))
	var combat := infantry.get_component(&"CombatComponent") as CombatComponent
	var movement := infantry.get_component(&"MovementComponent") as MovementComponent
	combat._physics_process(0.25)
	_expect(combat.current_target == enemy, "auto target acquired before move override")
	var new_home := Vector3(140.0, 0.0, 128.0)
	_expect(infantry.execute_command(&"move", {"target_position": new_home, "terrain": terrain}), "move command executes during target behavior")
	_expect(combat.current_target == null, "move clears current target")
	_expect(movement.has_path(), "move replaces target movement")
	_expect(combat.home_position.distance_to(new_home) <= 0.01, "move command updates home position")

func _drive_until_in_range(infantry: EntityBase, enemy: EntityBase, max_steps: int = 80) -> void:
	var combat := infantry.get_component(&"CombatComponent") as CombatComponent
	for i in range(max_steps):
		if combat.is_target_in_attack_range(enemy):
			return
		_drive_steps(infantry, 1)

func _drive_until_home(infantry: EntityBase, max_steps: int = 120) -> void:
	var combat := infantry.get_component(&"CombatComponent") as CombatComponent
	for i in range(max_steps):
		if infantry.global_position.distance_to(combat.home_position) <= 0.35:
			return
		_drive_steps(infantry, 1)

func _drive_steps(entity: EntityBase, steps: int) -> void:
	var combat := entity.get_component(&"CombatComponent") as CombatComponent
	var movement := entity.get_component(&"MovementComponent") as MovementComponent
	for i in range(steps):
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
		combat.set_home_position(position)
	var health := entity.get_health_component() as HealthComponent
	if health != null:
		health.destroy_on_death = false
		health.set_current_health(health.max_health)

func _configure_combat(entity: EntityBase) -> void:
	var combat := entity.get_component(&"CombatComponent") as CombatComponent
	if combat == null:
		return
	combat.attack_range = 4.0
	combat.acquisition_range = 6.0
	combat.leash_range = 12.0
	combat.pursue_stop_distance = 3.0
	combat.pursuit_repath_interval = 0.25
	combat.return_to_home_on_leash_break = true
	combat.scan_interval = 0.1

func _make_level(placements: Array) -> Level:
	var map_data = TerrainMapDataScript.new()
	map_data.create_flat_grass_map(Vector2i(2, 2), 0.0)
	map_data.entity_placements = placements
	_expect(TerrainSerializerScript.save(map_data, TEMP_MAP_PATH, "v33 Auto Pursuit Leash"), "temporary map saves")
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

func _expect(condition: bool, message: String) -> void:
	if condition:
		print("PASS: %s" % message)
	else:
		_failures += 1
		push_error("FAIL: %s" % message)
