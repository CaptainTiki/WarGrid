extends Node3D
class_name MapEditor

const BrushPreviewScene := preload("res://mapeditor/brushes/brush_preview.tscn")
const MaterialPaintBrushToolScript := preload("res://mapeditor/tools/material_paint_brush_tool.gd")
const WalkablePaintBrushToolScript := preload("res://mapeditor/tools/walkable_paint_brush_tool.gd")
const BuildablePaintBrushToolScript := preload("res://mapeditor/tools/buildable_paint_brush_tool.gd")
const FowHeightPaintBrushToolScript := preload("res://mapeditor/tools/fow_height_paint_brush_tool.gd")
const MAX_PLAYABLE_CHUNKS := 512

@onready var terrain: Terrain = $Terrain
@onready var camera_rig: EditorCameraRig = $EditorCameraRig
@onready var menu_bar = $CanvasLayer/EditorMenuBar
@onready var tool_dock: EditorToolDock = $CanvasLayer/EditorToolDock
@onready var overwrite_map_dialog: ConfirmationDialog = $CanvasLayer/OverwriteMapDialog
@onready var preferences_dialog: AcceptDialog = $CanvasLayer/PreferencesDialog

var camera: Camera3D
var brush_preview: BrushPreview
var height_brush_tool := HeightBrushTool.new()
var smooth_brush_tool := SmoothBrushTool.new()
var flatten_brush_tool := FlattenBrushTool.new()
var material_paint_brush_tool := MaterialPaintBrushToolScript.new()
var walkable_paint_brush_tool := WalkablePaintBrushToolScript.new()
var buildable_paint_brush_tool := BuildablePaintBrushToolScript.new()
var fow_height_paint_brush_tool := FowHeightPaintBrushToolScript.new()
var _last_pick_point: Variant = null
var _painting := false
var _lowering := false
var _active_tool := EditorToolDock.TOOL_HEIGHT
var _map_dirty := false
var _pending_new_map_playable_chunks := Vector2i.ZERO

func _ready() -> void:
	add_child(height_brush_tool)
	add_child(smooth_brush_tool)
	add_child(flatten_brush_tool)
	add_child(material_paint_brush_tool)
	add_child(walkable_paint_brush_tool)
	add_child(buildable_paint_brush_tool)
	add_child(fow_height_paint_brush_tool)
	_ensure_light()
	camera_rig.frame_point(terrain.get_center_position())
	camera = camera_rig.get_camera()
	menu_bar.new_map_requested.connect(_on_new_map_requested)
	menu_bar.save_map_requested.connect(_on_save_map)
	menu_bar.load_map_requested.connect(_on_load_map)
	menu_bar.preferences_requested.connect(_on_preferences_requested)
	menu_bar.close_requested.connect(_on_close_requested)
	menu_bar.set_current_playable_chunks(terrain.playable_chunks)
	overwrite_map_dialog.confirmed.connect(_create_pending_new_map)
	tool_dock.tool_selected.connect(_on_tool_selected)
	tool_dock.brush_radius_changed.connect(_on_brush_radius_changed)
	tool_dock.brush_strength_changed.connect(_on_brush_strength_changed)
	tool_dock.brush_falloff_changed.connect(_on_brush_falloff_changed)
	tool_dock.material_channel_changed.connect(_on_material_channel_changed)
	tool_dock.walkable_value_changed.connect(_on_walkable_value_changed)
	tool_dock.buildable_value_changed.connect(_on_buildable_value_changed)
	tool_dock.fow_height_changed.connect(_on_fow_height_changed)
	tool_dock.overlay_enabled_changed.connect(_on_overlay_enabled_changed)
	tool_dock.overlay_mode_changed.connect(_on_overlay_mode_changed)
	tool_dock.save_map_requested.connect(_on_save_map)
	tool_dock.load_map_requested.connect(_on_load_map)
	tool_dock.set_active_tool(_active_tool)
	tool_dock.set_brush_radius(height_brush_tool.brush_data.radius)
	tool_dock.set_brush_strength(height_brush_tool.brush_data.strength)
	tool_dock.set_brush_falloff(height_brush_tool.brush_data.falloff)
	tool_dock.set_material_channel(material_paint_brush_tool.selected_material_channel)
	tool_dock.set_walkable_value(walkable_paint_brush_tool.selected_walkable_value)
	tool_dock.set_buildable_value(buildable_paint_brush_tool.selected_buildable_value)
	tool_dock.set_fow_height(fow_height_paint_brush_tool.selected_fow_height)
	tool_dock.set_overlay_enabled(false)
	tool_dock.set_overlay_mode(TerrainMapData.OverlayMode.NONE)
	brush_preview = BrushPreviewScene.instantiate() as BrushPreview
	terrain.add_child(brush_preview)
	brush_preview.hide_preview()

