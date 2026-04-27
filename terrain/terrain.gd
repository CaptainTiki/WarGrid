extends Node3D
class_name Terrain

const TerrainChunkScene := preload("res://terrain/terrain_chunk.tscn")

@export var playable_chunks := Vector2i(2, 2)
@export var chunk_size_meters := 32
@export var border_chunks := 2
@export var cell_size := 1.0
@export var debug_plain_gray := false
@export_range(1, 4, 1) var mesh_chunks_per_frame := 2
@export var rebuild_pretty_normals_during_stroke := true
@export_range(1, 4, 1) var collider_chunks_per_tick := 1
@export var collider_rebuild_interval := 0.12
@export var rebuild_colliders_during_stroke := false

var map_data: TerrainMapData
var chunks := {}

var _chunk_root: Node3D
var _bounds_root: Node3D
var _terrain_material: StandardMaterial3D
var _mesh_rebuild_queue: Array[Vector2i] = []
var _collider_rebuild_queue: Array[Vector2i] = []
var _pretty_mesh_rebuild_lookup := {}
var _mesh_rebuild_lookup := {}
var _collider_rebuild_lookup := {}
var _stroke_dirty_lookup := {}
var _collider_rebuild_elapsed := 0.0
var _height_brush_stroke_active := false
var _smooth_brush_stroke_active := false

func _ready() -> void:
	create_flat_grass_map()

func _process(delta: float) -> void:
	TerrainProfiler.flush_pending()
	_drain_mesh_rebuild_queue(mesh_chunks_per_frame)
	_collider_rebuild_elapsed += delta
	if _collider_rebuild_elapsed >= collider_rebuild_interval:
		_collider_rebuild_elapsed = 0.0
		_drain_collider_rebuild_queue(collider_chunks_per_tick)

func create_flat_grass_map() -> void:
	map_data = TerrainMapData.new()
	map_data.chunk_size_meters = chunk_size_meters
	map_data.border_chunks = border_chunks
	map_data.cell_size = cell_size
	map_data.create_flat_grass_map(playable_chunks, 0.0)
	_ensure_roots()
	_clear_children(_chunk_root)
	chunks.clear()
	_clear_rebuild_queues()
	_build_all_chunks()
	_rebuild_bounds()

func apply_height_brush(local_center: Vector3, radius: float, amount: float, falloff_power: float = 1.0) -> void:
	if map_data == null:
		return

	var touched_chunks := map_data.apply_height_brush(local_center, radius, amount, falloff_power)
	queue_dirty_chunks(touched_chunks)

func begin_height_brush_stroke() -> void:
	_height_brush_stroke_active = true

func apply_smooth_brush(local_center: Vector3, radius: float, strength: float, falloff_power: float = 1.0) -> void:
	if map_data == null:
		return

	var touched_chunks := map_data.apply_smooth_brush(local_center, radius, strength, falloff_power)
	queue_dirty_chunks(touched_chunks)

func begin_smooth_brush_stroke() -> void:
	_smooth_brush_stroke_active = true

func finish_smooth_brush_stroke() -> void:
	_smooth_brush_stroke_active = false
	for value in _stroke_dirty_lookup.values():
		var chunk_coord: Vector2i = value
		_queue_mesh_rebuild(chunk_coord, true)
		_queue_collider_rebuild(chunk_coord)
	_stroke_dirty_lookup.clear()
	_drain_mesh_rebuild_queue(mesh_chunks_per_frame)

func queue_dirty_chunks(chunk_coords: Array[Vector2i], pretty_normals: bool = false) -> void:
	for chunk_coord in chunk_coords:
		if not map_data.is_chunk_valid(chunk_coord):
			continue
		var key := _chunk_key(chunk_coord)
		_stroke_dirty_lookup[key] = chunk_coord
		var chunk := chunks.get(key) as TerrainChunk
		if chunk != null:
			chunk.mark_dirty()
		_queue_mesh_rebuild(chunk_coord, pretty_normals or rebuild_pretty_normals_during_stroke)
		var brush_stroke_active := _height_brush_stroke_active or _smooth_brush_stroke_active
		if rebuild_colliders_during_stroke or not brush_stroke_active:
			_queue_collider_rebuild(chunk_coord)

func finish_height_brush_stroke() -> void:
	_height_brush_stroke_active = false
	for value in _stroke_dirty_lookup.values():
		var chunk_coord: Vector2i = value
		_queue_mesh_rebuild(chunk_coord, true)
		_queue_collider_rebuild(chunk_coord)
	_stroke_dirty_lookup.clear()
	_drain_mesh_rebuild_queue(mesh_chunks_per_frame)

func flush_rebuild_queues() -> void:
	while not _mesh_rebuild_queue.is_empty():
		_drain_mesh_rebuild_queue(_mesh_rebuild_queue.size())
	while not _collider_rebuild_queue.is_empty():
		_drain_collider_rebuild_queue(_collider_rebuild_queue.size())

func get_pick_point(camera: Camera3D, screen_position: Vector2, profile_raycast: bool = false) -> Variant:
	if camera == null:
		return null

	var from := camera.project_ray_origin(screen_position)
	var to := from + camera.project_ray_normal(screen_position) * 4096.0
	var query := PhysicsRayQueryParameters3D.create(from, to)
	query.collide_with_areas = false
	query.collide_with_bodies = true
	var raycast_start := TerrainProfiler.begin()
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	if profile_raycast:
		TerrainProfiler.log_timing(
			"Terrain.get_pick_point physics raycast",
			raycast_start,
			"screen=%s hit=%s" % [screen_position, not hit.is_empty()]
		)
	if hit.is_empty():
		return null

	var collider := hit.get("collider") as Node
	if collider == null or not collider.is_in_group("terrain_pick_colliders") or not is_ancestor_of(collider):
		return null
	var local_hit := to_local(hit.position)
	local_hit.y = map_data.get_height(map_data.local_to_grid(local_hit))
	return local_hit

