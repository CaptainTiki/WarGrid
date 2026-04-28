extends CommandBase
class_name StopCommand

func _init() -> void:
	command_id = &"stop"
	display_name = "Stop"
	tooltip = "Stop the current movement command."
	hotkey = &"command_stop"
	target_mode = TargetMode.NONE

func can_execute(entity: EntityBase, context: Dictionary) -> bool:
	if not super.can_execute(entity, context):
		return false
	return entity.get_component(&"MovementComponent") is MovementComponent

func execute(entity: EntityBase, context: Dictionary) -> void:
	var movement := entity.get_component(&"MovementComponent") as MovementComponent
	if movement != null:
		movement.clear_path()
