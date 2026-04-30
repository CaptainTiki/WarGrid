extends CommandBase
class_name TrainWorkerCommand

func _init() -> void:
	command_id = &"train_worker"
	display_name = "Train Worker"
	tooltip = "Train a Worker unit."
	hotkey = &"command_train_worker"
	target_mode = TargetMode.NONE

func can_execute(entity: EntityBase, context: Dictionary) -> bool:
	if not super.can_execute(entity, context):
		return false
	var production := entity.get_component(&"ProductionComponent")
	return production != null and production.has_method("get_recipe") and production.get_recipe(command_id) != null

func execute(entity: EntityBase, context: Dictionary) -> bool:
	var production := entity.get_component(&"ProductionComponent")
	if production == null or not production.has_method("queue_recipe_by_id"):
		return false
	return production.queue_recipe_by_id(command_id)
