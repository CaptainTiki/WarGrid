extends CommandBase
class_name MoveCommand

func _init() -> void:
	command_id = &"move"
	display_name = "Move"
	tooltip = "Move to a terrain point."
	hotkey = &"command_move"
	target_mode = TargetMode.POINT

func can_execute(entity: EntityBase, context: Dictionary) -> bool:
	if not super.can_execute(entity, context):
		return false
	if not context.has("target_position"):
		return false
	if typeof(context["target_position"]) != TYPE_VECTOR3:
		return false
	if not context.get("terrain") is Terrain:
		return false
	return entity.get_component(&"MovementComponent") is MovementComponent

func execute(entity: EntityBase, context: Dictionary) -> bool:
	_stop_combat(entity)
	_cancel_gather(entity)
	var movement := entity.get_component(&"MovementComponent") as MovementComponent
	if movement == null:
		return false
	var terrain := context.get("terrain") as Terrain
	if terrain == null:
		return false
	movement.set_terrain(terrain)
	var move_root := movement.get_move_root()
	if move_root == null:
		return false
	var target: Vector3 = context["target_position"]
	if not movement.request_move_to(target):
		print("MoveCommand failed: no path found.")
		return false
	var combat := entity.get_component(&"CombatComponent")
	if combat != null and combat.has_method("set_home_position"):
		var home_position := movement.get_resolved_target() if movement.has_method("get_resolved_target") else target
		combat.set_home_position(home_position)
	print("MoveCommand: move requested.")
	return true

func _stop_combat(entity: EntityBase) -> void:
	var combat := entity.get_component(&"CombatComponent")
	if combat != null and combat.has_method("clear_attack_target"):
		combat.clear_attack_target()
	var command_component := entity.get_component(&"CommandComponent") as CommandComponent
	if command_component != null:
		command_component.clear_current_target()

func _cancel_gather(entity: EntityBase) -> void:
	var gather := entity.get_component(&"WorkerGatherComponent")
	if gather != null and gather.has_method("cancel_gather"):
		gather.cancel_gather(true)
