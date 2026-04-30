extends Node3D
class_name MovementComponent

const MovementQueryScript := preload("res://game/entities/movement/movement_query.gd")
const GridPathfinderScript := preload("res://game/entities/movement/grid_pathfinder.gd")
const MovementSpaceQueryScript := preload("res://game/entities/movement/movement_space_query.gd")

const MAX_SEPARATION_CORRECTION := 0.45
const SEPARATION_EPSILON := 0.001
const FOOTPRINT_SHAPE_CIRCLE := 0
const FOOTPRINT_SHAPE_RECTANGLE := 1

@export var speed: float = 5.0
@export var arrival_radius: float = 0.25
@export var target_resolution_radius: float = 4.0
@export var target_resolution_step: float = 1.0
@export var stuck_check_interval: float = 0.5
@export var stuck_timeout_seconds: float = 1.5
@export var stuck_min_movement: float = 0.05
@export var stuck_min_progress: float = 0.1
@export_node_path("Node3D") var move_root_path: NodePath

var _terrain: Terrain = null
var _path: Array[Vector3] = []
var _requested_target := Vector3.ZERO
var _resolved_target := Vector3.ZERO
var _has_move_target := false
var _has_retried_stuck_repath := false
var _stuck_check_remaining := 0.0
var _stuck_elapsed_without_progress := 0.0
var _last_progress_position := Vector3.ZERO
var _last_distance_to_target := 0.0
var _finders: Array[TerrainFinder] = []
var _warned_missing_finder := false
var _warned_missing_move_root := false

func _ready() -> void:
	for child in get_children():
		if child is TerrainFinder:
			_finders.append(child)
	if _finders.is_empty():
		push_warning("%s has no TerrainFinder child; sampling terrain height at the move root." % name)
		_warned_missing_finder = true

func set_terrain(terrain: Terrain) -> void:
	_terrain = terrain

func get_terrain() -> Terrain:
	return _terrain

func set_path(points: Array[Vector3]) -> void:
	_path.assign(points)

func clear_path() -> void:
	_path.clear()
	_has_move_target = false
	_has_retried_stuck_repath = false

func request_move_to(target: Vector3) -> bool:
	return _request_move_to(target, true)

func get_resolved_target() -> Vector3:
	return _resolved_target

func has_move_target() -> bool:
	return _has_move_target

func _request_move_to(target: Vector3, reset_stuck_retry: bool) -> bool:
	if _terrain == null:
		return false
	var move_root := get_move_root()
	if move_root == null:
		return false
	var entity := move_root as EntityBase
	var radius := _get_move_root_radius(entity)
	var resolved_target = MovementSpaceQueryScript.find_nearest_open_position(
		target,
		radius,
		target_resolution_radius,
		_terrain,
		entity,
		target_resolution_step
	)
	if resolved_target == null:
		return false

	_requested_target = target
	_resolved_target = resolved_target
	_has_move_target = true
	if reset_stuck_retry:
		_has_retried_stuck_repath = false

	if move_root.global_position.distance_to(_resolved_target) <= arrival_radius:
		_path.clear()
		_reset_stuck_progress(move_root)
		return true

	var path := _build_path_to(_resolved_target, move_root)
	if path.is_empty():
		_has_move_target = false
		return false
	set_path(path)
	_reset_stuck_progress(move_root)
	return true

func has_path() -> bool:
	return not _path.is_empty()

func get_terrain_finder_count() -> int:
	return _finders.size()

func get_path_point_count() -> int:
	return _path.size()

func _process(delta: float) -> void:
	if _path.is_empty() or _terrain == null:
		return
	_advance(delta)
	if not _path.is_empty():
		_tick_stuck_detection(delta)

