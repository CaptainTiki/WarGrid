extends Node3D
class_name EntityBase

@export var display_name: String = ""
@export var team_id: int = 0
@export var attackable: bool = true

@onready var _components_root: Node = get_node_or_null("Components")

func get_component(component_name: StringName) -> Node:
	var components := get_components_root()
	if components == null:
		return null
	return components.get_node_or_null(NodePath(String(component_name)))

func get_components_root() -> Node:
	if _components_root == null:
		_components_root = get_node_or_null("Components")
	return _components_root

func get_available_commands() -> Array[CommandBase]:
	var command_component := get_component(&"CommandComponent")
	if command_component == null or not command_component.has_method("get_available_commands"):
		return []
	return command_component.get_available_commands(self)

func get_team_id() -> int:
	return team_id

func is_same_team(other: Node) -> bool:
	if other == null or not is_instance_valid(other) or not other.has_method("get_team_id"):
		return false
	return team_id != 0 and team_id == other.get_team_id()

func is_hostile_to(other: Node) -> bool:
	if other == null or not is_instance_valid(other) or not other.has_method("get_team_id"):
		return false
	var other_team: int = other.get_team_id()
	if team_id == 0 or other_team == 0:
		return false
	return team_id != other_team

func can_be_attacked() -> bool:
	return attackable and has_health() and is_alive()

func has_command(command_id: StringName) -> bool:
	var command_component := get_component(&"CommandComponent")
	if command_component == null or not command_component.has_method("has_command"):
		return false
	return command_component.has_command(command_id)

func get_footprint_component() -> Node:
	return get_component(&"EntityFootprintComponent")

func get_footprint_radius() -> float:
	var footprint := get_footprint_component()
	if footprint == null:
		return 0.0
	if footprint.has_method("get_separation_radius"):
		return footprint.get_separation_radius()
	return 0.0

func get_health_component() -> Node:
	return get_component(&"HealthComponent")

func has_health() -> bool:
	if is_queued_for_deletion():
		return false
	var health := get_health_component()
	return health != null and health.has_method("apply_damage")

func is_alive() -> bool:
	if is_queued_for_deletion():
		return false
	var health := get_health_component()
	if health == null or not health.has_method("is_alive"):
		return true
	return health.is_alive()

func apply_damage(amount: float, source: EntityBase = null) -> bool:
	if is_queued_for_deletion():
		return false
	var health := get_health_component()
	if health == null or not health.has_method("apply_damage"):
		return false
	return health.apply_damage(amount, source)

func execute_command(command_id: StringName, context: Dictionary = {}) -> bool:
	var command_component := get_component(&"CommandComponent")
	if command_component == null or not command_component.has_method("execute_command"):
		return false
	return command_component.execute_command(command_id, self, context)

func set_selected(value: bool) -> void:
	pass
