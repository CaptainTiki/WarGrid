extends SceneTree

const EntityBaseScript := preload("res://game/entities/entity_base.gd")
const CommandComponentScript := preload("res://game/entities/components/command_component.gd")
const HealthComponentScript := preload("res://game/entities/components/health_component.gd")
const CombatComponentScript := preload("res://game/entities/components/combat_component.gd")
const MovementComponentScript := preload("res://game/entities/components/movement_component.gd")
const AttackCommandScript := preload("res://game/entities/commands/attack_command.gd")
const StopCommandScript := preload("res://game/entities/commands/stop_command.gd")
const ProjectileScene := preload("res://game/entities/projectiles/basic_projectile.tscn")

var _failures := 0
var _ran := false

func _process(_delta: float) -> bool:
	if _ran:
		return false
	_ran = true
	_run()
	return true

func _run() -> void:
	var world := Node3D.new()
	root.add_child(world)

	var attacker = _make_entity("Infantry", 1, true, true)
	var enemy_a = _make_entity("Enemy Dummy Unit", 2, true, false)
	var enemy_b = _make_entity("Enemy Test HQ", 2, true, false)
	var friendly = _make_entity("Friendly", 1, true, false)
	world.add_child(attacker)
	world.add_child(enemy_a)
	world.add_child(enemy_b)
	world.add_child(friendly)
	attacker.global_position = Vector3.ZERO
	enemy_a.global_position = Vector3(5.0, 0.0, 0.0)
	enemy_b.global_position = Vector3(8.0, 0.0, 0.0)
	friendly.global_position = Vector3(2.0, 0.0, 0.0)

	var combat := attacker.get_component(&"CombatComponent") as CombatComponent
	combat.acquisition_range = 6.0
	combat.attack_range = 6.0
	combat.scan_interval = 0.1
	combat._physics_process(0.1)
	_expect(combat.current_target == enemy_a, "idle combat auto-acquires hostile in range")
	_expect(combat.target_source == CombatComponent.TargetSource.AUTO, "auto-acquired target source is AUTO")
	_expect(combat.current_target != friendly, "friendly target is ignored")

	_expect(attacker.execute_command(&"attack", {"target_entity": enemy_b}), "commanded attack target is accepted")
	_expect(combat.current_target == enemy_b, "commanded attack replaces auto target")
	_expect(combat.target_source == CombatComponent.TargetSource.COMMAND, "commanded target source is COMMAND")
	combat._physics_process(0.5)
	_expect(combat.current_target == enemy_b, "auto-acquire does not steal command target")

	enemy_b.global_position = Vector3(30.0, 0.0, 0.0)
	var projectile_count_before_range_tick := get_nodes_in_group(&"combat_projectiles").size()
	combat._physics_process(1.0)
	_expect(combat.current_target == enemy_b, "command target is held out of range")
	_expect(get_nodes_in_group(&"combat_projectiles").size() == projectile_count_before_range_tick, "out-of-range command target does not fire")

	_expect(attacker.execute_command(&"stop", {}), "stop command executes")
	_expect(combat.current_target == null, "stop clears remembered combat target")
	var projectile_count_after_stop := get_nodes_in_group(&"combat_projectiles").size()
	combat._physics_process(0.5)
	_expect(get_nodes_in_group(&"combat_projectiles").size() == projectile_count_after_stop, "stop suppresses immediate auto-acquire")

	combat._physics_process(1.0)
	_expect(combat.current_target == enemy_a, "auto-acquire resumes after suppression")
	enemy_a.global_position = Vector3(30.0, 0.0, 0.0)
	combat._physics_process(0.1)
	_expect(combat.current_target == null, "auto target clears when it leaves range")

	var moving = _make_entity("Moving Infantry", 1, true, true, true)
	var moving_enemy = _make_entity("Moving Enemy", 2, true, false)
	world.add_child(moving)
	world.add_child(moving_enemy)
	moving.global_position = Vector3.ZERO
	moving_enemy.global_position = Vector3(4.0, 0.0, 0.0)
	var moving_combat := moving.get_component(&"CombatComponent") as CombatComponent
	var movement := moving.get_component(&"MovementComponent") as MovementComponent
	movement.set_path([Vector3(10.0, 0.0, 0.0)])
	moving_combat._physics_process(0.25)
	_expect(moving_combat.current_target == null, "moving entity does not auto-acquire while pathing")

	world.free()
	if _failures == 0:
		print("v31 target memory and auto-acquire verification passed.")
		quit(0)
	else:
		push_error("v31 target memory and auto-acquire verification failed with %d failure(s)." % _failures)
		quit(1)

func _make_entity(entity_name: String, team_id: int, with_health: bool, with_combat: bool, with_movement: bool = false):
	var entity = EntityBaseScript.new()
	entity.name = entity_name
	entity.display_name = entity_name
	entity.team_id = team_id

	var components := Node.new()
	components.name = "Components"
	entity.add_child(components)

	if with_movement:
		var movement_component = MovementComponentScript.new()
		movement_component.name = "MovementComponent"
		movement_component.move_root_path = NodePath("../..")
		components.add_child(movement_component)

	if with_combat:
		var command_component = CommandComponentScript.new()
		command_component.name = "CommandComponent"
		command_component.entity_parent = NodePath("../..")
		command_component.commands.append(AttackCommandScript.new())
		command_component.commands.append(StopCommandScript.new())
		components.add_child(command_component)

		var combat_component = CombatComponentScript.new()
		combat_component.name = "CombatComponent"
		combat_component.entity_parent = NodePath("../..")
		combat_component.projectile_scene = ProjectileScene
		combat_component.acquisition_range = 6.0
		combat_component.attack_range = 6.0
		combat_component.scan_interval = 0.1
		components.add_child(combat_component)

	if with_health:
		var health_component = HealthComponentScript.new()
		health_component.name = "HealthComponent"
		health_component.entity_parent = NodePath("../..")
		health_component.max_health = 100.0
		components.add_child(health_component)

	return entity

func _expect(condition: bool, message: String) -> void:
	if condition:
		print("PASS: %s" % message)
	else:
		_failures += 1
		push_error("FAIL: %s" % message)