func _advance(delta: float) -> void:
	var move_root := get_move_root()
	if move_root == null:
		return
	if _has_move_target and move_root.global_position.distance_to(_resolved_target) <= arrival_radius:
		clear_path()
		return
	var target: Vector3 = _path[0]
	var pos: Vector3 = move_root.global_position

	var flat_dir: Vector3 = Vector3(target.x - pos.x, 0.0, target.z - pos.z)
	var dist: float = flat_dir.length()

	if dist <= arrival_radius:
		_path.pop_front()
		if _path.is_empty() and _has_move_target:
			clear_path()
		return

	flat_dir = flat_dir / dist
	var step: float = minf(speed * delta, dist)
	pos.x += flat_dir.x * step
	pos.z += flat_dir.z * step
	pos = _apply_footprint_separation(move_root, pos)

	move_root.global_position = pos
	pos.y = _terrain_y_for_move_root(move_root)
	move_root.global_position = pos

	var facing_target := Vector3(pos.x + flat_dir.x, pos.y, pos.z + flat_dir.z)
	move_root.look_at(facing_target, Vector3.UP)
	move_root.rotation.x = 0.0
	move_root.rotation.z = 0.0

func _build_path_to(target: Vector3, move_root: Node3D) -> Array[Vector3]:
	var entity := move_root as EntityBase
	var radius := _get_move_root_radius(entity)
	if MovementQueryScript.is_direct_route_walkable(_terrain, move_root.global_position, target, 1.0, radius, entity):
		return [target]
	return GridPathfinderScript.find_path(_terrain, move_root.global_position, target)

func _reset_stuck_progress(move_root: Node3D) -> void:
	_stuck_check_remaining = maxf(stuck_check_interval, 0.05)
	_stuck_elapsed_without_progress = 0.0
	_last_progress_position = move_root.global_position
	_last_distance_to_target = move_root.global_position.distance_to(_resolved_target)

func _tick_stuck_detection(delta: float) -> void:
	var move_root := get_move_root()
	if move_root == null or not _has_move_target:
		return
	_stuck_check_remaining -= delta
	if _stuck_check_remaining > 0.0:
		return
	var current_distance := move_root.global_position.distance_to(_resolved_target)
	var distance_progress := _last_distance_to_target - current_distance
	var position_progress := move_root.global_position.distance_to(_last_progress_position)
	if distance_progress < stuck_min_progress and position_progress < stuck_min_movement:
		_stuck_elapsed_without_progress += maxf(stuck_check_interval, 0.05)
	else:
		_stuck_elapsed_without_progress = 0.0
	if _stuck_elapsed_without_progress >= maxf(stuck_timeout_seconds, maxf(stuck_check_interval, 0.05)):
		_handle_stuck(move_root)
		return
	_stuck_check_remaining = maxf(stuck_check_interval, 0.05)
	_last_progress_position = move_root.global_position
	_last_distance_to_target = current_distance

func _handle_stuck(move_root: Node3D) -> void:
	if _has_retried_stuck_repath:
		print("%s movement stopped: no progress toward target." % _get_move_root_display_name(move_root))
		clear_path()
		return
	_has_retried_stuck_repath = true
	if not _request_move_to(_requested_target, false):
		print("%s movement stopped: could not repath after no progress." % _get_move_root_display_name(move_root))
		clear_path()

func _get_move_root_radius(entity: EntityBase) -> float:
	if entity == null:
		return 0.5
	var footprint := entity.get_footprint_component()
	if footprint != null and footprint.has_method("get_separation_radius"):
		return maxf(footprint.get_separation_radius(), 0.1)
	return 0.5

func _get_move_root_display_name(move_root: Node3D) -> String:
	if move_root is EntityBase:
		var entity := move_root as EntityBase
		if entity.display_name.strip_edges() != "":
			return entity.display_name
	return move_root.name

