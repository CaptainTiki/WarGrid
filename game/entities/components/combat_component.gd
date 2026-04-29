extends Node
class_name CombatComponent

enum TargetSource {
	NONE,
	AUTO,
	COMMAND,
}

@export_node_path("Node3D") var entity_parent: NodePath
@export var attack_damage: float = 25.0
@export var attack_cooldown: float = 1.0
@export var attack_range: float = 0.0
@export var projectile_scene: PackedScene
@export var auto_acquire_enabled: bool = true
@export var acquisition_range: float = 12.0
@export var scan_interval: float = 0.25
@export var stop_auto_acquire_suppression: float = 1.25

var current_target: EntityBase = null
var target_source := TargetSource.NONE

var _cooldown_remaining := 0.0
var _scan_remaining := 0.0
var _auto_acquire_suppression_remaining := 0.0
var _warned_missing_entity_parent := false
var _logged_command_target_out_of_range := false

func _ready() -> void:
	add_to_group(&"combat_components")

func set_attack_target(target: Node, source: int) -> bool:
	var entity_target := target as EntityBase
	if not _is_valid_target(entity_target):
		if source == TargetSource.COMMAND:
			clear_attack_target()
		return false
	if source == TargetSource.AUTO and has_valid_attack_target():
		return false
	if projectile_scene == null:
		return false
	current_target = entity_target
	target_source = clampi(source, TargetSource.NONE, TargetSource.COMMAND)
	_logged_command_target_out_of_range = false
	_cooldown_remaining = 0.0
	_sync_command_target(current_target)
	var attacker := get_entity_parent()
	if attacker != null and _is_target_in_attack_range(current_target):
		_try_fire()
		print("%s started attacking %s." % [_get_entity_display_name(attacker), _get_entity_display_name(current_target)])
	return true

func clear_attack_target(suppress_auto_acquire: bool = false) -> void:
	var attacker := get_entity_parent()
	var had_target := current_target != null
	current_target = null
	target_source = TargetSource.NONE
	_cooldown_remaining = 0.0
	_logged_command_target_out_of_range = false
	_sync_command_target(null)
	if suppress_auto_acquire:
		_auto_acquire_suppression_remaining = stop_auto_acquire_suppression
	if had_target and attacker != null:
		print("%s target cleared." % _get_entity_display_name(attacker))

func get_attack_target() -> Node:
	return current_target

func has_valid_attack_target() -> bool:
	return _is_valid_target(current_target)

func start_attack(target: EntityBase) -> bool:
	return set_attack_target(target, TargetSource.COMMAND)

func stop_attack() -> void:
	clear_attack_target()

func clear_current_target_if_matches(target: EntityBase) -> void:
	if current_target == target:
		clear_attack_target()

func has_valid_target() -> bool:
	return has_valid_attack_target()

func get_entity_parent() -> EntityBase:
	var entity := get_node_or_null(entity_parent) as EntityBase
	if entity != null:
		return entity
	if not _warned_missing_entity_parent:
		push_warning("%s has no entity_parent assigned." % name)
		_warned_missing_entity_parent = true
	return null

func _physics_process(delta: float) -> void:
	_auto_acquire_suppression_remaining = maxf(_auto_acquire_suppression_remaining - delta, 0.0)
	if current_target != null:
		_tick_current_target(delta)
		return
	_tick_auto_acquire(delta)

func _tick_current_target(delta: float) -> void:
	if not _is_valid_target(current_target):
		clear_attack_target()
		return
	if not _is_target_in_attack_range(current_target):
		if target_source == TargetSource.AUTO:
			clear_attack_target()
		elif not _logged_command_target_out_of_range:
			var attacker := get_entity_parent()
			if attacker != null:
				print("%s target out of range; pursuit not implemented yet." % _get_entity_display_name(attacker))
			_logged_command_target_out_of_range = true
		return
	_logged_command_target_out_of_range = false
	if _cooldown_remaining > 0.0:
		_cooldown_remaining = maxf(_cooldown_remaining - delta, 0.0)
		if _cooldown_remaining > 0.0:
			return
	_try_fire()

