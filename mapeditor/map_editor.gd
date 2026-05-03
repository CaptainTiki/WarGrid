extends Node3D
class_name MapEditor

const BrushPreviewScene := preload("res://mapeditor/brushes/brush_preview.tscn")
const TerrainDockScene := preload("res://mapeditor/docks/terrain_dock.tscn")
const EntityPlacementDockScene := preload("res://mapeditor/docks/entity_placement_dock.tscn")
const ResourcePlacementDockScene := preload("res://mapeditor/docks/resource_placement_dock.tscn")
const EditorPlaceholderDockScene := preload("res://mapeditor/docks/editor_placeholder_dock.tscn")
const EntityPlacementDockScript := preload("res://mapeditor/docks/entity_placement_dock.gd")
const EntityCatalogScript := preload("res://game/entities/catalog/entity_catalog.gd")
const EntityPlacementControllerScript := preload("res://mapeditor/entities/entity_placement_controller.gd")
const EntitySelectToolScript := preload("res://mapeditor/tools/entity/entity_select_tool.gd")
const EntityPlaceToolScript := preload("res://mapeditor/tools/entity/entity_place_tool.gd")
const EntityMoveToolScript := preload("res://mapeditor/tools/entity/entity_move_tool.gd")
const EntityRotateToolScript := preload("res://mapeditor/tools/entity/entity_rotate_tool.gd")
const EntityDeleteToolScript := preload("res://mapeditor/tools/entity/entity_delete_tool.gd")
const EditorGridOverlayScript := preload("res://mapeditor/overlays/editor_grid_overlay.gd")
const EditorPlacementOverlayScript := preload("res://mapeditor/overlays/editor_placement_overlay.gd")

const MODE_TERRAIN := &"terrain"
const MODE_ENTITIES := &"entities"
const MODE_RESOURCES := &"resources"
const MODE_REGIONS := &"regions"
const MODE_TRIGGERS := &"triggers"
const MODE_DEBUG := &"debug"

@onready var terrain: Terrain = $Terrain
@onready var camera_rig: EditorCameraRig = $EditorCameraRig
@onready var menu_bar = %EditorMenuBar
@onready var tool_dock_container: Control = %ToolDockContainer
@onready var overwrite_map_dialog: ConfirmationDialog = %OverwriteMapDialog
@onready var preferences_dialog: AcceptDialog = %PreferencesDialog

var camera: Camera3D
var brush_preview: BrushPreview
var terrain_dock: EditorToolDock
var entity_dock = null
var resource_dock = null
var entity_placement_controller = null
var editor_grid_overlay: Node
var editor_placement_overlay: Node

var _tools := {}
var _entity_tools := {}
var _entity_catalog := EntityCatalogScript.new()
var _resource_entity_ids: Array[StringName] = []
var _map_io: EditorMapIO
var _last_pick_point: Variant = null
var _painting := false
var _lowering := false
var _active_tool := EditorToolDock.TOOL_HEIGHT
var _active_mode := MODE_TERRAIN
var _entity_tool_mode := EntityPlacementDockScript.EntityToolMode.SELECT
var _active_entity_editor_tool = null
var _show_grid_overlay := false
var _show_placement_overlay := false

func _ready() -> void:
	_setup_tools()
	_setup_entity_tools()
	_map_io = EditorMapIO.new()
	_map_io.setup(terrain, camera_rig, menu_bar, overwrite_map_dialog)
	_setup_entity_placement_controller()
	_setup_editor_grid_overlay()
	_setup_editor_placement_overlay()
	_ensure_light()
	camera_rig.frame_point(terrain.get_center_position())
	camera = camera_rig.get_camera()
	_wire_menu_signals()
	_show_terrain_mode()
	brush_preview = BrushPreviewScene.instantiate() as BrushPreview
	terrain.add_child(brush_preview)
	brush_preview.hide_preview()
	entity_placement_controller.rebuild_placement_previews()

func _process(delta: float) -> void:
	_update_editor_grid_overlay()
	_update_editor_placement_overlay()
	if _active_mode == MODE_TERRAIN:
		_update_brush()
		_apply_active_brush()
		return

	if brush_preview != null:
		brush_preview.hide_preview()
	if _is_entity_placement_mode_active() and _active_entity_editor_tool != null:
		_active_entity_editor_tool.update_preview(self, delta)
	else:
		entity_hide_ghost()

