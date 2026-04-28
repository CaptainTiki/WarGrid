extends Node
class_name CommandComponent

@export_node_path("Node3D") var entity_parent: NodePath
@export var commands: Array[CommandBase] = []

var _warned_missing_entity_parent := false

func get_entity_parent() -> EntityBase:
	var entity := get_node_or_null(entity_parent) as EntityBase
	if entity != null:
		return entity
	if not _warned_missing_entity_parent:
		push_warning("%s has no entity_parent assigned." % name)
		_warned_missing_entity_parent = true
	return null

func get_available_commands(entity: EntityBase = null) -> Array[CommandBase]:
	var available: Array[CommandBase] = []
	for command in commands:
		if command != null:
			available.append(command)
	return available

func has_command(command_id: StringName) -> bool:
	return _get_command(command_id) != null

func execute_command(command_id: StringName, entity: EntityBase, context: Dictionary) -> bool:
	var command := _get_command(command_id)
	if command == null:
		return false
	if not command.can_execute(entity, context):
		return false
	command.execute(entity, context)
	return true

func _get_command(command_id: StringName) -> CommandBase:
	for command in commands:
		if command != null and command.command_id == command_id:
			return command
	return null
