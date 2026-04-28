extends Node3D
class_name Terrain

const TerrainChunkScene := preload("res://terrain/terrain_chunk.tscn")

@export var playable_chunks := Vector2i(2, 2)
@export var chunk_size_meters := 32
@export var border_chunks := 2
@export var cell_size := 1.0
@export var debug_plain_gray := false
@export var material_texture_scale := 8.0
@export var overlay_normal_offset := 0.01
@export_range(1, 4, 1) var mesh_chunks_per_frame := 2
@export var rebuild_pretty_normals_during_stroke := true
@export_range(1, 4, 1) var collider_chunks_per_tick := 1
@export var collider_rebuild_interval := 0.12
@export var rebuild_colliders_during_stroke := false

var map_data: TerrainMapData
var chunks := {}

var _chunk_root: Node3D
var _bounds_root: Node3D
var _rebuild: TerrainRebuildQueue
var _mat: TerrainMaterialController
var _overlay_enabled := false
var _overlay_mode := TerrainMapData.OverlayMode.NONE
var _flatten_target_height := 0.0

func _ready() -> void:
	_rebuild = TerrainRebuildQueue.new()
	_mat = TerrainMaterialController.new()
	create_flat_grass_map()

func _process(delta: float) -> void:
	TerrainProfiler.flush_pending()
	_rebuild.tick(delta, chunks, mesh_chunks_per_frame, collider_chunks_per_tick, collider_rebuild_interval)

# ── Map creation ─────────────────────────────────────────────────────────────

func create_flat_grass_map() -> void:
	map_data = TerrainMapData.new()
	map_data.chunk_size_meters = chunk_size_meters
	map_data.border_chunks = border_chunks
	map_data.cell_size = cell_size
	map_data.create_flat_grass_map(playable_chunks, 0.0)
	_ensure_roots()
	_clear_children(_chunk_root)
	chunks.clear()
	_rebuild.reset()
	_build_all_chunks()
	_rebuild_bounds()

func create_flat_grass_map_with_size(new_playable_chunks: Vector2i, new_border_chunks: int = border_chunks) -> void:
	playable_chunks = Vector2i(maxi(new_playable_chunks.x, 1), maxi(new_playable_chunks.y, 1))
	border_chunks = maxi(new_border_chunks, 0)
	create_flat_grass_map()

# ── Brush API ─────────────────────────────────────────────────────────────────

func apply_height_brush(local_center: Vector3, radius: float, amount: float, falloff_power: float = 1.0) -> void:
	if map_data == null:
		return
	queue_dirty_chunks(TerrainHeightBrushes.apply_height(map_data, local_center, radius, amount, falloff_power))

func begin_height_brush_stroke() -> void:
	_rebuild.set_stroke_active("height", true)

func finish_height_brush_stroke() -> void:
	_finish_deforming_stroke("height")

func apply_smooth_brush(local_center: Vector3, radius: float, strength: float, falloff_power: float = 1.0) -> void:
	if map_data == null:
		return
	queue_dirty_chunks(TerrainHeightBrushes.apply_smooth(map_data, local_center, radius, strength, falloff_power))

func begin_smooth_brush_stroke() -> void:
	_rebuild.set_stroke_active("smooth", true)

func finish_smooth_brush_stroke() -> void:
	_finish_deforming_stroke("smooth")

func apply_flatten_brush(local_center: Vector3, radius: float, strength: float, falloff_power: float, target_height: float) -> void:
	if map_data == null:
		return
	queue_dirty_chunks(TerrainHeightBrushes.apply_flatten(map_data, local_center, radius, strength, falloff_power, target_height))

func begin_flatten_brush_stroke(target_height: float) -> void:
	_rebuild.set_stroke_active("flatten", true)
	_flatten_target_height = target_height

func finish_flatten_brush_stroke() -> void:
	_finish_deforming_stroke("flatten")

func apply_material_paint_brush(local_center: Vector3, radius: float, strength: float, falloff_power: float, selected_channel: int) -> void:
	if map_data == null:
		return
	queue_splat_dirty_chunks(TerrainPaintBrushes.apply_material(map_data, local_center, radius, strength, falloff_power, selected_channel))

func begin_material_paint_brush_stroke() -> void:
	_rebuild.set_stroke_active("material", true)

func finish_material_paint_brush_stroke() -> void:
	_rebuild.set_stroke_active("material", false)
	_mat.update_splat_texture(map_data.splat_map)
	_rebuild.clear_stroke_dirty()

func apply_walkable_paint_brush(local_center: Vector3, radius: float, walkable_value: int) -> void:
	if map_data == null:
		return
	queue_gameplay_dirty_chunks(TerrainPaintBrushes.apply_walkable(map_data, local_center, radius, walkable_value), TerrainMapData.OverlayMode.WALKABLE)

