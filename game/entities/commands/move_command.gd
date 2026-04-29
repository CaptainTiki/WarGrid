extends CommandBase
class_name MoveCommand

const MovementQueryScript := preload("res://game/entities/movement/movement_query.gd")
const GridPathfinderScript := preload("res://game/entities/movement/grid_pathfinder.gd")

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
	var movement := entity.get_component(&"MovementComponent") as MovementComponent
	if movement == null:
		return false
	var terrain := context.get("terrain") as Terrain
	if terrain == null:
		return false
	var move_root := movement.get_move_root()
	if move_root == null:
		return false
	var target: Vector3 = context["target_position"]
	if MovementQueryScript.is_direct_route_walkable(terrain, move_root.global_position, target):
		var direct_path: Array[Vector3] = [target]
		movement.set_path(direct_path)
		print("MoveCommand: using direct route.")
		return true

	var path: Array[Vector3] = GridPathfinderScript.find_path(terrain, move_root.global_position, target)
	if path.is_empty():
		print("MoveCommand failed: no path found.")
		return false
	movement.set_path(path)
	print("MoveCommand: using A* path with %d waypoints." % path.size())
	return true

func _stop_combat(entity: EntityBase) -> void:
	var combat := entity.get_component(&"CombatComponent")
	if combat != null and combat.has_method("clear_attack_target"):
		combat.clear_attack_target(true)
	var command_component := entity.get_component(&"CommandComponent") as CommandComponent
	if command_component != null:
		command_component.clear_current_target()