func _process(delta: float) -> void:
	_update_brush()
	_apply_active_brush(delta)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			if Input.is_key_pressed(KEY_ALT):
				# ALT + wheel up: increase brush size
				var current_radius := _get_active_brush_data().radius
				_set_brush_radius(current_radius + 1.0)
			else:
				# Wheel up alone: move camera up
				camera_rig.move_vertical(1.0)
			get_viewport().set_input_as_handled()
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			if Input.is_key_pressed(KEY_ALT):
				# ALT + wheel down: decrease brush size
				var current_radius := _get_active_brush_data().radius
				_set_brush_radius(current_radius - 1.0)
			else:
				# Wheel down alone: move camera down
				camera_rig.move_vertical(-1.0)
			get_viewport().set_input_as_handled()
		elif event.button_index == MOUSE_BUTTON_LEFT:
			_update_brush()
			_begin_brush_stroke(Input.is_key_pressed(KEY_SHIFT))
			get_viewport().set_input_as_handled()
	elif event is InputEventMouseButton and not event.pressed:
		if event.button_index == MOUSE_BUTTON_LEFT:
			_end_brush_stroke()
			get_viewport().set_input_as_handled()

func _update_brush() -> void:
	_last_pick_point = terrain.get_pick_point(camera, get_viewport().get_mouse_position(), _painting)
	if _last_pick_point == null:
		brush_preview.hide_preview()
		return

	var active_brush_data := _get_active_brush_data()
	brush_preview.set_radius(active_brush_data.radius)
	brush_preview.show_at(_last_pick_point)

func _apply_active_brush(_delta: float) -> void:
	if _last_pick_point == null:
		return

	if not _painting:
		return

	match _active_tool:
		EditorToolDock.TOOL_HEIGHT:
			height_brush_tool.apply_stroke_sample(terrain, _last_pick_point, _lowering)
		EditorToolDock.TOOL_SMOOTH:
			smooth_brush_tool.apply_stroke_sample(terrain, _last_pick_point)
		EditorToolDock.TOOL_FLATTEN:
			flatten_brush_tool.apply_stroke_sample(terrain, _last_pick_point)
		EditorToolDock.TOOL_PAINT_MATERIAL:
			material_paint_brush_tool.apply_stroke_sample(terrain, _last_pick_point)
		EditorToolDock.TOOL_WALKABLE_PAINT:
			walkable_paint_brush_tool.apply_stroke_sample(terrain, _last_pick_point)
		EditorToolDock.TOOL_BUILDABLE_PAINT:
			buildable_paint_brush_tool.apply_stroke_sample(terrain, _last_pick_point)
		EditorToolDock.TOOL_FOW_HEIGHT_PAINT:
			fow_height_paint_brush_tool.apply_stroke_sample(terrain, _last_pick_point)

func _begin_brush_stroke(lowering: bool) -> void:
	if _last_pick_point == null:
		return

	_painting = true
	_lowering = lowering

	match _active_tool:
		EditorToolDock.TOOL_HEIGHT:
			terrain.begin_height_brush_stroke()
			height_brush_tool.begin_stroke(terrain, _last_pick_point, _lowering)
		EditorToolDock.TOOL_SMOOTH:
			terrain.begin_smooth_brush_stroke()
			smooth_brush_tool.begin_stroke(terrain, _last_pick_point)
		EditorToolDock.TOOL_FLATTEN:
			flatten_brush_tool.begin_stroke(terrain, _last_pick_point)
		EditorToolDock.TOOL_PAINT_MATERIAL:
			terrain.begin_material_paint_brush_stroke()
			material_paint_brush_tool.begin_stroke(terrain, _last_pick_point)
		EditorToolDock.TOOL_WALKABLE_PAINT:
			terrain.begin_walkable_paint_brush_stroke()
			walkable_paint_brush_tool.begin_stroke(terrain, _last_pick_point)
		EditorToolDock.TOOL_BUILDABLE_PAINT:
			terrain.begin_buildable_paint_brush_stroke()
			buildable_paint_brush_tool.begin_stroke(terrain, _last_pick_point)
		EditorToolDock.TOOL_FOW_HEIGHT_PAINT:
			terrain.begin_fow_height_paint_brush_stroke()
			fow_height_paint_brush_tool.begin_stroke(terrain, _last_pick_point)