func begin_walkable_paint_brush_stroke() -> void:
	_rebuild.set_stroke_active("walkable", true)

func finish_walkable_paint_brush_stroke() -> void:
	_finish_paint_stroke("walkable")

func apply_buildable_paint_brush(local_center: Vector3, radius: float, buildable_value: int) -> void:
	if map_data == null:
		return
	queue_gameplay_dirty_chunks(TerrainPaintBrushes.apply_buildable(map_data, local_center, radius, buildable_value), TerrainMapData.OverlayMode.BUILDABLE)

func begin_buildable_paint_brush_stroke() -> void:
	_rebuild.set_stroke_active("buildable", true)

func finish_buildable_paint_brush_stroke() -> void:
	_finish_paint_stroke("buildable")

func apply_fow_height_paint_brush(local_center: Vector3, radius: float, fow_height: int) -> void:
	if map_data == null:
		return
	queue_gameplay_dirty_chunks(TerrainPaintBrushes.apply_fow_height(map_data, local_center, radius, fow_height), TerrainMapData.OverlayMode.FOW_HEIGHT)

func begin_fow_height_paint_brush_stroke() -> void:
	_rebuild.set_stroke_active("fow_height", true)

func finish_fow_height_paint_brush_stroke() -> void:
	_finish_paint_stroke("fow_height")

# ── Chunk dirty routing ───────────────────────────────────────────────────────

func queue_dirty_chunks(chunk_coords: Array[Vector2i], pretty_normals: bool = false) -> void:
	for chunk_coord in chunk_coords:
		if not map_data.is_chunk_valid(chunk_coord):
			continue
		_rebuild.mark_stroke_dirty(chunk_coord)
		var chunk := chunks.get(_chunk_key(chunk_coord)) as TerrainChunk
		if chunk != null:
			chunk.mark_dirty()
		_rebuild.queue_mesh(chunk_coord, pretty_normals or rebuild_pretty_normals_during_stroke)
		if rebuild_colliders_during_stroke or not _rebuild.is_height_stroke_active():
			_rebuild.queue_collider(chunk_coord)

func queue_splat_dirty_chunks(chunk_coords: Array[Vector2i]) -> void:
	for chunk_coord in chunk_coords:
		if not map_data.is_chunk_valid(chunk_coord):
			continue
		_rebuild.mark_stroke_dirty(chunk_coord)
		var chunk := chunks.get(_chunk_key(chunk_coord)) as TerrainChunk
		if chunk != null:
			chunk.mark_dirty()
	_mat.update_splat_texture(map_data.splat_map)

func queue_gameplay_dirty_chunks(chunk_coords: Array[Vector2i], changed_overlay_mode: int) -> void:
	for chunk_coord in chunk_coords:
		if not map_data.is_chunk_valid(chunk_coord):
			continue
		_rebuild.mark_stroke_dirty(chunk_coord)
		var chunk := chunks.get(_chunk_key(chunk_coord)) as TerrainChunk
		if chunk != null:
			chunk.mark_dirty()
		if _overlay_enabled and _overlay_mode == changed_overlay_mode:
			_rebuild_chunk_overlay(chunk_coord)

func flush_rebuild_queues() -> void:
	_rebuild.flush(chunks)

# ── Overlay ───────────────────────────────────────────────────────────────────

func set_overlay_enabled(enabled: bool) -> void:
	_overlay_enabled = enabled
	_apply_overlay_state_to_chunks()

func set_overlay_mode(mode: int) -> void:
	_overlay_mode = clampi(mode, TerrainMapData.OverlayMode.NONE, TerrainMapData.OverlayMode.FOW_HEIGHT)
	_apply_overlay_state_to_chunks()
	_rebuild_all_overlays()

# ── Save / load ───────────────────────────────────────────────────────────────

func save_map(path: String, map_name: String = "Authored Map") -> bool:
	return TerrainSerializer.save(map_data, path, map_name)

func load_map(path: String) -> bool:
	var new_map_data := TerrainSerializer.load(path)
	if new_map_data == null:
		return false

	map_data = new_map_data
	_clear_children(_chunk_root)
	chunks.clear()
	_rebuild.reset()
	_build_all_chunks()
	_rebuild_bounds()

	var total_chunks := map_data.get_total_chunks()
	for z in range(total_chunks.y):
		for x in range(total_chunks.x):
			var chunk_coord := Vector2i(x, z)
			_rebuild.queue_mesh(chunk_coord, true)
			_rebuild.queue_collider(chunk_coord)
	_rebuild.flush(chunks)
	return true

# ── Terrain queries ───────────────────────────────────────────────────────────

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

func get_height_at_local_position(local_position: Vector3) -> float:
	if map_data == null:
		return 0.0
	return map_data.get_height(map_data.local_to_grid(local_position))

