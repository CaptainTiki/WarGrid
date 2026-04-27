extends Node3D
class_name Terrain

const TerrainChunkScene := preload("res://terrain/terrain_chunk.tscn")
const Material0Albedo := preload("res://assets/textures/terrain/grass.png")
const Material1Albedo := preload("res://assets/textures/terrain/dirt.png")
const Material2Albedo := preload("res://assets/textures/terrain/rock.png")
const Material3Albedo := preload("res://assets/textures/terrain/sand.png")

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
var _terrain_material: ShaderMaterial
var _overlay_material: StandardMaterial3D
var _terrain_shader_material: ShaderMaterial
var _splat_texture: ImageTexture
var _overlay_enabled := false
var _overlay_mode := TerrainMapData.OverlayMode.NONE
var _mesh_rebuild_queue: Array[Vector2i] = []
var _collider_rebuild_queue: Array[Vector2i] = []
var _pretty_mesh_rebuild_lookup := {}
var _mesh_rebuild_lookup := {}
var _collider_rebuild_lookup := {}
var _stroke_dirty_lookup := {}
var _collider_rebuild_elapsed := 0.0
var _height_brush_stroke_active := false
var _smooth_brush_stroke_active := false
var _flatten_brush_stroke_active := false
var _material_paint_brush_stroke_active := false
var _walkable_paint_brush_stroke_active := false
var _buildable_paint_brush_stroke_active := false
var _fow_height_paint_brush_stroke_active := false
var _flatten_target_height := 0.0

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

func create_flat_grass_map_with_size(new_playable_chunks: Vector2i, new_border_chunks: int = border_chunks) -> void:
	playable_chunks = Vector2i(maxi(new_playable_chunks.x, 1), maxi(new_playable_chunks.y, 1))
	border_chunks = maxi(new_border_chunks, 0)
	create_flat_grass_map()

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
		_rebuild_chunk_overlay(chunk_coord)
	_stroke_dirty_lookup.clear()
	_drain_mesh_rebuild_queue(mesh_chunks_per_frame)

func apply_flatten_brush(local_center: Vector3, radius: float, strength: float, falloff_power: float, target_height: float) -> void:
	if map_data == null:
		return

	var touched_chunks := map_data.apply_flatten_brush(local_center, radius, strength, falloff_power, target_height)
	queue_dirty_chunks(touched_chunks)

func begin_flatten_brush_stroke(target_height: float) -> void:
	_flatten_brush_stroke_active = true
	_flatten_target_height = target_height

func finish_flatten_brush_stroke() -> void:
	_flatten_brush_stroke_active = false
	for value in _stroke_dirty_lookup.values():
		var chunk_coord: Vector2i = value
		_queue_mesh_rebuild(chunk_coord, true)
		_queue_collider_rebuild(chunk_coord)
		_rebuild_chunk_overlay(chunk_coord)
	_stroke_dirty_lookup.clear()
	_drain_mesh_rebuild_queue(mesh_chunks_per_frame)

func apply_material_paint_brush(local_center: Vector3, radius: float, strength: float, falloff_power: float, selected_channel: int) -> void:
	if map_data == null:
		return

	var touched_chunks := map_data.apply_material_paint_brush(local_center, radius, strength, falloff_power, selected_channel)
	queue_splat_dirty_chunks(touched_chunks)

func begin_material_paint_brush_stroke() -> void:
	_material_paint_brush_stroke_active = true

func finish_material_paint_brush_stroke() -> void:
	_material_paint_brush_stroke_active = false
	_update_splat_texture()
	_stroke_dirty_lookup.clear()

func apply_walkable_paint_brush(local_center: Vector3, radius: float, walkable_value: int) -> void:
	if map_data == null:
		return

	var touched_chunks := map_data.apply_walkable_paint_brush(local_center, radius, walkable_value)
	queue_gameplay_dirty_chunks(touched_chunks, TerrainMapData.OverlayMode.WALKABLE)

func begin_walkable_paint_brush_stroke() -> void:
	_walkable_paint_brush_stroke_active = true

func finish_walkable_paint_brush_stroke() -> void:
	_walkable_paint_brush_stroke_active = false
	_stroke_dirty_lookup.clear()

func apply_buildable_paint_brush(local_center: Vector3, radius: float, buildable_value: int) -> void:
	if map_data == null:
		return

	var touched_chunks := map_data.apply_buildable_paint_brush(local_center, radius, buildable_value)
	queue_gameplay_dirty_chunks(touched_chunks, TerrainMapData.OverlayMode.BUILDABLE)

func begin_buildable_paint_brush_stroke() -> void:
	_buildable_paint_brush_stroke_active = true

func finish_buildable_paint_brush_stroke() -> void:
	_buildable_paint_brush_stroke_active = false
	_stroke_dirty_lookup.clear()

func apply_fow_height_paint_brush(local_center: Vector3, radius: float, fow_height: int) -> void:
	if map_data == null:
		return

	var touched_chunks := map_data.apply_fow_height_paint_brush(local_center, radius, fow_height)
	queue_gameplay_dirty_chunks(touched_chunks, TerrainMapData.OverlayMode.FOW_HEIGHT)