func _end_brush_stroke() -> void:
	if not _painting:
		return

	_painting = false
	match _active_tool:
		EditorToolDock.TOOL_HEIGHT:
			height_brush_tool.end_stroke(terrain)
		EditorToolDock.TOOL_SMOOTH:
			smooth_brush_tool.end_stroke(terrain)
		EditorToolDock.TOOL_FLATTEN:
			flatten_brush_tool.end_stroke(terrain)
		EditorToolDock.TOOL_PAINT_MATERIAL:
			material_paint_brush_tool.end_stroke(terrain)
		EditorToolDock.TOOL_WALKABLE_PAINT:
			walkable_paint_brush_tool.end_stroke(terrain)
		EditorToolDock.TOOL_BUILDABLE_PAINT:
			buildable_paint_brush_tool.end_stroke(terrain)
		EditorToolDock.TOOL_FOW_HEIGHT_PAINT:
			fow_height_paint_brush_tool.end_stroke(terrain)
	_map_dirty = true

func _ensure_light() -> void:
	if has_node("Sun"):
		return

	var sun := DirectionalLight3D.new()
	sun.name = "Sun"
	sun.rotation_degrees = Vector3(-55.0, -35.0, 0.0)
	add_child(sun)

func _on_tool_selected(tool_id: int) -> void:
	_end_brush_stroke()
	_active_tool = tool_id
	tool_dock.set_active_tool(_active_tool)
	if _active_tool == EditorToolDock.TOOL_WALKABLE_PAINT:
		terrain.set_overlay_enabled(true)
		terrain.set_overlay_mode(TerrainMapData.OverlayMode.WALKABLE)
		tool_dock.set_overlay_enabled(true)
		tool_dock.set_overlay_mode(TerrainMapData.OverlayMode.WALKABLE)
	elif _active_tool == EditorToolDock.TOOL_BUILDABLE_PAINT:
		terrain.set_overlay_enabled(true)
		terrain.set_overlay_mode(TerrainMapData.OverlayMode.BUILDABLE)
		tool_dock.set_overlay_enabled(true)
		tool_dock.set_overlay_mode(TerrainMapData.OverlayMode.BUILDABLE)
	elif _active_tool == EditorToolDock.TOOL_FOW_HEIGHT_PAINT:
		terrain.set_overlay_enabled(true)
		terrain.set_overlay_mode(TerrainMapData.OverlayMode.FOW_HEIGHT)
		tool_dock.set_overlay_enabled(true)
		tool_dock.set_overlay_mode(TerrainMapData.OverlayMode.FOW_HEIGHT)

func _on_brush_radius_changed(radius: float) -> void:
	_set_brush_radius(radius)

func _on_brush_strength_changed(strength: float) -> void:
	var clamped_strength := clampf(strength, 0.1, 16.0)
	height_brush_tool.brush_data.strength = clamped_strength
	smooth_brush_tool.brush_data.strength = clamped_strength
	flatten_brush_tool.brush_data.strength = clamped_strength
	material_paint_brush_tool.brush_data.strength = clamped_strength
	tool_dock.set_brush_strength(clamped_strength)

func _on_brush_falloff_changed(falloff: float) -> void:
	var clamped_falloff := clampf(falloff, 0.25, 4.0)
	height_brush_tool.brush_data.falloff = clamped_falloff
	smooth_brush_tool.brush_data.falloff = clamped_falloff
	flatten_brush_tool.brush_data.falloff = clamped_falloff
	material_paint_brush_tool.brush_data.falloff = clamped_falloff
	tool_dock.set_brush_falloff(clamped_falloff)

func _on_material_channel_changed(channel: int) -> void:
	material_paint_brush_tool.selected_material_channel = clampi(channel, 0, 3)
	tool_dock.set_material_channel(material_paint_brush_tool.selected_material_channel)

func _on_walkable_value_changed(value: int) -> void:
	walkable_paint_brush_tool.selected_walkable_value = clampi(value, TerrainMapData.Walkable.ALL, TerrainMapData.Walkable.NONE)
	tool_dock.set_walkable_value(walkable_paint_brush_tool.selected_walkable_value)

