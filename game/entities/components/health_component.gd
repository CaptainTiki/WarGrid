extends Node
class_name HealthComponent

signal health_changed(current_health: float, max_health: float)
signal died()

@export_node_path("Node3D") var entity_parent: NodePath
@export var max_health: float = 100.0
@export var destroy_on_death: bool = true

var current_health: float = 0.0
var _died := false
var _warned_missing_entity_parent := false

func _ready() -> void:
	current_health = max_health
	died.connect(_on_died)
	health_changed.emit(current_health, max_health)
	var entity := get_entity_parent()
	if entity != null:
		entity.add_to_group(&"targetable_entities")

func is_alive() -> bool:
	return current_health > 0.0 and not _died

func apply_damage(amount: float, source: EntityBase = null) -> bool:
	if amount <= 0.0 or not is_alive():
		return false
	current_health = maxf(current_health - amount, 0.0)
	health_changed.emit(current_health, max_health)
	if current_health <= 0.0:
		_die()
	return true

func heal(amount: float) -> bool:
	if amount <= 0.0 or not is_alive():
		return false
	var previous_health := current_health
	current_health = minf(current_health + amount, max_health)
	if is_equal_approx(previous_health, current_health):
		return false
	health_changed.emit(current_health, max_health)
	return true

func set_current_health(value: float) -> void:
	current_health = clampf(value, 0.0, max_health)
	_died = current_health <= 0.0
	health_changed.emit(current_health, max_health)

func get_entity_parent() -> EntityBase:
	var entity := get_node_or_null(entity_parent) as EntityBase
	if entity != null:
		return entity
	if not _warned_missing_entity_parent:
		push_warning("%s has no entity_parent assigned." % name)
		_warned_missing_entity_parent = true
	return null

func _on_died() -> void:
	var entity := get_entity_parent()
	if entity == null:
		return
	var entity_name := entity.display_name
	if entity_name.strip_edges() == "":
		entity_name = entity.name
	print("%s died." % entity_name)
	entity.set_selected(false)
	_clear_attackers_current_target(entity)
	if destroy_on_death:
		entity.queue_free()

func _die() -> void:
	if _died:
		return
	# Guard every death path so died is emitted exactly once.
	_died = true
	died.emit()

func _clear_attackers_current_target(entity: EntityBase) -> void:
	if entity == null or not is_inside_tree():
		return
	for command_component in get_tree().get_nodes_in_group(&"command_components"):
		if command_component != null and command_component.has_method("clear_current_target_if_matches"):
			command_component.clear_current_target_if_matches(entity)
	for combat_component in get_tree().get_nodes_in_group(&"combat_components"):
		if combat_component != null and combat_component.has_method("clear_current_target_if_matches"):
			combat_component.clear_current_target_if_matches(entity)
