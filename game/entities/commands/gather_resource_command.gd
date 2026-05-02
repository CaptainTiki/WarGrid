extends CommandBase
class_name GatherResourceCommand

func _init() -> void:
	command_id = &"gather"
	display_name = "Gather Crystals"
	tooltip = "Gather Tritanium Crystals near a target area."
	hotkey = &"command_gather"
	target_mode = TargetMode.POINT

func can_execute(entity: EntityBase, context: Dictionary) -> bool:
	if not super.can_execute(entity, context):
		return false
	var gather := entity.get_component(&"WorkerGatherComponent") as WorkerGatherComponent
	if gather == null:
		return false
	if context.has("target_position") and typeof(context["target_position"]) == TYPE_VECTOR3:
		return true
	var target := context.get("target_entity") as EntityBase
	return target != null and gather.can_gather_target(target)

func execute(entity: EntityBase, context: Dictionary) -> bool:
	var gather := entity.get_component(&"WorkerGatherComponent") as WorkerGatherComponent
	if gather == null:
		print("Gather failed: entity has no worker gather component.")
		return false
	if context.has("target_position") and typeof(context["target_position"]) == TYPE_VECTOR3:
		return gather.start_gather_location(context["target_position"], context.get("terrain") as Terrain)
	var target := context.get("target_entity") as EntityBase
	if target == null:
		print("Gather failed: no gather location or target.")
		return false
	return gather.start_gather(target)
