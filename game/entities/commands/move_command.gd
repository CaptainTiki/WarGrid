extends CommandBase
class_name MoveCommand

func _init() -> void:
	command_id = &"move"
	display_name = "Move"
	tooltip = "Move to a terrain point."
	hotkey = &"command_move"
	target_mode = TargetMode.POINT

func can_execute(entity: EntityBase, context: Dictionary) -> bool:
	if not super.can_execute(entity, context):
		return false
	if not context.has("target_position"):
		return false
	if typeof(context["target_position"]) != TYPE_VECTOR3:
		return false
	return entity.get_component(&"MovementComponent") is MovementComponent

func execute(entity: EntityBase, context: Dictionary) -> void:
	var movement := entity.get_component(&"MovementComponent") as MovementComponent
	if movement == null:
		return
	var target: Vector3 = context["target_position"]
	var path: Array[Vector3] = [target]
	movement.set_path(path)
