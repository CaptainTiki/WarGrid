extends Resource
class_name TerrainMapData

const GRASS_MATERIAL_ID := 0
const SPLAT_CHANNEL_COUNT := 4

enum Walkable { ALL, AIR, NONE }
enum Buildable { OPEN, BLOCKED }
enum OverlayMode { NONE, WALKABLE, BUILDABLE, FOW_HEIGHT }

@export var playable_chunks := Vector2i(2, 2)
@export var chunk_size_meters := 32
@export var border_chunks := 2
@export var cell_size := 1.0
@export var default_height := 0.0

var base_heights := PackedFloat32Array()
var material_ids := PackedInt32Array()
var walkable_data := PackedByteArray()
var buildable_data := PackedByteArray()
var fow_height_data := PackedByteArray()
var splat_map: Image
var _total_cell_count := Vector2i.ZERO
var _vertex_count := Vector2i.ZERO

func create_flat_grass_map(
		new_playable_chunks: Vector2i = Vector2i(2, 2),
		new_default_height: float = 0.0
) -> void:
	playable_chunks = new_playable_chunks
	default_height = new_default_height
	refresh_cached_sizes()

	var vertex_count := get_vertex_count()
	base_heights.resize(vertex_count.x * vertex_count.y)
	material_ids.resize(get_total_cell_count().x * get_total_cell_count().y)

	for i in base_heights.size():
		base_heights[i] = default_height

	for i in material_ids.size():
		material_ids[i] = GRASS_MATERIAL_ID

	create_default_splat_map()
	_create_default_gameplay_data()

func get_cells_per_chunk() -> int:
	return int(round(float(chunk_size_meters) / cell_size))

func get_total_chunks() -> Vector2i:
	return playable_chunks + Vector2i(border_chunks * 2, border_chunks * 2)

func get_total_cell_count() -> Vector2i:
	if _total_cell_count != Vector2i.ZERO:
		return _total_cell_count
	var cells_per_chunk := get_cells_per_chunk()
	return get_total_chunks() * cells_per_chunk

func get_vertex_count() -> Vector2i:
	if _vertex_count != Vector2i.ZERO:
		return _vertex_count
	return get_total_cell_count() + Vector2i.ONE

func get_total_size() -> Vector2:
	var cells := get_total_cell_count()
	return Vector2(float(cells.x) * cell_size, float(cells.y) * cell_size)

func get_splat_map_size() -> Vector2i:
	if splat_map == null:
		return Vector2i.ZERO
	return Vector2i(splat_map.get_width(), splat_map.get_height())

func get_border_size() -> float:
	return float(border_chunks * chunk_size_meters)

func get_playable_min() -> Vector2:
	return Vector2.ONE * get_border_size()

func get_playable_max() -> Vector2:
	var playable_size := Vector2(float(playable_chunks.x), float(playable_chunks.y)) * float(chunk_size_meters)
	return get_playable_min() + playable_size

func get_playable_cell_count() -> Vector2i:
	return playable_chunks * get_cells_per_chunk()

func get_playable_cell_min() -> Vector2i:
	var border_cells: int = border_chunks * get_cells_per_chunk()
	return Vector2i(border_cells, border_cells)

func get_playable_cell_max_exclusive() -> Vector2i:
	return get_playable_cell_min() + get_playable_cell_count()

func is_visual_cell_in_playable_area(visual_cell: Vector2i) -> bool:
	var min_cell: Vector2i = get_playable_cell_min()
	var max_cell: Vector2i = get_playable_cell_max_exclusive()
	return visual_cell.x >= min_cell.x and visual_cell.y >= min_cell.y and visual_cell.x < max_cell.x and visual_cell.y < max_cell.y

func visual_cell_to_playable_cell(visual_cell: Vector2i) -> Vector2i:
	return visual_cell - get_playable_cell_min()

func get_walkable_value_for_visual_cell(visual_cell: Vector2i) -> int:
	var index: int = playable_index_for_visual_cell(visual_cell)
	if index < 0 or index >= walkable_data.size():
		return Walkable.NONE
	return walkable_data[index]

func get_buildable_value_for_visual_cell(visual_cell: Vector2i) -> int:
	var index: int = playable_index_for_visual_cell(visual_cell)
	if index < 0 or index >= buildable_data.size():
		return Buildable.BLOCKED
	return buildable_data[index]

func get_fow_height_value_for_visual_cell(visual_cell: Vector2i) -> int:
	var index: int = playable_index_for_visual_cell(visual_cell)
	if index < 0 or index >= fow_height_data.size():
		return 0
	return fow_height_data[index]

func is_grid_point_valid(grid: Vector2i) -> bool:
	var vertices := get_vertex_count()
	return grid.x >= 0 and grid.y >= 0 and grid.x < vertices.x and grid.y < vertices.y

