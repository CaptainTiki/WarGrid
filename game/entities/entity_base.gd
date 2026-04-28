extends Node3D
class_name EntityBase

@export var display_name: String = ""
@export var team_id: int = 0

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

func has_command(command_id: StringName) -> bool:
	var command_component := get_component(&"CommandComponent")
	if command_component == null or not command_component.has_method("has_command"):
		return false
	return command_component.has_command(command_id)

func execute_command(command_id: StringName, context: Dictionary = {}) -> bool:
	var command_component := get_component(&"CommandComponent")
	if command_component == null or not command_component.has_method("execute_command"):
		return false
	return command_component.execute_command(command_id, self, context)

func set_selected(value: bool) -> void:
	pass