func get_visual_cell_from_local_position(local_position: Vector3) -> Vector2i:
	if map_data == null:
		return Vector2i.ZERO
	return Vector2i(
		int(floor(local_position.x / map_data.cell_size)),
		int(floor(local_position.z / map_data.cell_size))
	)

func get_playable_cell_from_local_position(local_position: Vector3) -> Vector2i:
	if map_data == null:
		return Vector2i.ZERO
	return map_data.visual_cell_to_playable_cell(get_visual_cell_from_local_position(local_position))

func get_walkable_at_local_position(local_position: Vector3) -> int:
	if map_data == null:
		return TerrainMapData.Walkable.NONE
	return map_data.get_walkable_value_for_visual_cell(get_visual_cell_from_local_position(local_position))

func is_ground_walkable_at_local_position(local_position: Vector3) -> bool:
	return get_walkable_at_local_position(local_position) == TerrainMapData.Walkable.ALL

func get_center_position() -> Vector3:
	if map_data == null:
		return Vector3.ZERO
	var total_size := map_data.get_total_size()
	return Vector3(total_size.x * 0.5, 0.0, total_size.y * 0.5)

# ── Internals ─────────────────────────────────────────────────────────────────

func _build_all_chunks() -> void:
	var total_chunks := map_data.get_total_chunks()
	_mat.setup(material_texture_scale)
	_mat.update_splat_texture(map_data.splat_map)
	for z in range(total_chunks.y):
		for x in range(total_chunks.x):
			var chunk_coord := Vector2i(x, z)
			var chunk := TerrainChunkScene.instantiate() as TerrainChunk
			_chunk_root.add_child(chunk)
			chunk.setup(chunk_coord, map_data, _mat.terrain_material, _mat.overlay_material)
			chunk.set_overlay_state(_overlay_enabled, _overlay_mode, overlay_normal_offset)
			chunk.rebuild_overlay()
			chunks[_chunk_key(chunk_coord)] = chunk

func _rebuild_bounds() -> void:
	_clear_children(_bounds_root)
	_bounds_root.add_child(_create_bounds_mesh("PlayableBounds", map_data.get_playable_min(), map_data.get_playable_max(), Color(1.0, 0.9, 0.1), 0.08))
	_bounds_root.add_child(_create_bounds_mesh("BorderBounds", Vector2.ZERO, map_data.get_total_size(), Color(0.15, 0.9, 1.0), 0.05))

func _create_bounds_mesh(node_name: String, min_corner: Vector2, max_corner: Vector2, color: Color, y: float) -> MeshInstance3D:
	var mesh := ArrayMesh.new()
	var vertices := PackedVector3Array([
		Vector3(min_corner.x, y, min_corner.y), Vector3(max_corner.x, y, min_corner.y),
		Vector3(max_corner.x, y, min_corner.y), Vector3(max_corner.x, y, max_corner.y),
		Vector3(max_corner.x, y, max_corner.y), Vector3(min_corner.x, y, max_corner.y),
		Vector3(min_corner.x, y, max_corner.y), Vector3(min_corner.x, y, min_corner.y),
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

func _apply_overlay_state_to_chunks() -> void:
	for value in chunks.values():
		var chunk := value as TerrainChunk
		if chunk != null:
			chunk.set_overlay_state(_overlay_enabled, _overlay_mode, overlay_normal_offset)

func _rebuild_all_overlays() -> void:
	for value in chunks.values():
		var chunk := value as TerrainChunk
		if chunk != null:
			chunk.rebuild_overlay()

func _rebuild_chunk_overlay(chunk_coord: Vector2i) -> void:
	if not _overlay_enabled or _overlay_mode == TerrainMapData.OverlayMode.NONE:
		return
	var chunk := chunks.get(_chunk_key(chunk_coord)) as TerrainChunk
	if chunk != null:
		chunk.rebuild_overlay()

func _finish_deforming_stroke(stroke_name: String) -> void:
	_rebuild.set_stroke_active(stroke_name, false)
	for value in _rebuild.get_stroke_dirty_chunks():
		var chunk_coord: Vector2i = value
		_rebuild.queue_mesh(chunk_coord, true)
		_rebuild.queue_collider(chunk_coord)
		_rebuild_chunk_overlay(chunk_coord)
	_rebuild.clear_stroke_dirty()
	_rebuild.drain_mesh_batch(chunks, mesh_chunks_per_frame)

func _finish_paint_stroke(stroke_name: String) -> void:
	_rebuild.set_stroke_active(stroke_name, false)
	_rebuild.clear_stroke_dirty()

func _chunk_key(chunk_coord: Vector2i) -> String:
	return "%d,%d" % [chunk_coord.x, chunk_coord.y]
