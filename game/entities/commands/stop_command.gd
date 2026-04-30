extends CommandBase
class_name StopCommand

func _init() -> void:
	command_id = &"stop"
	display_name = "Stop"
	tooltip = "Stop the current movement command."
	hotkey = &"command_stop"
	target_mode = TargetMode.NONE

func can_execute(entity: EntityBase, context: Dictionary) -> bool:
	if not super.can_execute(entity, context):
		return false
	var combat := entity.get_component(&"CombatComponent")
	var gather := entity.get_component(&"WorkerGatherComponent")
	return entity.get_component(&"MovementComponent") is MovementComponent or (combat != null and combat.has_method("clear_attack_target")) or (gather != null and gather.has_method("cancel_gather"))

func execute(entity: EntityBase, context: Dictionary) -> bool:
	var stopped := false
	var movement := entity.get_component(&"MovementComponent") as MovementComponent
	if movement != null:
		movement.clear_path()
		stopped = true
	var combat := entity.get_component(&"CombatComponent")
	if combat != null and combat.has_method("clear_attack_target"):
		combat.clear_attack_target()
		stopped = true
	var gather := entity.get_component(&"WorkerGatherComponent")
	if gather != null and gather.has_method("cancel_gather"):
		gather.cancel_gather(true)
		stopped = true
	var command_component := entity.get_component(&"CommandComponent") as CommandComponent
	if command_component != null:
		command_component.clear_current_target()
	return stopped
