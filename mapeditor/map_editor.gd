extends Node3D
class_name MapEditor

const BrushPreviewScene := preload("res://mapeditor/brushes/brush_preview.tscn")

@onready var terrain: Terrain = $Terrain
@onready var camera_rig: EditorCameraRig = $EditorCameraRig
@onready var menu_bar = $CanvasLayer/EditorMenuBar
@onready var tool_dock: EditorToolDock = $CanvasLayer/EditorToolDock
@onready var overwrite_map_dialog: ConfirmationDialog = $CanvasLayer/OverwriteMapDialog
@onready var preferences_dialog: AcceptDialog = $CanvasLayer/PreferencesDialog

var camera: Camera3D
var brush_preview: BrushPreview

var _tools := {}          # tool_id → EditorBrushTool
var _map_io: EditorMapIO
var _last_pick_point: Variant = null
var _painting := false
var _lowering := false
var _active_tool := EditorToolDock.TOOL_HEIGHT

func _ready() -> void:
	_setup_tools()
	_map_io = EditorMapIO.new()
	_map_io.setup(terrain, camera_rig, menu_bar, overwrite_map_dialog)
	_ensure_light()
	camera_rig.frame_point(terrain.get_center_position())
	camera = camera_rig.get_camera()
	_wire_signals()
	_sync_ui_to_tools()
	brush_preview = BrushPreviewScene.instantiate() as BrushPreview
	terrain.add_child(brush_preview)
	brush_preview.hide_preview()

func _process(_delta: float) -> void:
	_update_brush()
	_apply_active_brush()

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			if Input.is_key_pressed(KEY_ALT):
				_set_brush_radius(_get_active_brush_data().radius + 1.0)
			else:
				camera_rig.move_vertical(1.0)
			get_viewport().set_input_as_handled()
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			if Input.is_key_pressed(KEY_ALT):
				_set_brush_radius(_get_active_brush_data().radius - 1.0)
			else:
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

# ── Brush stroke ──────────────────────────────────────────────────────────────

func _update_brush() -> void:
	_last_pick_point = terrain.get_pick_point(camera, get_viewport().get_mouse_position(), _painting)
	if _last_pick_point == null:
		brush_preview.hide_preview()
		return
	brush_preview.set_radius(_get_active_brush_data().radius)
	brush_preview.show_at(_last_pick_point)

func _apply_active_brush() -> void:
	if _last_pick_point == null or not _painting:
		return
	var tool := _tools.get(_active_tool) as EditorBrushTool
	if tool != null:
		tool.apply_stroke_sample(terrain, _last_pick_point, _lowering)

func _begin_brush_stroke(lowering: bool) -> void:
	if _last_pick_point == null:
		return
	_painting = true
	_lowering = lowering
	var tool := _tools.get(_active_tool) as EditorBrushTool
	if tool != null:
		tool.begin_stroke(terrain, _last_pick_point, lowering)

func _end_brush_stroke() -> void:
	if not _painting:
		return
	_painting = false
	var tool := _tools.get(_active_tool) as EditorBrushTool
	if tool != null:
		tool.end_stroke(terrain)
	_map_io.mark_dirty()

# ── Tool & brush param handlers ───────────────────────────────────────────────

func _on_tool_selected(tool_id: int) -> void:
	_end_brush_stroke()
	_active_tool = tool_id
	tool_dock.set_active_tool(_active_tool)
	match _active_tool:
		EditorToolDock.TOOL_WALKABLE_PAINT:
			_set_overlay(true, TerrainMapData.OverlayMode.WALKABLE)
		EditorToolDock.TOOL_BUILDABLE_PAINT:
			_set_overlay(true, TerrainMapData.OverlayMode.BUILDABLE)
		EditorToolDock.TOOL_FOW_HEIGHT_PAINT:
			_set_overlay(true, TerrainMapData.OverlayMode.FOW_HEIGHT)

func _on_brush_radius_changed(radius: float) -> void:
	_set_brush_radius(radius)

func _on_brush_strength_changed(strength: float) -> void:
	var clamped := clampf(strength, 0.1, 16.0)
	for tool in _tools.values():
		(tool as EditorBrushTool).brush_data.strength = clamped
	tool_dock.set_brush_strength(clamped)

func _on_brush_falloff_changed(falloff: float) -> void:
	var clamped := clampf(falloff, 0.25, 4.0)
	for tool in _tools.values():
		(tool as EditorBrushTool).brush_data.falloff = clamped
	tool_dock.set_brush_falloff(clamped)

func _on_material_channel_changed(channel: int) -> void:
	var tool := _tools.get(EditorToolDock.TOOL_PAINT_MATERIAL) as MaterialPaintBrushTool
	if tool == null: return
	tool.selected_material_channel = clampi(channel, 0, 3)
	tool_dock.set_material_channel(tool.selected_material_channel)

func _on_walkable_value_changed(value: int) -> void:
	var tool := _tools.get(EditorToolDock.TOOL_WALKABLE_PAINT) as WalkablePaintBrushTool
	if tool == null: return
	tool.selected_walkable_value = clampi(value, TerrainMapData.Walkable.ALL, TerrainMapData.Walkable.NONE)
	tool_dock.set_walkable_value(tool.selected_walkable_value)

