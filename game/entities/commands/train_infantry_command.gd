extends CommandBase
class_name TrainInfantryCommand

func _init() -> void:
	command_id = &"train_infantry"
	display_name = "Train Infantry"
	tooltip = "Queue infantry training."
	hotkey = &"command_train_infantry"
	target_mode = TargetMode.NONE

func can_execute(entity: EntityBase, context: Dictionary) -> bool:
	if not super.can_execute(entity, context):
		return false
	var production := _get_production_component(entity)
	return production != null and production.has_method("get_recipe") and production.get_recipe(command_id) != null

func execute(entity: EntityBase, context: Dictionary) -> bool:
	var production := _get_production_component(entity)
	if production == null or not production.has_method("queue_recipe_by_id"):
		return false
	return production.queue_recipe_by_id(command_id)

func _get_production_component(entity: EntityBase) -> Node:
	if entity == null:
		return null
	return entity.get_component(&"ProductionComponent")
