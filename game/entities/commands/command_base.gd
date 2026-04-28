extends Resource
class_name CommandBase

enum TargetMode { NONE, POINT, ENTITY, AREA }

@export var command_id: StringName
@export var display_name: String = ""
@export_multiline var tooltip: String = ""
@export var hotkey: StringName
@export var target_mode := TargetMode.NONE

func can_execute(entity: EntityBase, context: Dictionary) -> bool:
	return entity != null

func execute(entity: EntityBase, context: Dictionary) -> void:
	pass