func _unhandled_input(event: InputEvent) -> void:
	if _is_entity_placement_mode_active() and _active_entity_editor_tool != null:
		if _active_entity_editor_tool.handle_input(self, event):
			get_viewport().set_input_as_handled()
			return

	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			if Input.is_key_pressed(KEY_ALT) and _active_mode == MODE_TERRAIN:
				_set_brush_radius(_get_active_brush_data().radius + 1.0)
			else:
				camera_rig.move_vertical(1.0)
			get_viewport().set_input_as_handled()
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			if Input.is_key_pressed(KEY_ALT) and _active_mode == MODE_TERRAIN:
				_set_brush_radius(_get_active_brush_data().radius - 1.0)
			else:
				camera_rig.move_vertical(-1.0)
			get_viewport().set_input_as_handled()
		elif event.button_index == MOUSE_BUTTON_LEFT:
			if _active_mode == MODE_TERRAIN:
				_update_brush()
				_begin_brush_stroke(Input.is_key_pressed(KEY_SHIFT))
				get_viewport().set_input_as_handled()
	elif event is InputEventMouseButton and not event.pressed:
		if event.button_index == MOUSE_BUTTON_LEFT and _active_mode == MODE_TERRAIN:
			_end_brush_stroke()
			get_viewport().set_input_as_handled()

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

func entity_create_placement(local_position: Vector3) -> void:
	entity_placement_controller.create_placement(local_position)

func entity_select_nearest_placement(local_position: Vector3) -> void:
	entity_placement_controller.select_nearest_placement(local_position)

func entity_move_selected_placement(local_position: Vector3) -> void:
	entity_placement_controller.move_selected_placement(local_position)

func entity_rotate_selected_placement(delta_radians: float) -> void:
	entity_placement_controller.rotate_selected_placement(delta_radians)

func entity_delete_nearest_placement(local_position: Vector3) -> void:
	entity_placement_controller.delete_nearest_placement(local_position)

func entity_delete_selected_or_last_placement() -> void:
	entity_placement_controller.delete_selected_or_last_placement()

func entity_update_ghost() -> void:
	entity_placement_controller.update_ghost(camera, get_viewport().get_mouse_position())

func entity_hide_ghost() -> void:
	entity_placement_controller.hide_ghost()

func entity_clear_ghost() -> void:
	entity_placement_controller.clear_ghost()

func entity_get_settings() -> Dictionary:
	return entity_placement_controller.get_entity_settings()

func entity_get_selected_placement_index() -> int:
	return entity_placement_controller.get_selected_placement_index()

func entity_get_last_placement_validation() -> Variant:
	return entity_placement_controller.get_last_validation_result()

func entity_has_selected_placement() -> bool:
	return entity_placement_controller.has_selected_placement()

func entity_set_validation_feedback(is_valid: bool, reason: String) -> void:
	var dock := _get_active_placement_dock()
	if dock != null and dock.has_method("set_validation_feedback"):
		dock.set_validation_feedback(is_valid, reason)

func _show_terrain_mode() -> void:
	_deactivate_active_entity_tool()
	_set_active_mode(MODE_TERRAIN)
	entity_placement_controller.clear_placement_filter()
	entity_hide_ghost()
	_show_tool_dock(TerrainDockScene)
	terrain_dock = tool_dock_container.get_child(0) as EditorToolDock
	_wire_terrain_dock_signals(terrain_dock)
	_sync_ui_to_tools()

func _show_entities_mode() -> void:
	_end_brush_stroke()
	_set_active_mode(MODE_ENTITIES)
	entity_placement_controller.clear_placement_filter()
	terrain.set_overlay_enabled(false)
	if brush_preview != null:
		brush_preview.hide_preview()
	_show_tool_dock(EntityPlacementDockScene)
	entity_dock = tool_dock_container.get_child(0)
	_wire_entity_dock_signals(entity_dock)
	entity_set_validation_feedback(true, "Valid")
	entity_placement_controller.set_entity_settings(entity_dock.get_settings())
	_set_entity_tool_mode(_entity_tool_mode)
	entity_placement_controller.set_entity_settings(entity_dock.get_settings())
	_update_placement_dock_count()
	_sync_placement_dock_to_selection()