func _on_buildable_value_changed(value: int) -> void:
	buildable_paint_brush_tool.selected_buildable_value = clampi(value, TerrainMapData.Buildable.OPEN, TerrainMapData.Buildable.BLOCKED)
	tool_dock.set_buildable_value(buildable_paint_brush_tool.selected_buildable_value)

func _on_fow_height_changed(height: int) -> void:
	fow_height_paint_brush_tool.selected_fow_height = clampi(height, 0, 3)
	tool_dock.set_fow_height(fow_height_paint_brush_tool.selected_fow_height)

func _on_overlay_enabled_changed(enabled: bool) -> void:
	terrain.set_overlay_enabled(enabled)
	tool_dock.set_overlay_enabled(enabled)

func _on_overlay_mode_changed(mode: int) -> void:
	terrain.set_overlay_mode(mode)
	tool_dock.set_overlay_mode(mode)

func _set_brush_radius(radius: float) -> void:
	var clamped_radius := clampf(radius, 1.0, 32.0)
	height_brush_tool.brush_data.radius = clamped_radius
	smooth_brush_tool.brush_data.radius = clamped_radius
	flatten_brush_tool.brush_data.radius = clamped_radius
	material_paint_brush_tool.brush_data.radius = clamped_radius
	walkable_paint_brush_tool.brush_data.radius = clamped_radius
	buildable_paint_brush_tool.brush_data.radius = clamped_radius
	fow_height_paint_brush_tool.brush_data.radius = clamped_radius
	brush_preview.set_radius(clamped_radius)
	tool_dock.set_brush_radius(clamped_radius)

func _get_active_brush_data() -> TerrainBrushData:
	match _active_tool:
		EditorToolDock.TOOL_HEIGHT:
			return height_brush_tool.brush_data
		EditorToolDock.TOOL_SMOOTH:
			return smooth_brush_tool.brush_data
		EditorToolDock.TOOL_FLATTEN:
			return flatten_brush_tool.brush_data
		EditorToolDock.TOOL_PAINT_MATERIAL:
			return material_paint_brush_tool.brush_data
		EditorToolDock.TOOL_WALKABLE_PAINT:
			return walkable_paint_brush_tool.brush_data
		EditorToolDock.TOOL_BUILDABLE_PAINT:
			return buildable_paint_brush_tool.brush_data
		EditorToolDock.TOOL_FOW_HEIGHT_PAINT:
			return fow_height_paint_brush_tool.brush_data
		_:
			return height_brush_tool.brush_data

func _on_save_map() -> void:
	_end_brush_stroke()
	var save_path := "res://levels/test_map/map_data.res"
	var dir := DirAccess.open("res://levels/test_map")
	if dir == null:
		DirAccess.make_dir_recursive_absolute("res://levels/test_map")
	if terrain.save_map(save_path, "Test Map"):
		_map_dirty = false

func _on_load_map() -> void:
	_end_brush_stroke()
	var load_path := "res://levels/test_map/map_data.res"
	if not ResourceLoader.exists(load_path):
		push_error("Map file not found: %s" % load_path)
		return
	if terrain.load_map(load_path):
		camera_rig.frame_point(terrain.get_center_position())
		menu_bar.set_current_playable_chunks(terrain.playable_chunks)
		_map_dirty = false

func _on_new_map_requested(playable_chunks: Vector2i) -> void:
	_end_brush_stroke()
	_pending_new_map_playable_chunks = Vector2i(clampi(playable_chunks.x, 1, MAX_PLAYABLE_CHUNKS), clampi(playable_chunks.y, 1, MAX_PLAYABLE_CHUNKS))
	if _map_dirty:
		overwrite_map_dialog.popup_centered()
	else:
		_create_pending_new_map()

func _create_pending_new_map() -> void:
	if _pending_new_map_playable_chunks == Vector2i.ZERO:
		return
	terrain.create_flat_grass_map_with_size(_pending_new_map_playable_chunks, 2)
	terrain.flush_rebuild_queues()
	camera_rig.frame_point(terrain.get_center_position())
	menu_bar.set_current_playable_chunks(terrain.playable_chunks)
	_map_dirty = false
	_pending_new_map_playable_chunks = Vector2i.ZERO

func _on_preferences_requested() -> void:
	preferences_dialog.popup_centered()

func _on_close_requested() -> void:
	get_tree().quit()
