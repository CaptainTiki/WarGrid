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
	if not context.has("target_position") or typeof(context["target_position"]) != TYPE_VECTOR3:
		return false
	var production := _get_production_component(entity)
	return production != null and production.has_method("set_rally_point")

func execute(entity: EntityBase, context: Dictionary) -> bool:
	var production := _get_production_component(entity)
	if production == null or not production.has_method("set_rally_point"):
		return false
	var target_position: Vector3 = context["target_position"]
	production.set_rally_point(target_position)
	return true

func _get_production_component(entity: EntityBase) -> Node:
	if entity == null:
		return null
	return entity.get_component(&"ProductionComponent")