func _show_resources_mode() -> void:
	_end_brush_stroke()
	_set_active_mode(MODE_RESOURCES)
	terrain.set_overlay_enabled(false)
	if brush_preview != null:
		brush_preview.hide_preview()
	_resource_entity_ids = _get_resource_entity_ids()
	entity_placement_controller.set_placement_filter_entity_ids(_resource_entity_ids)
	if not _is_selected_placement_resource():
		entity_placement_controller.reset_selection()
		entity_placement_controller.rebuild_placement_previews()
	_show_tool_dock(ResourcePlacementDockScene)
	resource_dock = tool_dock_container.get_child(0)
	if resource_dock.has_method("set_available_resources"):
		resource_dock.set_available_resources(_entity_catalog.get_resource_entity_entries())
	_wire_resource_dock_signals(resource_dock)
	entity_set_validation_feedback(true, "Valid")
	entity_placement_controller.set_entity_settings(resource_dock.get_settings())
	_set_entity_tool_mode(_entity_tool_mode)
	entity_placement_controller.set_entity_settings(resource_dock.get_settings())
	_update_placement_dock_count()
	_sync_placement_dock_to_selection()

func _show_regions_mode() -> void:
	_show_placeholder_mode(MODE_REGIONS, "Regions")

func _show_triggers_mode() -> void:
	_show_placeholder_mode(MODE_TRIGGERS, "Triggers")

func _show_debug_mode() -> void:
	_show_placeholder_mode(MODE_DEBUG, "Debug")

func _show_placeholder_mode(mode: StringName, mode_title: String) -> void:
	_end_brush_stroke()
	_deactivate_active_entity_tool()
	_set_active_mode(mode)
	entity_placement_controller.clear_placement_filter()
	terrain.set_overlay_enabled(false)
	if brush_preview != null:
		brush_preview.hide_preview()
	entity_hide_ghost()
	_show_placeholder_dock(mode_title)

func _set_active_mode(mode: StringName) -> void:
	_active_mode = mode
	menu_bar.set_active_tool_mode(mode)

func _show_tool_dock(dock_scene: PackedScene) -> void:
	for child in tool_dock_container.get_children():
		child.free()
	terrain_dock = null
	entity_dock = null
	resource_dock = null
	var dock := dock_scene.instantiate() as Control
	tool_dock_container.add_child(dock)
	dock.set_anchors_preset(Control.PRESET_FULL_RECT)
	dock.offset_left = 0.0
	dock.offset_top = 0.0
	dock.offset_right = 0.0
	dock.offset_bottom = 0.0

func _show_placeholder_dock(mode_title: String) -> void:
	_show_tool_dock(EditorPlaceholderDockScene)
	var dock = tool_dock_container.get_child(0)
	if dock != null and dock.has_method("set_mode_label"):
		dock.set_mode_label(mode_title)

func _set_entity_tool_mode(mode: int) -> void:
	var clamped := clampi(
		mode,
		EntityPlacementDockScript.EntityToolMode.SELECT,
		EntityPlacementDockScript.EntityToolMode.DELETE
	)

	if _entity_tool_mode == clamped and _active_entity_editor_tool != null:
		var current_dock := _get_active_placement_dock()
		if current_dock != null and current_dock.has_method("set_tool_mode"):
			current_dock.set_tool_mode(_entity_tool_mode)
		return

	if _active_entity_editor_tool != null:
		_active_entity_editor_tool.deactivate(self)

	_entity_tool_mode = clamped
	_active_entity_editor_tool = _entity_tools.get(_entity_tool_mode)

	var dock := _get_active_placement_dock()
	if dock != null and dock.has_method("set_tool_mode"):
		dock.set_tool_mode(_entity_tool_mode)

	if _active_entity_editor_tool != null:
		_active_entity_editor_tool.activate(self)

	print("Entity tool mode: %s" % _get_entity_tool_mode_name(_entity_tool_mode))

func _deactivate_active_entity_tool() -> void:
	if _active_entity_editor_tool == null:
		return
	_active_entity_editor_tool.deactivate(self)
	_active_entity_editor_tool = null

func _on_tool_selected(tool_id: int) -> void:
	_end_brush_stroke()
	_active_tool = tool_id
	if terrain_dock != null:
		terrain_dock.set_active_tool(_active_tool)
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
	if terrain_dock != null:
		terrain_dock.set_brush_strength(clamped)