func get_center_position() -> Vector3:
	if map_data == null:
		return Vector3.ZERO
	var total_size := map_data.get_total_size()
	return Vector3(total_size.x * 0.5, 0.0, total_size.y * 0.5)

func _build_all_chunks() -> void:
	var total_chunks := map_data.get_total_chunks()
	_terrain_material = _create_terrain_material()
	for z in range(total_chunks.y):
		for x in range(total_chunks.x):
			var chunk_coord := Vector2i(x, z)
			var chunk := TerrainChunkScene.instantiate() as TerrainChunk
			_chunk_root.add_child(chunk)
			chunk.setup(chunk_coord, map_data, _terrain_material)
			chunks[_chunk_key(chunk_coord)] = chunk

func _rebuild_bounds() -> void:
	_clear_children(_bounds_root)
	_bounds_root.add_child(_create_bounds_mesh("PlayableBounds", map_data.get_playable_min(), map_data.get_playable_max(), Color(1.0, 0.9, 0.1), 0.08))
	_bounds_root.add_child(_create_bounds_mesh("BorderBounds", Vector2.ZERO, map_data.get_total_size(), Color(0.15, 0.9, 1.0), 0.05))

func _create_bounds_mesh(node_name: String, min_corner: Vector2, max_corner: Vector2, color: Color, y: float) -> MeshInstance3D:
	var mesh := ArrayMesh.new()
	var vertices := PackedVector3Array([
		Vector3(min_corner.x, y, min_corner.y),
		Vector3(max_corner.x, y, min_corner.y),
		Vector3(max_corner.x, y, min_corner.y),
		Vector3(max_corner.x, y, max_corner.y),
		Vector3(max_corner.x, y, max_corner.y),
		Vector3(min_corner.x, y, max_corner.y),
		Vector3(min_corner.x, y, max_corner.y),
		Vector3(min_corner.x, y, min_corner.y),
	])
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_LINES, arrays)

	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = color

	var instance := MeshInstance3D.new()
	instance.name = node_name
	instance.mesh = mesh
	instance.material_override = material
	return instance

func _ensure_roots() -> void:
	if _chunk_root == null:
		_chunk_root = Node3D.new()
		_chunk_root.name = "Chunks"
		add_child(_chunk_root)
	if _bounds_root == null:
		_bounds_root = Node3D.new()
		_bounds_root.name = "Bounds"
		add_child(_bounds_root)

func _clear_children(node: Node) -> void:
	for child in node.get_children():
		child.free()

func _queue_mesh_rebuild(chunk_coord: Vector2i, pretty_normals: bool = false) -> void:
	var key := _chunk_key(chunk_coord)
	if pretty_normals:
		_pretty_mesh_rebuild_lookup[key] = true
	if _mesh_rebuild_lookup.has(key):
		return
	_mesh_rebuild_lookup[key] = true
	_mesh_rebuild_queue.append(chunk_coord)

func _queue_collider_rebuild(chunk_coord: Vector2i) -> void:
	var key := _chunk_key(chunk_coord)
	if _collider_rebuild_lookup.has(key):
		return
	_collider_rebuild_lookup[key] = true
	_collider_rebuild_queue.append(chunk_coord)

func _drain_mesh_rebuild_queue(max_chunks: int) -> void:
	var rebuilt := 0
	while rebuilt < max_chunks and not _mesh_rebuild_queue.is_empty():
		var chunk_coord: Vector2i = _mesh_rebuild_queue.pop_front()
		var key := _chunk_key(chunk_coord)
		_mesh_rebuild_lookup.erase(key)
		var pretty_normals := _pretty_mesh_rebuild_lookup.has(key)
		_pretty_mesh_rebuild_lookup.erase(key)
		var chunk := chunks.get(key) as TerrainChunk
		if chunk != null:
			chunk.rebuild_mesh(pretty_normals)
			chunk.data.dirty = false
		rebuilt += 1

func _drain_collider_rebuild_queue(max_chunks: int) -> void:
	var rebuilt := 0
	while rebuilt < max_chunks and not _collider_rebuild_queue.is_empty():
		var chunk_coord: Vector2i = _collider_rebuild_queue.pop_front()
		var key := _chunk_key(chunk_coord)
		_collider_rebuild_lookup.erase(key)
		var chunk := chunks.get(key) as TerrainChunk
		if chunk != null:
			chunk.rebuild_collider()
		rebuilt += 1

func _clear_rebuild_queues() -> void:
	_mesh_rebuild_queue.clear()
	_collider_rebuild_queue.clear()
	_pretty_mesh_rebuild_lookup.clear()
	_mesh_rebuild_lookup.clear()
	_collider_rebuild_lookup.clear()
	_stroke_dirty_lookup.clear()
	_collider_rebuild_elapsed = 0.0
	_height_brush_stroke_active = false
	_smooth_brush_stroke_active = false

func _create_terrain_material() -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.resource_name = "TerrainGrassMaterial"
	material.albedo_color = Color(0.24, 0.58, 0.18) if not debug_plain_gray else Color(0.55, 0.55, 0.55)
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	material.roughness = 0.9
	return material

func _chunk_key(chunk_coord: Vector2i) -> String:
	return "%d,%d" % [chunk_coord.x, chunk_coord.y]