func begin_fow_height_paint_brush_stroke() -> void:
	_fow_height_paint_brush_stroke_active = true

func finish_fow_height_paint_brush_stroke() -> void:
	_fow_height_paint_brush_stroke_active = false
	_stroke_dirty_lookup.clear()

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
		var brush_stroke_active := _height_brush_stroke_active or _smooth_brush_stroke_active or _flatten_brush_stroke_active
		if rebuild_colliders_during_stroke or not brush_stroke_active:
			_queue_collider_rebuild(chunk_coord)

func queue_splat_dirty_chunks(chunk_coords: Array[Vector2i]) -> void:
	for chunk_coord in chunk_coords:
		if not map_data.is_chunk_valid(chunk_coord):
			continue
		var key := _chunk_key(chunk_coord)
		_stroke_dirty_lookup[key] = chunk_coord
		var chunk := chunks.get(key) as TerrainChunk
		if chunk != null:
			chunk.mark_dirty()
	_update_splat_texture()

func queue_gameplay_dirty_chunks(chunk_coords: Array[Vector2i], changed_overlay_mode: int) -> void:
	for chunk_coord in chunk_coords:
		if not map_data.is_chunk_valid(chunk_coord):
			continue
		var key := _chunk_key(chunk_coord)
		_stroke_dirty_lookup[key] = chunk_coord
		var chunk := chunks.get(key) as TerrainChunk
		if chunk != null:
			chunk.mark_dirty()
		if _overlay_enabled and _overlay_mode == changed_overlay_mode:
			_rebuild_chunk_overlay(chunk_coord)

func finish_height_brush_stroke() -> void:
	_height_brush_stroke_active = false
	for value in _stroke_dirty_lookup.values():
		var chunk_coord: Vector2i = value
		_queue_mesh_rebuild(chunk_coord, true)
		_queue_collider_rebuild(chunk_coord)
		_rebuild_chunk_overlay(chunk_coord)
	_stroke_dirty_lookup.clear()
	_drain_mesh_rebuild_queue(mesh_chunks_per_frame)

func set_overlay_enabled(enabled: bool) -> void:
	_overlay_enabled = enabled
	_apply_overlay_state_to_chunks()

func set_overlay_mode(mode: int) -> void:
	_overlay_mode = clampi(mode, TerrainMapData.OverlayMode.NONE, TerrainMapData.OverlayMode.FOW_HEIGHT)
	_apply_overlay_state_to_chunks()
	_rebuild_all_overlays()

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

func save_map(path: String, map_name: String = "Authored Map") -> bool:
	if map_data == null:
		push_error("Cannot save: map_data is null")
		return false

	var resource := TerrainMapResource.new()
	resource.map_name = map_name
	resource.chunk_size_meters = map_data.chunk_size_meters
	resource.cell_size = map_data.cell_size
	resource.playable_chunks = map_data.playable_chunks
	resource.border_chunks = map_data.border_chunks
	resource.base_heights = map_data.base_heights.duplicate()
	if map_data.splat_map != null:
		resource.splat_map = map_data.splat_map.duplicate()
	resource.walkable_data = map_data.walkable_data.duplicate()
	resource.buildable_data = map_data.buildable_data.duplicate()
	resource.fow_height_data = map_data.fow_height_data.duplicate()

	var error := ResourceSaver.save(resource, path)
	if error == OK:
		print("Map saved: %s" % path)
		return true
	else:
		push_error("Failed to save map: error code %d" % error)
		return false

func load_map(path: String) -> bool:
	var resource := ResourceLoader.load(path) as TerrainMapResource
	if resource == null:
		push_error("Failed to load map from: %s" % path)
		return false

	# Create new map data from resource
	var new_map_data := TerrainMapData.new()
	new_map_data.chunk_size_meters = resource.chunk_size_meters
	new_map_data.cell_size = resource.cell_size
	new_map_data.playable_chunks = resource.playable_chunks
	new_map_data.border_chunks = resource.border_chunks
	new_map_data._refresh_cached_sizes()

	# Restore height data
	new_map_data.base_heights = resource.base_heights.duplicate()
	new_map_data.material_ids.resize(new_map_data.get_total_cell_count().x * new_map_data.get_total_cell_count().y)
	for i in new_map_data.material_ids.size():
		new_map_data.material_ids[i] = TerrainMapData.GRASS_MATERIAL_ID
	if resource.splat_map != null:
		new_map_data.splat_map = resource.splat_map.duplicate()
	else:
		new_map_data.splat_map = Image.create(new_map_data.get_total_cell_count().x, new_map_data.get_total_cell_count().y, false, Image.FORMAT_RGBA8)
		new_map_data.splat_map.fill(Color(1.0, 0.0, 0.0, 0.0))
	_restore_or_default_gameplay_data(new_map_data, resource)

	# Replace and rebuild
	map_data = new_map_data
	_clear_children(_chunk_root)
	chunks.clear()
	_clear_rebuild_queues()
	_build_all_chunks()
	_rebuild_bounds()

	# Queue all chunks for mesh rebuild with pretty normals and collider rebuild
	var total_chunks := map_data.get_total_chunks()
	for z in range(total_chunks.y):
		for x in range(total_chunks.x):
			var chunk_coord := Vector2i(x, z)
			_queue_mesh_rebuild(chunk_coord, true)
			_queue_collider_rebuild(chunk_coord)

	# Drain rebuild queues to complete the rebuild immediately
	flush_rebuild_queues()

	print("Map loaded: %s" % path)
	return true