func _on_brush_falloff_changed(falloff: float) -> void:
	var clamped := clampf(falloff, 0.25, 4.0)
	for tool in _tools.values():
		(tool as EditorBrushTool).brush_data.falloff = clamped
	if terrain_dock != null:
		terrain_dock.set_brush_falloff(clamped)

func _on_material_channel_changed(channel: int) -> void:
	var tool := _tools.get(EditorToolDock.TOOL_PAINT_MATERIAL) as MaterialPaintBrushTool
	if tool == null: return
	tool.selected_material_channel = clampi(channel, 0, 3)
	if terrain_dock != null:
		terrain_dock.set_material_channel(tool.selected_material_channel)

func _on_walkable_value_changed(value: int) -> void:
	var tool := _tools.get(EditorToolDock.TOOL_WALKABLE_PAINT) as WalkablePaintBrushTool
	if tool == null: return
	tool.selected_walkable_value = clampi(value, TerrainMapData.Walkable.ALL, TerrainMapData.Walkable.NONE)
	if terrain_dock != null:
		terrain_dock.set_walkable_value(tool.selected_walkable_value)

func _on_buildable_value_changed(value: int) -> void:
	var tool := _tools.get(EditorToolDock.TOOL_BUILDABLE_PAINT) as BuildablePaintBrushTool
	if tool == null: return
	tool.selected_buildable_value = clampi(value, TerrainMapData.Buildable.OPEN, TerrainMapData.Buildable.BLOCKED)
	if terrain_dock != null:
		terrain_dock.set_buildable_value(tool.selected_buildable_value)

func _on_fow_height_changed(height: int) -> void:
	var tool := _tools.get(EditorToolDock.TOOL_FOW_HEIGHT_PAINT) as FowHeightPaintBrushTool
	if tool == null: return
	tool.selected_fow_height = clampi(height, 0, 3)
	if terrain_dock != null:
		terrain_dock.set_fow_height(tool.selected_fow_height)

func _on_overlay_enabled_changed(enabled: bool) -> void:
	terrain.set_overlay_enabled(enabled)
	if terrain_dock != null:
		terrain_dock.set_overlay_enabled(enabled)

func _on_overlay_mode_changed(mode: int) -> void:
	terrain.set_overlay_mode(mode)
	if terrain_dock != null:
		terrain_dock.set_overlay_mode(mode)

func _on_entity_placement_mode_changed(enabled: bool) -> void:
	print("Entity placement mode active." if enabled else "Entity placement mode inactive.")

func _on_entity_tool_mode_changed(mode: int) -> void:
	_set_entity_tool_mode(mode)

func _on_entity_settings_changed(settings: Dictionary) -> void:
	var requested_tool_mode: int = settings.get("tool_mode", _entity_tool_mode)
	if requested_tool_mode != _entity_tool_mode:
		_set_entity_tool_mode(requested_tool_mode)
	if _entity_tool_mode == EntityPlacementDockScript.EntityToolMode.PLACE:
		entity_clear_ghost()
	var apply_to_selected: bool = (
		_entity_tool_mode != EntityPlacementDockScript.EntityToolMode.PLACE
		and entity_placement_controller.has_selected_placement()
	)
	entity_placement_controller.set_entity_settings(settings, apply_to_selected)

func _get_entity_tool_mode_name(mode: int) -> String:
	match mode:
		EntityPlacementDockScript.EntityToolMode.SELECT:
			return "Select"
		EntityPlacementDockScript.EntityToolMode.PLACE:
			return "Place"
		EntityPlacementDockScript.EntityToolMode.MOVE:
			return "Move"
		EntityPlacementDockScript.EntityToolMode.ROTATE:
			return "Rotate"
		EntityPlacementDockScript.EntityToolMode.DELETE:
			return "Delete"
	return "Unknown"

func _sync_entity_dock_to_selection() -> void:
	_sync_placement_dock_to_selection()

func _sync_placement_dock_to_selection() -> void:
	var dock := _get_active_placement_dock()
	if dock == null or terrain.map_data == null or entity_placement_controller == null:
		return
	_update_placement_dock_count()
	var placement = entity_placement_controller.get_selected_placement()
	if placement == null:
		return
	if _active_mode == MODE_RESOURCES and not _resource_entity_ids.has(placement.entity_id):
		return
	if dock.has_method("set_from_placement"):
		dock.set_from_placement(placement)
	if dock.has_method("get_settings"):
		entity_placement_controller.set_entity_settings(dock.get_settings(), false)

