extends RefCounted
class_name GridPathfinder

const MAX_ITERATIONS := 12000
const DIRECTIONS := [
	Vector2i(1, 0),
	Vector2i(-1, 0),
	Vector2i(0, 1),
	Vector2i(0, -1),
]

static func find_path(
		terrain: Terrain,
		start_world: Vector3,
		goal_world: Vector3,
		cell_size: float = 1.0
) -> Array[Vector3]:
	var path: Array[Vector3] = []
	if terrain == null:
		return path

	var path_cell_size: float = maxf(cell_size, 0.01)
	var bounds := terrain.get_pathfinding_bounds(path_cell_size)
	if bounds.size.x <= 0 or bounds.size.y <= 0:
		return path

	var start_cell := _world_to_cell(terrain, start_world, path_cell_size)
	var goal_cell := _world_to_cell(terrain, goal_world, path_cell_size)
	if not bounds.has_point(start_cell) or not bounds.has_point(goal_cell):
		return path
	if not _is_cell_walkable(terrain, start_cell, path_cell_size):
		return path
	if not _is_cell_walkable(terrain, goal_cell, path_cell_size):
		return path
	if start_cell == goal_cell:
		path.append(_cell_to_world(terrain, goal_cell, path_cell_size))
		return path

	var open: Array[Vector2i] = [start_cell]
	var came_from := {}
	var g_score := { start_cell: 0.0 }
	var f_score := { start_cell: float(_heuristic(start_cell, goal_cell)) }
	var closed := {}
	var iterations := 0

	while not open.is_empty() and iterations < MAX_ITERATIONS:
		iterations += 1
		var current := _pop_lowest_f_score(open, f_score)
		if current == goal_cell:
			return _build_world_path(terrain, came_from, current, path_cell_size)

		closed[current] = true
		for direction in DIRECTIONS:
			var neighbor: Vector2i = current + direction
			if closed.has(neighbor):
				continue
			if not bounds.has_point(neighbor):
				continue
			if not _is_cell_walkable(terrain, neighbor, path_cell_size):
				continue

			var tentative_g: float = g_score[current] + 1.0
			if not g_score.has(neighbor) or tentative_g < g_score[neighbor]:
				came_from[neighbor] = current
				g_score[neighbor] = tentative_g
				f_score[neighbor] = tentative_g + float(_heuristic(neighbor, goal_cell))
				if not open.has(neighbor):
					open.append(neighbor)

	return path

static func _world_to_cell(terrain: Terrain, world_position: Vector3, cell_size: float) -> Vector2i:
	var local := terrain.to_local(world_position)
	return Vector2i(
		int(floor(local.x / cell_size)),
		int(floor(local.z / cell_size))
	)

static func _cell_to_local(cell: Vector2i, cell_size: float) -> Vector3:
	return Vector3(
		(float(cell.x) + 0.5) * cell_size,
		0.0,
		(float(cell.y) + 0.5) * cell_size
	)

static func _cell_to_world(terrain: Terrain, cell: Vector2i, cell_size: float) -> Vector3:
	var local := _cell_to_local(cell, cell_size)
	local.y = terrain.get_height_at_local_position(local)
	return terrain.to_global(local)

static func _is_cell_walkable(terrain: Terrain, cell: Vector2i, cell_size: float) -> bool:
	return terrain.is_ground_walkable_at_local_position(_cell_to_local(cell, cell_size))

static func _heuristic(a: Vector2i, b: Vector2i) -> int:
	return absi(a.x - b.x) + absi(a.y - b.y)

static func _pop_lowest_f_score(open: Array[Vector2i], f_score: Dictionary) -> Vector2i:
	var best_index := 0
	var best_score: float = f_score.get(open[0], INF)
	for i in range(1, open.size()):
		var score: float = f_score.get(open[i], INF)
		if score < best_score:
			best_score = score
			best_index = i
	return open.pop_at(best_index)

static func _build_world_path(
		terrain: Terrain,
		came_from: Dictionary,
		current: Vector2i,
		cell_size: float
) -> Array[Vector3]:
	var cells: Array[Vector2i] = [current]
	while came_from.has(current):
		current = came_from[current]
		cells.push_front(current)

	var world_path: Array[Vector3] = []
	for i in range(1, cells.size()):
		world_path.append(_cell_to_world(terrain, cells[i], cell_size))
	return world_path
