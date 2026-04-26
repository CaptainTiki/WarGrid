extends Node3D
class_name Terrain

const TerrainChunkScene := preload("res://terrain/terrain_chunk.tscn")

@export var playable_chunks := Vector2i(1, 1)
@export var chunk_size_meters := 64
@export var border_chunks := 1
@export var cell_size := 1.0

var map_data: TerrainMapData
var chunks := {}
var dirty_chunks: Array[Vector2i] = []

var _chunk_root: Node3D
var _bounds_root: Node3D
var _pick_body: StaticBody3D
var _grass_material: StandardMaterial3D

func _ready() -> void:
	create_flat_grass_map()

func create_flat_grass_map() -> void:
	map_data = TerrainMapData.new()
	map_data.chunk_size_meters = chunk_size_meters
	map_data.border_chunks = border_chunks
	map_data.cell_size = cell_size
	map_data.create_flat_grass_map(playable_chunks, 0.0)
	_ensure_roots()
	_clear_children(_chunk_root)
	chunks.clear()
	_build_all_chunks()
	_rebuild_collider()
	_rebuild_bounds()

func apply_height_brush(local_center: Vector3, radius: float, amount: float) -> void:
	if map_data == null:
		return

	var touched_chunks := map_data.apply_height_brush(local_center, radius, amount)
	mark_chunks_dirty(touched_chunks)
	rebuild_dirty_chunks()
	_rebuild_collider()

func mark_chunks_dirty(chunk_coords: Array[Vector2i]) -> void:
	var dirty_lookup := {}
	for existing in dirty_chunks:
		dirty_lookup[_chunk_key(existing)] = true

	for chunk_coord in chunk_coords:
		for neighbor in _neighbor_chunks_for_seams(chunk_coord):
			if not map_data.is_chunk_valid(neighbor):
				continue
			var key := _chunk_key(neighbor)
			if dirty_lookup.has(key):
				continue
			dirty_lookup[key] = true
			dirty_chunks.append(neighbor)
			var chunk := chunks.get(key) as TerrainChunk
			if chunk != null:
				chunk.mark_dirty()

func rebuild_dirty_chunks() -> void:
	for chunk_coord in dirty_chunks:
		var chunk := chunks.get(_chunk_key(chunk_coord)) as TerrainChunk
		if chunk != null:
			chunk.rebuild()
	dirty_chunks.clear()

func get_pick_point(camera: Camera3D, screen_position: Vector2) -> Variant:
	if camera == null:
		return null

	var from := camera.project_ray_origin(screen_position)
	var to := from + camera.project_ray_normal(screen_position) * 4096.0
	var query := PhysicsRayQueryParameters3D.create(from, to)
	query.collide_with_areas = false
	query.collide_with_bodies = true
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	if hit.is_empty() or hit.get("collider") != _pick_body:
		return null
	return to_local(hit.position)

func get_center_position() -> Vector3:
	if map_data == null:
		return Vector3.ZERO
	var total_size := map_data.get_total_size()
	return Vector3(total_size.x * 0.5, 0.0, total_size.y * 0.5)

func _build_all_chunks() -> void:
	var total_chunks := map_data.get_total_chunks()
	_grass_material = _create_grass_material()
	for z in range(total_chunks.y):
		for x in range(total_chunks.x):
			var chunk_coord := Vector2i(x, z)
			var chunk := TerrainChunkScene.instantiate() as TerrainChunk
			_chunk_root.add_child(chunk)
			chunk.setup(chunk_coord, map_data, _grass_material)
			chunks[_chunk_key(chunk_coord)] = chunk

func _rebuild_collider() -> void:
	if _pick_body == null:
		_pick_body = StaticBody3D.new()
		_pick_body.name = "PlayablePickCollider"
		add_child(_pick_body)
		var collision_shape := CollisionShape3D.new()
		collision_shape.name = "CollisionShape3D"
		_pick_body.add_child(collision_shape)

	var shape_node := _pick_body.get_node("CollisionShape3D") as CollisionShape3D
	shape_node.shape = TerrainColliderBuilder.build_playable_collision_shape(map_data)

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

func _create_grass_material() -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.24, 0.55, 0.20)
	material.roughness = 0.9
	return material

func _neighbor_chunks_for_seams(chunk_coord: Vector2i) -> Array[Vector2i]:
	return [
		chunk_coord,
		chunk_coord + Vector2i.LEFT,
		chunk_coord + Vector2i.RIGHT,
		chunk_coord + Vector2i.UP,
		chunk_coord + Vector2i.DOWN,
	]

func _chunk_key(chunk_coord: Vector2i) -> String:
	return "%d,%d" % [chunk_coord.x, chunk_coord.y]
