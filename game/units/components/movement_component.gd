extends Node3D
class_name MovementComponent

@export var speed: float = 5.0

var _terrain: Terrain = null
var _path: Array[Vector3] = []
var _finders: Array[TerrainFinder] = []

func _ready() -> void:
	for child in get_children():
		if child is TerrainFinder:
			_finders.append(child)

func set_terrain(terrain: Terrain) -> void:
	_terrain = terrain

func set_path(points: Array[Vector3]) -> void:
	_path = points.duplicate()

func clear_path() -> void:
	_path.clear()

func has_path() -> bool:
	return not _path.is_empty()

func _process(delta: float) -> void:
	if _path.is_empty() or _terrain == null:
		return
	_advance(delta)

func _advance(delta: float) -> void:
	var unit: Node3D = owner as Node3D
	if unit == null:
		return
	var target: Vector3 = _path[0]
	var pos: Vector3 = unit.global_position

	var flat_dir: Vector3 = Vector3(target.x - pos.x, 0.0, target.z - pos.z)
	var dist: float = flat_dir.length()

	if dist < 0.05:
		_path.pop_front()
		return

	flat_dir = flat_dir / dist
	var step: float = minf(speed * delta, dist)
	pos.x += flat_dir.x * step
	pos.z += flat_dir.z * step
	pos.y = _terrain_y(pos)

	unit.global_position = pos
	unit.look_at(Vector3(pos.x + flat_dir.x, pos.y, pos.z + flat_dir.z), Vector3.UP)

func _terrain_y(world_pos: Vector3) -> float:
	var local: Vector3 = _terrain.to_local(world_pos)
	var height: float = _terrain.get_height_at_local_position(local)
	return _terrain.to_global(Vector3(local.x, height, local.z)).y
