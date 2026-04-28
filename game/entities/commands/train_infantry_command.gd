extends CommandBase
class_name TrainInfantryCommand

func _init() -> void:
	command_id = &"train_infantry"
	display_name = "Train Infantry"
	tooltip = "Queue infantry training."
	hotkey = &"command_train_infantry"
	target_mode = TargetMode.NONE

func can_execute(entity: EntityBase, context: Dictionary) -> bool:
	return super.can_execute(entity, context)

func execute(entity: EntityBase, context: Dictionary) -> bool:
	print("Train Infantry command placeholder executed for %s." % entity.name)
	return true
