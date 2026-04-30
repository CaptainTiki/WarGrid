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
	return _is_valid_attack_target(entity, context.get("target_entity"))

func execute(entity: EntityBase, context: Dictionary) -> bool:
	_cancel_gather(entity)
	var invalid_reason := _get_invalid_attack_target_reason(entity, context.get("target_entity"))
	if invalid_reason != "":
		print("AttackCommand failed: %s" % invalid_reason)
		return false
	var target := context.get("target_entity") as EntityBase
	var combat := entity.get_component(&"CombatComponent")
	if combat == null or not combat.has_method("set_attack_target"):
		print("AttackCommand failed: attacker has no combat component.")
		return false
	var attacker_name := _get_entity_display_name(entity)
	var target_name := _get_entity_display_name(target)
	if not combat.set_attack_target(target, CombatComponent.TargetSource.COMMAND):
		print("AttackCommand failed: attack mode could not start.")
		return false
	print("%s accepted attack target %s." % [attacker_name, target_name])
	return true

func _is_valid_attack_target(entity: EntityBase, target_value: Variant) -> bool:
	return _get_invalid_attack_target_reason(entity, target_value) == ""

func _get_invalid_attack_target_reason(entity: EntityBase, target_value: Variant) -> String:
	if entity == null or not is_instance_valid(entity) or entity.is_queued_for_deletion():
		return "attacker is no longer valid."
	if typeof(target_value) != TYPE_OBJECT or not is_instance_valid(target_value):
		return "target is no longer valid."
	var target := target_value as EntityBase
	if target == null or target == entity:
		return "target is not attackable."
	if target.is_queued_for_deletion():
		return "target is queued for deletion."
	var combat := entity.get_component(&"CombatComponent")
	if combat == null or not combat.has_method("set_attack_target"):
		return "attacker has no combat component."
	if not target.attackable:
		return "target is not attackable."
	if not target.has_health():
		return "target has no health component."
	if not target.is_alive():
		return "target is no longer alive."
	if target.get_team_id() == 0:
		return "target is neutral."
	if entity.is_same_team(target):
		return "target is friendly."
	if not entity.is_hostile_to(target):
		return "target is not hostile."
	return ""

func _get_entity_display_name(entity: EntityBase) -> String:
	if entity.display_name.strip_edges() != "":
		return entity.display_name
	return entity.name

func _cancel_gather(entity: EntityBase) -> void:
	var gather := entity.get_component(&"WorkerGatherComponent")
	if gather != null and gather.has_method("cancel_gather"):
		gather.cancel_gather(true)
