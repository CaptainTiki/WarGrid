extends SceneTree

const EntityBaseScript := preload("res://game/entities/entity_base.gd")
const CommandComponentScript := preload("res://game/entities/components/command_component.gd")
const HealthComponentScript := preload("res://game/entities/components/health_component.gd")
const CombatComponentScript := preload("res://game/entities/components/combat_component.gd")
const AttackCommandScript := preload("res://game/entities/commands/attack_command.gd")
const StopCommandScript := preload("res://game/entities/commands/stop_command.gd")
const ProjectileScene := preload("res://game/entities/projectiles/basic_projectile.tscn")

var _failures := 0
var _ran := false
var _died_count := 0

func _process(_delta: float) -> bool:
	if _ran:
		return false
	_ran = true
	_run()
	return true

func _run() -> void:
	var world := Node3D.new()
	root.add_child(world)

	var attacker = _make_entity("Attacker", true, true)
	var target = _make_entity("Target", true, false)
	attacker.team_id = 1
	target.team_id = 2
	world.add_child(attacker)
	world.add_child(target)
	attacker.global_position = Vector3.ZERO
	target.global_position = Vector3(1.0, 0.0, 0.0)

	var target_health = target.get_health_component()
	target_health.died.connect(_on_target_died)
	var combat = attacker.get_component(&"CombatComponent")

	combat.attack_damage = 25.0
	combat.attack_cooldown = 1.0
	_expect(attacker.execute_command(&"attack", {"target_entity": target}), "attack command starts sustained attack")
	_expect(is_equal_approx(target_health.current_health, 100.0), "attack command does not apply instant damage")
	_drive_projectiles_until_clear()
	_expect(is_equal_approx(target_health.current_health, 75.0), "projectile impact applies non-lethal damage")
	_expect(_died_count == 0, "non-lethal projectile does not emit died")

	combat.attack_damage = 100.0
	combat._physics_process(1.0)
	_drive_projectiles_until_clear()
	_expect(is_equal_approx(target_health.current_health, 0.0), "projectile impact can kill target")
	_expect(_died_count == 1, "died signal emits once on lethal damage")
	_expect(not target_health.apply_damage(1.0, attacker), "dead target rejects repeated damage")
	_expect(_died_count == 1, "repeated damage does not emit died again")
	_expect(attacker.get_component(&"CommandComponent").current_target == null, "command target clears on target death")
	_expect(combat.current_target == null, "combat target clears on target death")
	_expect(not attacker.execute_command(&"attack", {"target_entity": target}), "queued target is rejected cleanly")

	var invalid_target = _make_entity("InvalidTarget", true, false)
	invalid_target.team_id = 2
	world.add_child(invalid_target)
	invalid_target.free()
	_expect(not is_instance_valid(invalid_target), "test target can become invalid")
	_expect(not attacker.execute_command(&"attack", {"target_entity": invalid_target}), "invalid target is rejected cleanly")
	_expect(not attacker.execute_command(&"attack", {"target_entity": Vector3.ZERO}), "non-entity target is rejected cleanly")

	var missing_health_target = _make_entity("NoHealthTarget", false, false)
	missing_health_target.team_id = 2
	world.add_child(missing_health_target)
	_expect(not attacker.execute_command(&"attack", {"target_entity": missing_health_target}), "target without health is rejected cleanly")

	var friendly_target = _make_entity("FriendlyTarget", true, false)
	friendly_target.team_id = 1
	world.add_child(friendly_target)
	_expect(not attacker.execute_command(&"attack", {"target_entity": friendly_target}), "friendly target is rejected cleanly")

	var neutral_target = _make_entity("NeutralTarget", true, false)
	neutral_target.team_id = 0
	world.add_child(neutral_target)
	_expect(not attacker.execute_command(&"attack", {"target_entity": neutral_target}), "neutral target is rejected cleanly")

	var stop_target = _make_entity("StopTarget", true, false)
	stop_target.team_id = 2
	world.add_child(stop_target)
	stop_target.global_position = Vector3(2.0, 0.0, 0.0)
	_expect(attacker.execute_command(&"attack", {"target_entity": stop_target}), "attack command can start on another target")
	_expect(attacker.execute_command(&"stop", {}), "stop command executes")
	_expect(combat.current_target == null, "stop command clears combat target")
	var projectile_count_after_stop := get_nodes_in_group(&"combat_projectiles").size()
	combat._physics_process(1.0)
	_expect(get_nodes_in_group(&"combat_projectiles").size() == projectile_count_after_stop, "stop command prevents new projectiles")

	if _failures == 0:
		print("Attack/death lifecycle verification passed.")
		quit(0)
	else:
		push_error("Attack/death lifecycle verification failed with %d failure(s)." % _failures)
		quit(1)

func _make_entity(entity_name: String, with_health: bool, with_attack: bool):
	var entity = EntityBaseScript.new()
	entity.name = entity_name
	entity.display_name = entity_name

	var components := Node.new()
	components.name = "Components"
	entity.add_child(components)

	if with_attack:
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
		components.add_child(combat_component)

	if with_health:
		var health_component = HealthComponentScript.new()
		health_component.name = "HealthComponent"
		health_component.entity_parent = NodePath("../..")
		health_component.max_health = 100.0
		components.add_child(health_component)

	return entity

func _drive_projectiles_until_clear(max_steps: int = 120) -> void:
	for i in range(max_steps):
		var projectiles := get_nodes_in_group(&"combat_projectiles")
		if projectiles.is_empty():
			return
		for projectile in projectiles:
			if is_instance_valid(projectile) and not projectile.is_queued_for_deletion():
				projectile._process(0.1)
			if is_instance_valid(projectile) and projectile.is_queued_for_deletion():
				projectile.free()

func _expect(condition: bool, message: String) -> void:
	if condition:
		print("PASS: %s" % message)
	else:
		_failures += 1
		push_error("FAIL: %s" % message)

func _on_target_died() -> void:
	_died_count += 1