func _on_buildable_value_changed(value: int) -> void:
	var tool := _tools.get(EditorToolDock.TOOL_BUILDABLE_PAINT) as BuildablePaintBrushTool
	if tool == null: return
	tool.selected_buildable_value = clampi(value, TerrainMapData.Buildable.OPEN, TerrainMapData.Buildable.BLOCKED)
	tool_dock.set_buildable_value(tool.selected_buildable_value)

func _on_fow_height_changed(height: int) -> void:
	var tool := _tools.get(EditorToolDock.TOOL_FOW_HEIGHT_PAINT) as FowHeightPaintBrushTool
	if tool == null: return
	tool.selected_fow_height = clampi(height, 0, 3)
	tool_dock.set_fow_height(tool.selected_fow_height)

func _on_overlay_enabled_changed(enabled: bool) -> void:
	terrain.set_overlay_enabled(enabled)
	tool_dock.set_overlay_enabled(enabled)

func _on_overlay_mode_changed(mode: int) -> void:
	terrain.set_overlay_mode(mode)
	tool_dock.set_overlay_mode(mode)

func _on_save_map() -> void:
	_end_brush_stroke()
	_map_io.save()

func _on_load_map() -> void:
	_end_brush_stroke()
	_map_io.load()

func _on_new_map_requested(playable_chunks: Vector2i) -> void:
	_end_brush_stroke()
	_map_io.request_new(playable_chunks)

func _on_preferences_requested() -> void:
	preferences_dialog.popup_centered()

func _on_close_requested() -> void:
	get_tree().quit()

# ── Helpers ───────────────────────────────────────────────────────────────────

func _set_brush_radius(radius: float) -> void:
	var clamped := clampf(radius, 1.0, 32.0)
	for tool in _tools.values():
		(tool as EditorBrushTool).brush_data.radius = clamped
	brush_preview.set_radius(clamped)
	tool_dock.set_brush_radius(clamped)

func _get_active_brush_data() -> TerrainBrushData:
	var tool := _tools.get(_active_tool) as EditorBrushTool
	return tool.brush_data if tool != null else TerrainBrushData.new()

func _set_overlay(enabled: bool, mode: int) -> void:
	terrain.set_overlay_enabled(enabled)
	terrain.set_overlay_mode(mode)
	tool_dock.set_overlay_enabled(enabled)
	tool_dock.set_overlay_mode(mode)

func _setup_tools() -> void:
	var pairs := [
		[EditorToolDock.TOOL_HEIGHT,          HeightBrushTool.new()],
		[EditorToolDock.TOOL_SMOOTH,          SmoothBrushTool.new()],
		[EditorToolDock.TOOL_FLATTEN,         FlattenBrushTool.new()],
		[EditorToolDock.TOOL_PAINT_MATERIAL,  MaterialPaintBrushTool.new()],
		[EditorToolDock.TOOL_WALKABLE_PAINT,  WalkablePaintBrushTool.new()],
		[EditorToolDock.TOOL_BUILDABLE_PAINT, BuildablePaintBrushTool.new()],
		[EditorToolDock.TOOL_FOW_HEIGHT_PAINT,FowHeightPaintBrushTool.new()],
	]
	for pair in pairs:
		var tool: EditorBrushTool = pair[1]
		add_child(tool)
		_tools[pair[0]] = tool

func _sync_ui_to_tools() -> void:
	var height_tool := _tools.get(EditorToolDock.TOOL_HEIGHT) as EditorBrushTool
	tool_dock.set_active_tool(_active_tool)
	tool_dock.set_brush_radius(height_tool.brush_data.radius)
	tool_dock.set_brush_strength(height_tool.brush_data.strength)
	tool_dock.set_brush_falloff(height_tool.brush_data.falloff)
	tool_dock.set_material_channel((_tools.get(EditorToolDock.TOOL_PAINT_MATERIAL) as MaterialPaintBrushTool).selected_material_channel)
	tool_dock.set_walkable_value((_tools.get(EditorToolDock.TOOL_WALKABLE_PAINT) as WalkablePaintBrushTool).selected_walkable_value)
	tool_dock.set_buildable_value((_tools.get(EditorToolDock.TOOL_BUILDABLE_PAINT) as BuildablePaintBrushTool).selected_buildable_value)
	tool_dock.set_fow_height((_tools.get(EditorToolDock.TOOL_FOW_HEIGHT_PAINT) as FowHeightPaintBrushTool).selected_fow_height)
	tool_dock.set_overlay_enabled(false)
	tool_dock.set_overlay_mode(TerrainMapData.OverlayMode.NONE)
	menu_bar.set_current_playable_chunks(terrain.playable_chunks)

func _wire_signals() -> void:
	menu_bar.new_map_requested.connect(_on_new_map_requested)
	menu_bar.save_map_requested.connect(_on_save_map)
	menu_bar.load_map_requested.connect(_on_load_map)
	menu_bar.preferences_requested.connect(_on_preferences_requested)
	menu_bar.close_requested.connect(_on_close_requested)
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

func _ensure_light() -> void:
	if has_node("Sun"):
		return
	var sun := DirectionalLight3D.new()
	sun.name = "Sun"
	sun.rotation_degrees = Vector3(-55.0, -35.0, 0.0)
	add_child(sun)