func _build_all_chunks() -> void:
	var total_chunks := map_data.get_total_chunks()
	_terrain_material = _create_terrain_material()
	_overlay_material = _create_overlay_material()
	for z in range(total_chunks.y):
		for x in range(total_chunks.x):
			var chunk_coord := Vector2i(x, z)
			var chunk := TerrainChunkScene.instantiate() as TerrainChunk
			_chunk_root.add_child(chunk)
			chunk.setup(chunk_coord, map_data, _terrain_material, _overlay_material)
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
	_flatten_brush_stroke_active = false
	_material_paint_brush_stroke_active = false
	_walkable_paint_brush_stroke_active = false
	_buildable_paint_brush_stroke_active = false
	_fow_height_paint_brush_stroke_active = false

func _create_terrain_material() -> ShaderMaterial:
	var material := ShaderMaterial.new()
	material.resource_name = "TerrainSplatMaterial"
	material.shader = _create_terrain_shader()
	_terrain_shader_material = material
	_update_splat_texture()
	material.set_shader_parameter("material_0_albedo", Material0Albedo)
	material.set_shader_parameter("material_1_albedo", Material1Albedo)
	material.set_shader_parameter("material_2_albedo", Material2Albedo)
	material.set_shader_parameter("material_3_albedo", Material3Albedo)
	material.set_shader_parameter("material_texture_scale", material_texture_scale)
	return material

func _create_terrain_shader() -> Shader:
	var shader := Shader.new()
	shader.code = """
shader_type spatial;

uniform sampler2D splat_texture : filter_linear, repeat_disable;
uniform sampler2D material_0_albedo : source_color, filter_linear, repeat_enable;
uniform sampler2D material_1_albedo : source_color, filter_linear, repeat_enable;
uniform sampler2D material_2_albedo : source_color, filter_linear, repeat_enable;
uniform sampler2D material_3_albedo : source_color, filter_linear, repeat_enable;
uniform float material_texture_scale = 8.0;

void fragment() {
	vec4 weights = texture(splat_texture, UV);
	float total_weight = max(weights.r + weights.g + weights.b + weights.a, 0.0001);
	weights /= total_weight;
	vec2 tiled_uv = UV * material_texture_scale;
	vec3 blended = texture(material_0_albedo, tiled_uv).rgb * weights.r;
	blended += texture(material_1_albedo, tiled_uv).rgb * weights.g;
	blended += texture(material_2_albedo, tiled_uv).rgb * weights.b;
	blended += texture(material_3_albedo, tiled_uv).rgb * weights.a;
	ALBEDO = blended;
	ROUGHNESS = 0.9;
}
"""
	return shader

func _update_splat_texture() -> void:
	if map_data == null or map_data.splat_map == null or _terrain_shader_material == null:
		return
	if _splat_texture == null or _splat_texture.get_width() != map_data.splat_map.get_width() or _splat_texture.get_height() != map_data.splat_map.get_height():
		_splat_texture = ImageTexture.create_from_image(map_data.splat_map)
	else:
		_splat_texture.update(map_data.splat_map)
	_terrain_shader_material.set_shader_parameter("splat_texture", _splat_texture)

func _create_overlay_material() -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.resource_name = "TerrainGameplayOverlayMaterial"
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.vertex_color_use_as_albedo = true
	material.albedo_color = Color(1.0, 1.0, 1.0, 1.0)
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	material.no_depth_test = false
	return material

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

func _restore_or_default_gameplay_data(new_map_data: TerrainMapData, resource: TerrainMapResource) -> void:
	var playable_cells: Vector2i = new_map_data.get_playable_cell_count()
	var cell_count: int = playable_cells.x * playable_cells.y
	if resource.walkable_data.size() == cell_count:
		new_map_data.walkable_data = resource.walkable_data.duplicate()
	else:
		new_map_data.walkable_data.resize(cell_count)
		for i in range(cell_count):
			new_map_data.walkable_data[i] = TerrainMapData.Walkable.ALL
	if resource.buildable_data.size() == cell_count:
		new_map_data.buildable_data = resource.buildable_data.duplicate()
	else:
		new_map_data.buildable_data.resize(cell_count)
		for i in range(cell_count):
			new_map_data.buildable_data[i] = TerrainMapData.Buildable.OPEN
	if resource.fow_height_data.size() == cell_count:
		new_map_data.fow_height_data = resource.fow_height_data.duplicate()
	else:
		new_map_data.fow_height_data.resize(cell_count)
		for i in range(cell_count):
			new_map_data.fow_height_data[i] = 0

func _chunk_key(chunk_coord: Vector2i) -> String:
	return "%d,%d" % [chunk_coord.x, chunk_coord.y]
