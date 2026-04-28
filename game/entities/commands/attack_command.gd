extends CommandBase
class_name AttackCommand

func _init() -> void:
	command_id = &"attack"
	display_name = "Attack"
	tooltip = "Attack a target."
	hotkey = &"command_attack"
	target_mode = TargetMode.ENTITY

func can_execute(entity: EntityBase, context: Dictionary) -> bool:
	return super.can_execute(entity, context)

func execute(entity: EntityBase, context: Dictionary) -> void:
	pass