func _update_entity_dock_count() -> void:
	_update_placement_dock_count()

func _update_placement_dock_count() -> void:
	var dock := _get_active_placement_dock()
	if dock == null or entity_placement_controller == null:
		return
	var count: int = entity_placement_controller.get_filtered_placement_count() if _active_mode == MODE_RESOURCES else entity_placement_controller.get_placement_count()
	if dock.has_method("set_placement_count"):
		dock.set_placement_count(count)

func _on_save_map() -> void:
	_end_brush_stroke()
	_map_io.save()

func _on_load_map() -> void:
	_end_brush_stroke()
	_map_io.load()

func _on_map_reloaded() -> void:
	entity_placement_controller.reset_selection()
	entity_placement_controller.rebuild_placement_previews()

func _on_new_map_requested(playable_chunks: Vector2i) -> void:
	_end_brush_stroke()
	_map_io.request_new(playable_chunks)

func _on_map_created() -> void:
	entity_placement_controller.reset_selection()
	entity_placement_controller.rebuild_placement_previews()

func _on_preferences_requested() -> void:
	preferences_dialog.popup_centered()

func _on_close_requested() -> void:
	get_tree().quit()

func _set_brush_radius(radius: float) -> void:
	var clamped := clampf(radius, 1.0, 32.0)
	for tool in _tools.values():
		(tool as EditorBrushTool).brush_data.radius = clamped
	if brush_preview != null:
		brush_preview.set_radius(clamped)
	if terrain_dock != null:
		terrain_dock.set_brush_radius(clamped)

func _get_active_brush_data() -> TerrainBrushData:
	var tool := _tools.get(_active_tool) as EditorBrushTool
	return tool.brush_data if tool != null else TerrainBrushData.new()

func _set_overlay(enabled: bool, mode: int) -> void:
	terrain.set_overlay_enabled(enabled)
	terrain.set_overlay_mode(mode)
	if terrain_dock != null:
		terrain_dock.set_overlay_enabled(enabled)
		terrain_dock.set_overlay_mode(mode)

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

func _setup_entity_tools() -> void:
	var pairs := [
		[EntityPlacementDockScript.EntityToolMode.SELECT, EntitySelectToolScript.new()],
		[EntityPlacementDockScript.EntityToolMode.PLACE, EntityPlaceToolScript.new()],
		[EntityPlacementDockScript.EntityToolMode.MOVE, EntityMoveToolScript.new()],
		[EntityPlacementDockScript.EntityToolMode.ROTATE, EntityRotateToolScript.new()],
		[EntityPlacementDockScript.EntityToolMode.DELETE, EntityDeleteToolScript.new()],
	]
	for pair in pairs:
		var tool = pair[1]
		add_child(tool)
		_entity_tools[pair[0]] = tool

func _setup_entity_placement_controller() -> void:
	entity_placement_controller = EntityPlacementControllerScript.new()
	entity_placement_controller.name = "EntityPlacementController"
	add_child(entity_placement_controller)
	entity_placement_controller.setup(terrain)
	entity_placement_controller.placements_changed.connect(_on_entity_placements_changed)
	entity_placement_controller.selection_changed.connect(_on_entity_selection_changed)
	entity_placement_controller.placement_count_changed.connect(_on_entity_placement_count_changed)
	entity_placement_controller.placement_validation_changed.connect(_on_entity_placement_validation_changed)

func _sync_ui_to_tools() -> void:
	if terrain_dock == null:
		return
	var height_tool := _tools.get(EditorToolDock.TOOL_HEIGHT) as EditorBrushTool
	terrain_dock.set_active_tool(_active_tool)
	terrain_dock.set_brush_radius(height_tool.brush_data.radius)
	terrain_dock.set_brush_strength(height_tool.brush_data.strength)
	terrain_dock.set_brush_falloff(height_tool.brush_data.falloff)
	terrain_dock.set_material_channel((_tools.get(EditorToolDock.TOOL_PAINT_MATERIAL) as MaterialPaintBrushTool).selected_material_channel)
	terrain_dock.set_walkable_value((_tools.get(EditorToolDock.TOOL_WALKABLE_PAINT) as WalkablePaintBrushTool).selected_walkable_value)
	terrain_dock.set_buildable_value((_tools.get(EditorToolDock.TOOL_BUILDABLE_PAINT) as BuildablePaintBrushTool).selected_buildable_value)
	terrain_dock.set_fow_height((_tools.get(EditorToolDock.TOOL_FOW_HEIGHT_PAINT) as FowHeightPaintBrushTool).selected_fow_height)
	terrain_dock.set_overlay_enabled(false)
	terrain_dock.set_overlay_mode(TerrainMapData.OverlayMode.NONE)
	menu_bar.set_current_playable_chunks(terrain.playable_chunks)