func is_chunk_valid(chunk_coord: Vector2i) -> bool:
	var total_chunks := get_total_chunks()
	return chunk_coord.x >= 0 and chunk_coord.y >= 0 and chunk_coord.x < total_chunks.x and chunk_coord.y < total_chunks.y

func is_local_position_in_playable_area(local_position: Vector3) -> bool:
	var playable_min := get_playable_min()
	var playable_max := get_playable_max()
	return (
		local_position.x >= playable_min.x
		and local_position.z >= playable_min.y
		and local_position.x <= playable_max.x
		and local_position.z <= playable_max.y
	)

func get_height(grid: Vector2i) -> float:
	if not is_grid_point_valid(grid):
		return default_height
	return base_heights[_height_index(grid)]

func get_height_at(x: int, z: int) -> float:
	var vertices := get_vertex_count()
	if x < 0 or z < 0 or x >= vertices.x or z >= vertices.y:
		return default_height
	return base_heights[z * vertices.x + x]

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

func get_position_for_grid_coords(x: int, z: int) -> Vector3:
	return Vector3(float(x) * cell_size, get_height_at(x, z), float(z) * cell_size)

func get_chunk_for_grid(grid: Vector2i) -> Vector2i:
	var cells_per_chunk := get_cells_per_chunk()
	return Vector2i(
		clampi(int(floor(float(grid.x) / float(cells_per_chunk))), 0, get_total_chunks().x - 1),
		clampi(int(floor(float(grid.y) / float(cells_per_chunk))), 0, get_total_chunks().y - 1)
	)

func local_to_splat_pixel(local_position: Vector3) -> Vector2i:
	var size := get_splat_map_size()
	return Vector2i(
		clampi(int(floor(local_position.x / cell_size)), 0, max(size.x - 1, 0)),
		clampi(int(floor(local_position.z / cell_size)), 0, max(size.y - 1, 0))
	)

func get_chunks_using_grid_point(grid: Vector2i) -> Array[Vector2i]:
	var chunk_coords: Array[Vector2i] = []
	var cells_per_chunk := get_cells_per_chunk()
	var min_chunk := Vector2i(
		int(floor(float(grid.x - 1) / float(cells_per_chunk))),
		int(floor(float(grid.y - 1) / float(cells_per_chunk)))
	)
	var max_chunk := get_chunk_for_grid(grid)

	for chunk_y in range(min_chunk.y, max_chunk.y + 1):
		for chunk_x in range(min_chunk.x, max_chunk.x + 1):
			var chunk_coord := Vector2i(chunk_x, chunk_y)
			if is_chunk_valid(chunk_coord):
				chunk_coords.append(chunk_coord)

	return chunk_coords

func add_dirty_chunks_for_grid(grid: Vector2i, dirty_chunks: Array[Vector2i], dirty_lookup: Dictionary) -> void:
	for chunk_coord in get_chunks_using_grid_point(grid):
		var key := _chunk_key(chunk_coord)
		if dirty_lookup.has(key):
			continue
		dirty_lookup[key] = true
		dirty_chunks.append(chunk_coord)

func playable_index_for_visual_cell(visual_cell: Vector2i) -> int:
	if not is_visual_cell_in_playable_area(visual_cell):
		return -1
	var playable_cell: Vector2i = visual_cell_to_playable_cell(visual_cell)
	var playable_cells: Vector2i = get_playable_cell_count()
	return playable_cell.y * playable_cells.x + playable_cell.x

func create_default_splat_map() -> void:
	var size := get_total_cell_count()
	splat_map = Image.create(size.x, size.y, false, Image.FORMAT_RGBA8)
	splat_map.fill(Color(1.0, 0.0, 0.0, 0.0))

func _height_index(grid: Vector2i) -> int:
	return grid.y * get_vertex_count().x + grid.x

func refresh_cached_sizes() -> void:
	var cells_per_chunk := get_cells_per_chunk()
	_total_cell_count = get_total_chunks() * cells_per_chunk
	_vertex_count = _total_cell_count + Vector2i.ONE

func _create_default_gameplay_data() -> void:
	var playable_cells: Vector2i = get_playable_cell_count()
	var cell_count: int = playable_cells.x * playable_cells.y
	walkable_data.resize(cell_count)
	buildable_data.resize(cell_count)
	fow_height_data.resize(cell_count)
	for i in range(cell_count):
		walkable_data[i] = Walkable.ALL
		buildable_data[i] = Buildable.OPEN
		fow_height_data[i] = 0

func _chunk_key(chunk_coord: Vector2i) -> String:
	return "%d,%d" % [chunk_coord.x, chunk_coord.y]