func _apply_footprint_separation(move_root: Node3D, proposed_position: Vector3) -> Vector3:
	var entity := move_root as EntityBase
	if entity == null:
		return proposed_position
	var footprint := entity.get_footprint_component()
	if footprint == null or not footprint.blocks_units or not footprint.participates_in_separation:
		return proposed_position

	var correction := Vector3.ZERO
	for node in get_tree().get_nodes_in_group("entity_footprints"):
		var other_footprint := node
		if other_footprint == null or other_footprint == footprint:
			continue
		if not other_footprint.blocks_units or not other_footprint.participates_in_separation:
			continue
		var other_entity: EntityBase = other_footprint.get_entity_parent()
		if other_entity == null or other_entity == entity:
			continue
		correction += _get_footprint_correction(proposed_position + correction, footprint, other_entity, other_footprint)

	if correction.length() > MAX_SEPARATION_CORRECTION:
		correction = correction.normalized() * MAX_SEPARATION_CORRECTION
	proposed_position.x += correction.x
	proposed_position.z += correction.z
	return proposed_position

func _get_footprint_correction(
		position: Vector3,
		footprint: Node,
		other_entity: EntityBase,
		other_footprint: Node
) -> Vector3:
	if footprint.shape != FOOTPRINT_SHAPE_CIRCLE:
		return Vector3.ZERO
	if other_footprint.shape == FOOTPRINT_SHAPE_RECTANGLE:
		return _get_circle_rectangle_correction(position, footprint.radius, other_entity.global_position, other_footprint.half_extents)
	return _get_circle_circle_correction(position, footprint.radius, other_entity.global_position, other_footprint.get_separation_radius())

func _get_circle_circle_correction(position: Vector3, radius: float, other_position: Vector3, other_radius: float) -> Vector3:
	var delta := Vector3(position.x - other_position.x, 0.0, position.z - other_position.z)
	var distance := delta.length()
	var min_distance := radius + other_radius
	if distance >= min_distance:
		return Vector3.ZERO
	if distance <= SEPARATION_EPSILON:
		delta = Vector3.RIGHT
		distance = 1.0
	return delta / distance * (min_distance - distance)

func _get_circle_rectangle_correction(position: Vector3, radius: float, rectangle_position: Vector3, half_extents: Vector2) -> Vector3:
	var min_x := rectangle_position.x - half_extents.x
	var max_x := rectangle_position.x + half_extents.x
	var min_z := rectangle_position.z - half_extents.y
	var max_z := rectangle_position.z + half_extents.y
	var closest_x := clampf(position.x, min_x, max_x)
	var closest_z := clampf(position.z, min_z, max_z)
	var delta := Vector3(position.x - closest_x, 0.0, position.z - closest_z)
	var distance := delta.length()

	if distance > SEPARATION_EPSILON:
		if distance >= radius:
			return Vector3.ZERO
		return delta / distance * (radius - distance)

	if position.x < min_x or position.x > max_x or position.z < min_z or position.z > max_z:
		return Vector3.ZERO

	var push_left := absf(position.x - min_x)
	var push_right := absf(max_x - position.x)
	var push_front := absf(position.z - min_z)
	var push_back := absf(max_z - position.z)
	var nearest := minf(minf(push_left, push_right), minf(push_front, push_back))
	if nearest == push_left:
		return Vector3.LEFT * (push_left + radius)
	if nearest == push_right:
		return Vector3.RIGHT * (push_right + radius)
	if nearest == push_front:
		return Vector3.FORWARD * (push_front + radius)
	return Vector3.BACK * (push_back + radius)

func _terrain_y_for_move_root(move_root: Node3D) -> float:
	var sample_world: Vector3 = move_root.global_position
	if not _finders.is_empty():
		sample_world = _finders[0].global_position
	elif not _warned_missing_finder:
		push_warning("%s has no TerrainFinder child; sampling terrain height at the move root." % name)
		_warned_missing_finder = true

	var local: Vector3 = _terrain.to_local(sample_world)
	var height: float = _terrain.get_height_at_local_position(local)
	var terrain_world_y: float = _terrain.to_global(Vector3(local.x, height, local.z)).y
	return move_root.global_position.y + (terrain_world_y - sample_world.y)

func get_move_root() -> Node3D:
	var move_root := get_node_or_null(move_root_path) as Node3D
	if move_root != null:
		return move_root
	if not _warned_missing_move_root:
		push_warning("%s has no move_root_path assigned; movement is disabled." % name)
		_warned_missing_move_root = true
	return null
