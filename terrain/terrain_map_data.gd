extends Resource
class_name TerrainMapData

const GRASS_MATERIAL_ID := 0

@export var playable_chunks := Vector2i(1, 1)
@export var chunk_size_meters := 64
@export var border_chunks := 1
@export var cell_size := 1.0
@export var default_height := 0.0

var base_heights := PackedFloat32Array()
var material_ids := PackedInt32Array()

func create_flat_grass_map(
		new_playable_chunks: Vector2i = Vector2i(1, 1),
		new_default_height: float = 0.0
) -> void:
	playable_chunks = new_playable_chunks
	default_height = new_default_height

	var vertex_count := get_vertex_count()
	base_heights.resize(vertex_count.x * vertex_count.y)
	material_ids.resize(get_total_cell_count().x * get_total_cell_count().y)

	for i in base_heights.size():
		base_heights[i] = default_height

	for i in material_ids.size():
		material_ids[i] = GRASS_MATERIAL_ID

func get_cells_per_chunk() -> int:
	return int(round(float(chunk_size_meters) / cell_size))

func get_total_chunks() -> Vector2i:
	return playable_chunks + Vector2i(border_chunks * 2, border_chunks * 2)

func get_total_cell_count() -> Vector2i:
	var cells_per_chunk := get_cells_per_chunk()
	return get_total_chunks() * cells_per_chunk

func get_vertex_count() -> Vector2i:
	return get_total_cell_count() + Vector2i.ONE

func get_total_size() -> Vector2:
	var cells := get_total_cell_count()
	return Vector2(float(cells.x) * cell_size, float(cells.y) * cell_size)

func get_border_size() -> float:
	return float(border_chunks * chunk_size_meters)

func get_playable_min() -> Vector2:
	return Vector2.ONE * get_border_size()

func get_playable_max() -> Vector2:
	var playable_size := Vector2(float(playable_chunks.x), float(playable_chunks.y)) * float(chunk_size_meters)
	return get_playable_min() + playable_size

func is_grid_point_valid(grid: Vector2i) -> bool:
	var vertices := get_vertex_count()
	return grid.x >= 0 and grid.y >= 0 and grid.x < vertices.x and grid.y < vertices.y

func is_chunk_valid(chunk_coord: Vector2i) -> bool:
	var total_chunks := get_total_chunks()
	return chunk_coord.x >= 0 and chunk_coord.y >= 0 and chunk_coord.x < total_chunks.x and chunk_coord.y < total_chunks.y

func get_height(grid: Vector2i) -> float:
	if not is_grid_point_valid(grid):
		return default_height
	return base_heights[_height_index(grid)]

func set_height(grid: Vector2i, height: float) -> void:
	if is_grid_point_valid(grid):
		base_heights[_height_index(grid)] = height

func local_to_grid(local_position: Vector3) -> Vector2i:
	return Vector2i(
		int(round(local_position.x / cell_size)),
		int(round(local_position.z / cell_size))
	)

func get_position_for_grid(grid: Vector2i) -> Vector3:
	return Vector3(float(grid.x) * cell_size, get_height(grid), float(grid.y) * cell_size)

func get_chunk_for_grid(grid: Vector2i) -> Vector2i:
	var cells_per_chunk := get_cells_per_chunk()
	return Vector2i(
		clampi(int(floor(float(grid.x) / float(cells_per_chunk))), 0, get_total_chunks().x - 1),
		clampi(int(floor(float(grid.y) / float(cells_per_chunk))), 0, get_total_chunks().y - 1)
	)

func apply_height_brush(local_center: Vector3, radius: float, amount: float) -> Array[Vector2i]:
	var dirty_chunks: Array[Vector2i] = []
	var dirty_lookup := {}
	var radius_cells := int(ceil(radius / cell_size))
	var center_grid := local_to_grid(local_center)
	var radius_squared := radius * radius
	var playable_min := get_playable_min()
	var playable_max := get_playable_max()

	for z in range(center_grid.y - radius_cells, center_grid.y + radius_cells + 1):
		for x in range(center_grid.x - radius_cells, center_grid.x + radius_cells + 1):
			var grid := Vector2i(x, z)
			if not is_grid_point_valid(grid):
				continue

			var point_x := float(x) * cell_size
			var point_z := float(z) * cell_size
			if point_x < playable_min.x or point_z < playable_min.y or point_x > playable_max.x or point_z > playable_max.y:
				continue

			var distance_squared := Vector2(point_x, point_z).distance_squared_to(Vector2(local_center.x, local_center.z))
			if distance_squared > radius_squared:
				continue

			var falloff : float = 1.0 - sqrt(distance_squared) / max(radius, 0.001)
			var shaped_amount := amount * smoothstep(0.0, 1.0, falloff)
			set_height(grid, get_height(grid) + shaped_amount)

			var chunk_coord := get_chunk_for_grid(grid)
			var key := _chunk_key(chunk_coord)
			if not dirty_lookup.has(key):
				dirty_lookup[key] = true
				dirty_chunks.append(chunk_coord)

	return dirty_chunks

func _height_index(grid: Vector2i) -> int:
	return grid.y * get_vertex_count().x + grid.x

func _chunk_key(chunk_coord: Vector2i) -> String:
	return "%d,%d" % [chunk_coord.x, chunk_coord.y]
