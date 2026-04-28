extends CommandBase
class_name AttackCommand

@export var placeholder_damage: float = 25.0

func _init() -> void:
	command_id = &"attack"
	display_name = "Attack"
	tooltip = "Attack a target."
	hotkey = &"command_attack"
	target_mode = TargetMode.ENTITY

func can_execute(entity: EntityBase, context: Dictionary) -> bool:
	if not super.can_execute(entity, context):
		return false
	var target := context.get("target_entity") as EntityBase
	if target == null or target == entity:
		return false
	return target.has_health() and target.is_alive()

func execute(entity: EntityBase, context: Dictionary) -> bool:
	var target := context.get("target_entity") as EntityBase
	if target == null or not can_execute(entity, context):
		return false
	if not target.apply_damage(placeholder_damage, entity):
		return false
	print("%s attacked %s for %.1f damage." % [
		_get_entity_display_name(entity),
		_get_entity_display_name(target),
		placeholder_damage,
	])
	return true

func _get_entity_display_name(entity: EntityBase) -> String:
	if entity.display_name.strip_edges() != "":
		return entity.display_name
	return entity.name
