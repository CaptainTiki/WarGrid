extends CommandBase
class_name SetRallyPointCommand

func _init() -> void:
	command_id = &"set_rally_point"
	display_name = "Set Rally Point"
	tooltip = "Set a rally point."
	hotkey = &"command_set_rally_point"
	target_mode = TargetMode.POINT

func can_execute(entity: EntityBase, context: Dictionary) -> bool:
	if not super.can_execute(entity, context):
		return false
	return context.has("target_position") and typeof(context["target_position"]) == TYPE_VECTOR3

func execute(entity: EntityBase, context: Dictionary) -> bool:
	var target_position: Vector3 = context["target_position"]
	print("Set Rally Point placeholder for %s at %s" % [entity.name, target_position])
	return true