func _wire_menu_signals() -> void:
	menu_bar.new_map_requested.connect(_on_new_map_requested)
	menu_bar.save_map_requested.connect(_on_save_map)
	menu_bar.load_map_requested.connect(_on_load_map)
	menu_bar.preferences_requested.connect(_on_preferences_requested)
	menu_bar.close_requested.connect(_on_close_requested)
	menu_bar.grid_visibility_changed.connect(_on_grid_visibility_changed)
	menu_bar.placement_overlay_visibility_changed.connect(_on_placement_overlay_visibility_changed)
	menu_bar.terrain_tool_requested.connect(_show_terrain_mode)
	menu_bar.entities_tool_requested.connect(_show_entities_mode)
	menu_bar.resources_tool_requested.connect(_show_resources_mode)
	menu_bar.regions_tool_requested.connect(_show_regions_mode)
	menu_bar.triggers_tool_requested.connect(_show_triggers_mode)
	menu_bar.debug_tool_requested.connect(_show_debug_mode)
	_map_io.map_reloaded.connect(_on_map_reloaded)
	_map_io.map_created.connect(_on_map_created)

func _wire_terrain_dock_signals(dock: EditorToolDock) -> void:
	dock.tool_selected.connect(_on_tool_selected)
	dock.brush_radius_changed.connect(_on_brush_radius_changed)
	dock.brush_strength_changed.connect(_on_brush_strength_changed)
	dock.brush_falloff_changed.connect(_on_brush_falloff_changed)
	dock.material_channel_changed.connect(_on_material_channel_changed)
	dock.walkable_value_changed.connect(_on_walkable_value_changed)
	dock.buildable_value_changed.connect(_on_buildable_value_changed)
	dock.fow_height_changed.connect(_on_fow_height_changed)
	dock.overlay_enabled_changed.connect(_on_overlay_enabled_changed)
	dock.overlay_mode_changed.connect(_on_overlay_mode_changed)

func _wire_entity_dock_signals(dock) -> void:
	dock.placement_mode_changed.connect(_on_entity_placement_mode_changed)
	dock.tool_mode_changed.connect(_on_entity_tool_mode_changed)
	dock.placement_settings_changed.connect(_on_entity_settings_changed)
	dock.delete_selected_requested.connect(entity_delete_selected_or_last_placement)
	dock.delete_last_requested.connect(_delete_last_placement)

func _wire_resource_dock_signals(dock) -> void:
	dock.tool_mode_changed.connect(_on_entity_tool_mode_changed)
	dock.placement_settings_changed.connect(_on_entity_settings_changed)
	dock.delete_selected_requested.connect(entity_delete_selected_or_last_placement)
	dock.delete_last_requested.connect(_delete_last_placement)

func _setup_editor_grid_overlay() -> void:
	editor_grid_overlay = EditorGridOverlayScript.new()
	editor_grid_overlay.name = "EditorGridOverlay"
	terrain.add_child(editor_grid_overlay)
	editor_grid_overlay.setup(terrain)
	editor_grid_overlay.set_enabled(false)

func _setup_editor_placement_overlay() -> void:
	editor_placement_overlay = EditorPlacementOverlayScript.new()
	editor_placement_overlay.name = "EditorPlacementOverlay"
	terrain.add_child(editor_placement_overlay)
	editor_placement_overlay.setup(terrain, entity_placement_controller)
	editor_placement_overlay.set_enabled(false)

func _delete_last_placement() -> void:
	entity_placement_controller.delete_last_placement()

func _on_entity_placements_changed() -> void:
	_map_io.mark_dirty()
	_update_placement_dock_count()
	_sync_placement_dock_to_selection()

func _on_entity_selection_changed() -> void:
	_sync_placement_dock_to_selection()

