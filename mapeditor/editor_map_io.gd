class_name EditorMapIO

const MAX_PLAYABLE_CHUNKS := 512
const _SAVE_PATH := "res://levels/test_map/map_data.res"
const _SAVE_DIR  := "res://levels/test_map"
const _MAP_NAME  := "Test Map"

var _terrain: Terrain
var _camera_rig: EditorCameraRig
var _menu_bar: Node  # EditorMenuBar — loosely typed to avoid circular dependency
var _overwrite_dialog: ConfirmationDialog
var _map_dirty := false
var _pending_chunks := Vector2i.ZERO

func setup(terrain: Terrain, camera_rig: EditorCameraRig, menu_bar: Node, overwrite_dialog: ConfirmationDialog) -> void:
	_terrain = terrain
	_camera_rig = camera_rig
	_menu_bar = menu_bar
	_overwrite_dialog = overwrite_dialog
	overwrite_dialog.confirmed.connect(_create_pending_new_map)

func mark_dirty() -> void:
	_map_dirty = true

func save() -> void:
	if DirAccess.open(_SAVE_DIR) == null:
		DirAccess.make_dir_recursive_absolute(_SAVE_DIR)
	if _terrain.save_map(_SAVE_PATH, _MAP_NAME):
		_map_dirty = false

func load() -> void:
	if not ResourceLoader.exists(_SAVE_PATH):
		push_error("Map file not found: %s" % _SAVE_PATH)
		return
	if _terrain.load_map(_SAVE_PATH):
		_camera_rig.frame_point(_terrain.get_center_position())
		_menu_bar.set_current_playable_chunks(_terrain.playable_chunks)
		_map_dirty = false

func request_new(playable_chunks: Vector2i) -> void:
	_pending_chunks = Vector2i(
		clampi(playable_chunks.x, 1, MAX_PLAYABLE_CHUNKS),
		clampi(playable_chunks.y, 1, MAX_PLAYABLE_CHUNKS)
	)
	if _map_dirty:
		_overwrite_dialog.popup_centered()
	else:
		_create_pending_new_map()

func _create_pending_new_map() -> void:
	if _pending_chunks == Vector2i.ZERO:
		return
	_terrain.create_flat_grass_map_with_size(_pending_chunks, 2)
	_terrain.flush_rebuild_queues()
	_camera_rig.frame_point(_terrain.get_center_position())
	_menu_bar.set_current_playable_chunks(_terrain.playable_chunks)
	_map_dirty = false
	_pending_chunks = Vector2i.ZERO
