extends Node3D
class_name MovementComponent

@export var speed: float = 5.0
@export_node_path("Node3D") var move_root_path: NodePath

var _terrain: Terrain = null
var _path: Array[Vector3] = []
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

func set_path(points: Array[Vector3]) -> void:
	_path.assign(points)

func clear_path() -> void:
	_path.clear()

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

func _advance(delta: float) -> void:
	var move_root := get_move_root()
	if move_root == null:
		return
	var target: Vector3 = _path[0]
	var pos: Vector3 = move_root.global_position

	var flat_dir: Vector3 = Vector3(target.x - pos.x, 0.0, target.z - pos.z)
	var dist: float = flat_dir.length()

	if dist < 0.05:
		_path.pop_front()
		return

	flat_dir = flat_dir / dist
	var step: float = minf(speed * delta, dist)
	pos.x += flat_dir.x * step
	pos.z += flat_dir.z * step

	move_root.global_position = pos
	pos.y = _terrain_y_for_move_root(move_root)
	move_root.global_position = pos

	var facing_target := Vector3(pos.x + flat_dir.x, pos.y, pos.z + flat_dir.z)
	move_root.look_at(facing_target, Vector3.UP)
	move_root.rotation.x = 0.0
	move_root.rotation.z = 0.0

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