func _on_entity_placement_count_changed(count: int) -> void:
	_update_placement_dock_count()

func _on_entity_placement_validation_changed(is_valid: bool, reason: String) -> void:
	entity_set_validation_feedback(is_valid, reason)

func _on_grid_visibility_changed(is_visible: bool) -> void:
	_show_grid_overlay = is_visible
	if editor_grid_overlay != null:
		editor_grid_overlay.set_enabled(is_visible)

func _on_placement_overlay_visibility_changed(is_visible: bool) -> void:
	_show_placement_overlay = is_visible
	if editor_placement_overlay != null:
		editor_placement_overlay.set_enabled(is_visible)

func _update_editor_grid_overlay() -> void:
	if not _show_grid_overlay or editor_grid_overlay == null:
		if editor_grid_overlay != null:
			editor_grid_overlay.hide_grid()
		return
	if terrain == null or terrain.map_data == null or camera == null:
		editor_grid_overlay.hide_grid()
		return
	var pick_point = terrain.get_pick_point(camera, get_viewport().get_mouse_position())
	if pick_point == null:
		editor_grid_overlay.hide_grid()
		return
	var local_position: Vector3 = pick_point
	if not terrain.map_data.is_local_position_in_playable_area(local_position):
		editor_grid_overlay.hide_grid()
		return
	editor_grid_overlay.set_hover_position(local_position)

func _update_editor_placement_overlay() -> void:
	if not _show_placement_overlay or editor_placement_overlay == null:
		if editor_placement_overlay != null:
			editor_placement_overlay.hide_overlay()
		return
	if not _is_entity_placement_mode_active():
		editor_placement_overlay.hide_overlay()
		return
	if _entity_tool_mode != EntityPlacementDockScript.EntityToolMode.PLACE and _entity_tool_mode != EntityPlacementDockScript.EntityToolMode.MOVE:
		editor_placement_overlay.hide_overlay()
		return
	if terrain == null or terrain.map_data == null or camera == null:
		editor_placement_overlay.hide_overlay()
		return
	var pick_point = terrain.get_pick_point(camera, get_viewport().get_mouse_position())
	if pick_point == null:
		editor_placement_overlay.hide_overlay()
		return
	var picked_position: Vector3 = pick_point
	if not terrain.map_data.is_local_position_in_playable_area(picked_position):
		editor_placement_overlay.hide_overlay()
		return

	var entity_id := &""
	var rotation_y := 0.0
	var ignored_index := -1
	if _entity_tool_mode == EntityPlacementDockScript.EntityToolMode.MOVE:
		var placement = entity_placement_controller.get_selected_placement()
		if placement == null:
			editor_placement_overlay.hide_overlay()
			return
		entity_id = placement.entity_id
		rotation_y = placement.rotation_y
		ignored_index = entity_placement_controller.get_selected_placement_index()
	else:
		var settings: Dictionary = entity_placement_controller.get_entity_settings()
		entity_id = settings.get("entity_id", &"")
		rotation_y = settings.get("rotation_y", 0.0)
	if entity_id == &"":
		editor_placement_overlay.hide_overlay()
		return
	editor_placement_overlay.set_hover_entity(entity_id, picked_position, rotation_y, ignored_index)

func _get_active_placement_dock() -> Node:
	if _active_mode == MODE_RESOURCES:
		return resource_dock
	if _active_mode == MODE_ENTITIES:
		return entity_dock
	return null

func _is_entity_placement_mode_active() -> bool:
	return _active_mode == MODE_ENTITIES or _active_mode == MODE_RESOURCES

func _get_resource_entity_ids() -> Array[StringName]:
	var ids: Array[StringName] = []
	for entry in _entity_catalog.get_resource_entity_entries():
		var data := entry as Dictionary
		var entity_id := StringName(str(data.get("entity_id", &"")))
		if entity_id != &"":
			ids.append(entity_id)
	return ids

func _is_selected_placement_resource() -> bool:
	var placement = entity_placement_controller.get_selected_placement()
	return placement != null and _resource_entity_ids.has(placement.entity_id)

func _ensure_light() -> void:
	if has_node("Sun"):
		return
	var sun := DirectionalLight3D.new()
	sun.name = "Sun"
	sun.rotation_degrees = Vector3(-55.0, -35.0, 0.0)
	add_child(sun)
