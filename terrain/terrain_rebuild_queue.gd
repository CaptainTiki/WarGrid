class_name TerrainRebuildQueue

var _mesh_rebuild_queue: Array[Vector2i] = []
var _collider_rebuild_queue: Array[Vector2i] = []
var _pretty_mesh_rebuild_lookup := {}
var _mesh_rebuild_lookup := {}
var _collider_rebuild_lookup := {}
var _stroke_dirty_lookup := {}
var _collider_rebuild_elapsed := 0.0
var _height_stroke_active := false
var _smooth_stroke_active := false
var _flatten_stroke_active := false
var _material_stroke_active := false
var _walkable_stroke_active := false
var _buildable_stroke_active := false
var _fow_height_stroke_active := false

func tick(delta: float, chunks: Dictionary, mesh_chunks_per_frame: int, collider_chunks_per_tick: int, collider_rebuild_interval: float) -> void:
	_drain_mesh(chunks, mesh_chunks_per_frame)
	_collider_rebuild_elapsed += delta
	if _collider_rebuild_elapsed >= collider_rebuild_interval:
		_collider_rebuild_elapsed = 0.0
		_drain_colliders(chunks, collider_chunks_per_tick)

func queue_mesh(chunk_coord: Vector2i, pretty_normals: bool = false) -> void:
	var key := _key(chunk_coord)
	if pretty_normals:
		_pretty_mesh_rebuild_lookup[key] = true
	if _mesh_rebuild_lookup.has(key):
		return
	_mesh_rebuild_lookup[key] = true
	_mesh_rebuild_queue.append(chunk_coord)

func queue_collider(chunk_coord: Vector2i) -> void:
	var key := _key(chunk_coord)
	if _collider_rebuild_lookup.has(key):
		return
	_collider_rebuild_lookup[key] = true
	_collider_rebuild_queue.append(chunk_coord)

func mark_stroke_dirty(chunk_coord: Vector2i) -> void:
	_stroke_dirty_lookup[_key(chunk_coord)] = chunk_coord

func get_stroke_dirty_chunks() -> Array:
	return _stroke_dirty_lookup.values()

func clear_stroke_dirty() -> void:
	_stroke_dirty_lookup.clear()

func is_height_stroke_active() -> bool:
	return _height_stroke_active or _smooth_stroke_active or _flatten_stroke_active

func set_stroke_active(stroke_name: String, active: bool) -> void:
	match stroke_name:
		"height":    _height_stroke_active    = active
		"smooth":    _smooth_stroke_active    = active
		"flatten":   _flatten_stroke_active   = active
		"material":  _material_stroke_active  = active
		"walkable":  _walkable_stroke_active  = active
		"buildable": _buildable_stroke_active = active
		"fow_height":_fow_height_stroke_active = active

func drain_mesh_batch(chunks: Dictionary, max_chunks: int) -> void:
	_drain_mesh(chunks, max_chunks)

func flush(chunks: Dictionary) -> void:
	while not _mesh_rebuild_queue.is_empty():
		_drain_mesh(chunks, _mesh_rebuild_queue.size())
	while not _collider_rebuild_queue.is_empty():
		_drain_colliders(chunks, _collider_rebuild_queue.size())

func reset() -> void:
	_mesh_rebuild_queue.clear()
	_collider_rebuild_queue.clear()
	_pretty_mesh_rebuild_lookup.clear()
	_mesh_rebuild_lookup.clear()
	_collider_rebuild_lookup.clear()
	_stroke_dirty_lookup.clear()
	_collider_rebuild_elapsed = 0.0
	_height_stroke_active    = false
	_smooth_stroke_active    = false
	_flatten_stroke_active   = false
	_material_stroke_active  = false
	_walkable_stroke_active  = false
	_buildable_stroke_active = false
	_fow_height_stroke_active = false

func _drain_mesh(chunks: Dictionary, max_chunks: int) -> void:
	var rebuilt := 0
	while rebuilt < max_chunks and not _mesh_rebuild_queue.is_empty():
		var chunk_coord: Vector2i = _mesh_rebuild_queue.pop_front()
		var key := _key(chunk_coord)
		_mesh_rebuild_lookup.erase(key)
		var pretty_normals := _pretty_mesh_rebuild_lookup.has(key)
		_pretty_mesh_rebuild_lookup.erase(key)
		var chunk := chunks.get(key) as TerrainChunk
		if chunk != null:
			chunk.rebuild_mesh(pretty_normals)
			chunk.data.dirty = false
		rebuilt += 1

func _drain_colliders(chunks: Dictionary, max_chunks: int) -> void:
	var rebuilt := 0
	while rebuilt < max_chunks and not _collider_rebuild_queue.is_empty():
		var chunk_coord: Vector2i = _collider_rebuild_queue.pop_front()
		var key := _key(chunk_coord)
		_collider_rebuild_lookup.erase(key)
		var chunk := chunks.get(key) as TerrainChunk
		if chunk != null:
			chunk.rebuild_collider()
		rebuilt += 1

func _key(chunk_coord: Vector2i) -> String:
	return "%d,%d" % [chunk_coord.x, chunk_coord.y]
