extends CommandBase
class_name GatherResourceCommand

func _init() -> void:
	command_id = &"gather"
	display_name = "Gather Crystals"
	tooltip = "Gather Tritanium Crystals from a crystal node."
	hotkey = &"command_gather"
	target_mode = TargetMode.ENTITY

func can_execute(entity: EntityBase, context: Dictionary) -> bool:
	if not super.can_execute(entity, context):
		return false
	var gather := entity.get_component(&"WorkerGatherComponent") as WorkerGatherComponent
	if gather == null:
		return false
	var target := context.get("target_entity") as EntityBase
	return target != null

func execute(entity: EntityBase, context: Dictionary) -> bool:
	var gather := entity.get_component(&"WorkerGatherComponent") as WorkerGatherComponent
	if gather == null:
		print("Gather failed: entity has no worker gather component.")
		return false
	var target := context.get("target_entity") as EntityBase
	return gather.start_gather(target)