func _tick_auto_acquire(delta: float) -> void:
	if not auto_acquire_enabled or _auto_acquire_suppression_remaining > 0.0:
		return
	if not _is_idle_for_auto_acquire():
		return
	_scan_remaining = maxf(_scan_remaining - delta, 0.0)
	if _scan_remaining > 0.0:
		return
	_scan_remaining = maxf(scan_interval, 0.05)
	var target := _find_auto_acquire_target()
	if target == null:
		return
	if set_attack_target(target, TargetSource.AUTO):
		var attacker := get_entity_parent()
		if attacker != null:
			print("%s auto-acquired %s." % [_get_entity_display_name(attacker), _get_entity_display_name(target)])

func _try_fire() -> bool:
	if projectile_scene == null:
		return false
	var attacker := get_entity_parent()
	if attacker == null or not is_instance_valid(attacker) or attacker.is_queued_for_deletion():
		clear_attack_target()
		return false
	if not _is_valid_target(current_target):
		clear_attack_target()
		return false
	if not _is_target_in_attack_range(current_target):
		return false
	var projectile := projectile_scene.instantiate()
	if projectile == null:
		return false
	var spawn_parent := get_tree().current_scene
	if spawn_parent == null:
		spawn_parent = get_tree().root
	spawn_parent.add_child(projectile)
	if projectile is Node3D:
		var projectile_node := projectile as Node3D
		projectile_node.global_position = _get_projectile_spawn_position(attacker)
	if projectile.has_method("setup"):
		projectile.setup(attacker, current_target, attack_damage)
	_cooldown_remaining = attack_cooldown
	return true

func _find_auto_acquire_target() -> EntityBase:
	var attacker := get_entity_parent()
	if attacker == null:
		return null
	var best_target: EntityBase = null
	var best_distance := acquisition_range
	for node in get_tree().get_nodes_in_group(&"targetable_entities"):
		var target := node as EntityBase
		if not _is_valid_target(target):
			continue
		var distance := attacker.global_position.distance_to(target.global_position)
		if distance <= best_distance:
			best_distance = distance
			best_target = target
	return best_target

func _is_idle_for_auto_acquire() -> bool:
	var attacker := get_entity_parent()
	if attacker == null:
		return false
	var movement := attacker.get_component(&"MovementComponent")
	if movement != null and movement.has_method("has_path") and movement.has_path():
		return false
	return true

func _is_valid_target(target: EntityBase) -> bool:
	var attacker := get_entity_parent()
	if attacker == null or not is_instance_valid(attacker):
		return false
	if target == null or not is_instance_valid(target):
		return false
	if target == attacker:
		return false
	if target.is_queued_for_deletion():
		return false
	if not target.can_be_attacked():
		return false
	return attacker.is_hostile_to(target)

func _is_target_in_attack_range(target: EntityBase) -> bool:
	var attacker := get_entity_parent()
	if attacker == null or target == null:
		return false
	var range := attack_range if attack_range > 0.0 else acquisition_range
	return attacker.global_position.distance_to(target.global_position) <= range

func _sync_command_target(target: EntityBase) -> void:
	var attacker := get_entity_parent()
	if attacker == null:
		return
	var command_component := attacker.get_component(&"CommandComponent") as CommandComponent
	if command_component == null:
		return
	if target == null:
		command_component.clear_current_target()
	else:
		command_component.set_current_target(target)

func _get_projectile_spawn_position(attacker: EntityBase) -> Vector3:
	return attacker.global_position + Vector3.UP * 0.75

func _get_entity_display_name(entity: EntityBase) -> String:
	if entity == null:
		return "Unknown"
	if entity.display_name.strip_edges() != "":
		return entity.display_name
	return entity.name
