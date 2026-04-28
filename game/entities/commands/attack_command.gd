extends CommandBase
class_name AttackCommand

func _init() -> void:
	command_id = &"attack"
	display_name = "Attack"
	tooltip = "Attack a target."
	hotkey = &"command_attack"
	target_mode = TargetMode.ENTITY

func can_execute(entity: EntityBase, context: Dictionary) -> bool:
	if not super.can_execute(entity, context):
		return false
	return context.get("target_entity") is EntityBase

func execute(entity: EntityBase, context: Dictionary) -> bool:
	var target := context.get("target_entity") as EntityBase
	if target == null:
		return false
	print("Attack command placeholder: %s attacking %s" % [entity.name, target.name])
	return true
