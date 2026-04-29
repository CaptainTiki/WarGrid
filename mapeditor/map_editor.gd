extends Node3D
class_name MapEditor

const BrushPreviewScene := preload("res://mapeditor/brushes/brush_preview.tscn")
const TerrainDockScene := preload("res://mapeditor/docks/terrain_dock.tscn")
const EntityPlacementDockScene := preload("res://mapeditor/docks/entity_placement_dock.tscn")
const EntityPlacementDockScript := preload("res://mapeditor/docks/entity_placement_dock.gd")
const EntityCatalogScript := preload("res://game/entities/catalog/entity_catalog.gd")
const EntityPlacementDataScript := preload("res://game/entities/placement/entity_placement_data.gd")

const MODE_TERRAIN := &"terrain"
const MODE_ENTITIES := &"entities"
const PLACEMENT_SELECT_RADIUS := 2.0

@onready var terrain: Terrain = $Terrain
@onready var camera_rig: EditorCameraRig = $EditorCameraRig
@onready var menu_bar = $CanvasLayer/EditorMenuBar
@onready var right_dock_container: Control = $CanvasLayer/RightDockContainer
@onready var overwrite_map_dialog: ConfirmationDialog = $CanvasLayer/OverwriteMapDialog
@onready var preferences_dialog: AcceptDialog = $CanvasLayer/PreferencesDialog

var camera: Camera3D
var brush_preview: BrushPreview
var terrain_dock: EditorToolDock
var entity_dock = null

var _tools := {}
var _map_io: EditorMapIO
var _last_pick_point: Variant = null
var _painting := false
var _lowering := false
var _active_tool := EditorToolDock.TOOL_HEIGHT
var _active_mode := MODE_TERRAIN
var _entity_catalog := EntityCatalogScript.new()
var _entity_settings := {}
var _entity_tool_mode := EntityPlacementDockScript.EntityToolMode.SELECT
var _placement_preview_root: Node3D
var _placement_preview_nodes: Array[Node3D] = []
var _placement_ghost_root: Node3D
var _ghost_entity_id: StringName = &""
var _ghost_team_id := -1
var _ghost_rotation_y := INF
var _selected_placement_index := -1

func _ready() -> void:
	_setup_tools()
	_map_io = EditorMapIO.new()
	_map_io.setup(terrain, camera_rig, menu_bar, overwrite_map_dialog)
	_ensure_light()
	_ensure_placement_preview_root()
	camera_rig.frame_point(terrain.get_center_position())
	camera = camera_rig.get_camera()
	_wire_menu_signals()
	_show_terrain_mode()
	brush_preview = BrushPreviewScene.instantiate() as BrushPreview
	terrain.add_child(brush_preview)
	brush_preview.hide_preview()
	_rebuild_placement_previews()

func _process(_delta: float) -> void:
	if _active_mode != MODE_TERRAIN:
		if brush_preview != null:
			brush_preview.hide_preview()
		_update_entity_ghost()
		return
	_update_brush()
	_apply_active_brush()

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_DELETE and _active_mode == MODE_ENTITIES:
			_delete_selected_or_last_placement()
			get_viewport().set_input_as_handled()
		elif _active_mode == MODE_ENTITIES and _entity_tool_mode == EntityPlacementDockScript.EntityToolMode.ROTATE:
			if event.keycode == KEY_Q:
				_rotate_selected_placement(-PI * 0.5)
				get_viewport().set_input_as_handled()
			elif event.keycode == KEY_E:
				_rotate_selected_placement(PI * 0.5)
				get_viewport().set_input_as_handled()
	elif event is InputEventMouseButton and event.pressed:
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
			elif _active_mode == MODE_ENTITIES:
				_handle_entity_mode_click()
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

func _handle_entity_mode_click() -> void:
	var pick_point = terrain.get_pick_point(camera, get_viewport().get_mouse_position())
	if pick_point == null:
		return
	var local_position: Vector3 = pick_point
	if not terrain.map_data.is_local_position_in_playable_area(local_position):
		return
	match _entity_tool_mode:
		EntityPlacementDockScript.EntityToolMode.SELECT:
			_select_nearest_placement(local_position)
		EntityPlacementDockScript.EntityToolMode.PLACE:
			_create_entity_placement(local_position)
		EntityPlacementDockScript.EntityToolMode.MOVE:
			_move_selected_placement(local_position)
		EntityPlacementDockScript.EntityToolMode.ROTATE:
			_rotate_selected_placement(PI * 0.5)
		EntityPlacementDockScript.EntityToolMode.DELETE:
			_delete_nearest_placement(local_position)

func _create_entity_placement(local_position: Vector3) -> void:
	if terrain.map_data == null:
		return
	var placement = EntityPlacementDataScript.new()
	placement.entity_id = _entity_settings.get("entity_id", &"infantry")
	placement.position = local_position
	placement.rotation_y = _entity_settings.get("rotation_y", 0.0)
	placement.team_id = _entity_settings.get("team_id", 1)
	placement.health_spawn_mode = _entity_settings.get("health_spawn_mode", EntityPlacementDataScript.HealthSpawnMode.FULL)
	placement.health_value = _entity_settings.get("health_value", 1.0)
	terrain.map_data.entity_placements.append(placement)
	_selected_placement_index = terrain.map_data.entity_placements.size() - 1
	_map_io.mark_dirty()
	_rebuild_placement_previews()
	_sync_entity_dock_to_selection()
	print("Placed %s at %s team %d." % [placement.entity_id, placement.position, placement.team_id])

func _select_nearest_placement(local_position: Vector3) -> void:
	_selected_placement_index = _find_nearest_placement_index(local_position)
	_rebuild_placement_previews()
	_sync_entity_dock_to_selection()
	if _selected_placement_index >= 0:
		var placement := terrain.map_data.entity_placements[_selected_placement_index] as EntityPlacementData
		if placement != null:
			print("Selected placement %s at %s." % [placement.entity_id, placement.position])

func _find_nearest_placement_index(local_position: Vector3) -> int:
	if terrain.map_data == null:
		return -1
	var best_index := -1
	var best_distance := PLACEMENT_SELECT_RADIUS
	for i in terrain.map_data.entity_placements.size():
		var placement := terrain.map_data.entity_placements[i] as EntityPlacementData
		if placement == null:
			continue
		var flat_distance := Vector2(local_position.x, local_position.z).distance_to(Vector2(placement.position.x, placement.position.z))
		if flat_distance <= best_distance:
			best_distance = flat_distance
			best_index = i
	return best_index

func _delete_selected_or_last_placement() -> void:
	if terrain.map_data == null or terrain.map_data.entity_placements.is_empty():
		return
	var index := _selected_placement_index
	if index < 0 or index >= terrain.map_data.entity_placements.size():
		index = terrain.map_data.entity_placements.size() - 1
	var placement := terrain.map_data.entity_placements[index] as EntityPlacementData
	var deleted_id := placement.entity_id if placement != null else &"unknown"
	terrain.map_data.entity_placements.remove_at(index)
	_selected_placement_index = -1
	_map_io.mark_dirty()
	_rebuild_placement_previews()
	_sync_entity_dock_to_selection()
	print("Deleted placement %s." % deleted_id)

func _delete_nearest_placement(local_position: Vector3) -> void:
	var index := _find_nearest_placement_index(local_position)
	if index < 0 or terrain.map_data == null:
		return
	var placement := terrain.map_data.entity_placements[index] as EntityPlacementData
	var deleted_id := placement.entity_id if placement != null else &"unknown"
	terrain.map_data.entity_placements.remove_at(index)
	if _selected_placement_index == index:
		_selected_placement_index = -1
	elif _selected_placement_index > index:
		_selected_placement_index -= 1
	_map_io.mark_dirty()
	_rebuild_placement_previews()
	_sync_entity_dock_to_selection()
	print("Deleted placement %s." % deleted_id)

func _move_selected_placement(local_position: Vector3) -> void:
	var placement := _get_selected_placement()
	if placement == null:
		return
	placement.position = local_position
	_map_io.mark_dirty()
	_rebuild_placement_previews()
	print("Moved selected placement to %s." % local_position)

func _rotate_selected_placement(delta_radians: float) -> void:
	var placement := _get_selected_placement()
	if placement == null:
		return
	placement.rotation_y = wrapf(placement.rotation_y + delta_radians, -PI, PI)
	if entity_dock != null:
		entity_dock.set_from_placement(placement)
	_entity_settings = entity_dock.get_settings() if entity_dock != null else _entity_settings
	_map_io.mark_dirty()
	_rebuild_placement_previews()
	print("Rotated selected placement to %.0f degrees." % rad_to_deg(placement.rotation_y))

func _get_selected_placement() -> EntityPlacementData:
	if terrain.map_data == null:
		return null
	if _selected_placement_index < 0 or _selected_placement_index >= terrain.map_data.entity_placements.size():
		return null
	return terrain.map_data.entity_placements[_selected_placement_index] as EntityPlacementData

func _rebuild_placement_previews() -> void:
	_ensure_placement_preview_root()
	for child in _placement_preview_root.get_children():
		child.queue_free()
	_placement_preview_nodes.clear()
	if terrain.map_data == null:
		_update_entity_dock_count()
		return
	for i in terrain.map_data.entity_placements.size():
		var placement := terrain.map_data.entity_placements[i] as EntityPlacementData
		if placement == null:
			continue
		var marker := _create_placement_marker(placement, i == _selected_placement_index)
		_placement_preview_root.add_child(marker)
		_placement_preview_nodes.append(marker)
	print("Loaded %d entity placements." % terrain.map_data.entity_placements.size())
	_update_entity_dock_count()

func _create_placement_marker(placement: EntityPlacementData, selected: bool) -> Node3D:
	var marker := Node3D.new()
	marker.name = "Placement_%s" % placement.entity_id
	marker.position = placement.position
	marker.rotation.y = placement.rotation_y

	var entity := _entity_catalog.spawn_entity(placement.entity_id)
	if entity != null and entity is Node3D:
		var entity_3d := entity as Node3D
		entity_3d.name = "Preview_%s" % placement.entity_id
		entity_3d.position = Vector3.ZERO
		if "team_id" in entity_3d:
			entity_3d.team_id = placement.team_id
		_prepare_entity_preview(entity_3d)
		marker.add_child(entity_3d)
	else:
		marker.add_child(_create_fallback_marker(placement))

	marker.add_child(_create_selection_ring(placement, selected))
	return marker

func _prepare_entity_preview(root_node: Node) -> void:
	root_node.process_mode = Node.PROCESS_MODE_DISABLED
	for child in root_node.get_children():
		_prepare_entity_preview(child)
	if root_node is CollisionObject3D:
		var collision_object := root_node as CollisionObject3D
		collision_object.collision_layer = 0
		collision_object.collision_mask = 0
	if root_node is EntityFootprintComponent:
		var footprint := root_node as EntityFootprintComponent
		footprint.blocks_units = false
		footprint.blocks_pathfinding = false
		footprint.participates_in_separation = false

func _create_fallback_marker(placement: EntityPlacementData) -> Node3D:
	var mesh_instance := MeshInstance3D.new()
	var mesh := CylinderMesh.new()
	mesh.top_radius = 0.4
	mesh.bottom_radius = 0.4
	mesh.height = 0.8
	mesh_instance.mesh = mesh
	mesh_instance.position.y = mesh.height * 0.5 + 0.08
	mesh_instance.material_override = _create_marker_material(placement.team_id, false)
	return mesh_instance

func _create_selection_ring(placement: EntityPlacementData, selected: bool) -> MeshInstance3D:
	var ring := MeshInstance3D.new()
	ring.name = "SelectionRing"
	var mesh := TorusMesh.new()
	mesh.inner_radius = 0.58 if selected else 0.45
	mesh.outer_radius = 0.68 if selected else 0.52
	ring.mesh = mesh
	ring.position.y = 0.06
	ring.material_override = _create_marker_material(placement.team_id, selected)
	return ring

func _create_marker_material(team_id: int, selected: bool) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	match team_id:
		1:
			material.albedo_color = Color(0.15, 0.45, 1.0)
		2:
			material.albedo_color = Color(1.0, 0.18, 0.12)
		_:
			material.albedo_color = Color(0.75, 0.75, 0.75)
	if selected:
		material.albedo_color = Color(1.0, 0.95, 0.15)
	return material

func _update_entity_ghost() -> void:
	if _active_mode != MODE_ENTITIES or _entity_tool_mode != EntityPlacementDockScript.EntityToolMode.PLACE:
		_hide_entity_ghost()
		return
	var pick_point = terrain.get_pick_point(camera, get_viewport().get_mouse_position())
	if pick_point == null:
		_hide_entity_ghost()
		return
	var local_position: Vector3 = pick_point
	if not terrain.map_data.is_local_position_in_playable_area(local_position):
		_hide_entity_ghost()
		return
	_ensure_entity_ghost()
	_placement_ghost_root.visible = true
	_placement_ghost_root.position = local_position
	_placement_ghost_root.rotation.y = _entity_settings.get("rotation_y", 0.0)

func _ensure_entity_ghost() -> void:
	var entity_id: StringName = _entity_settings.get("entity_id", &"infantry")
	var team_id: int = _entity_settings.get("team_id", 1)
	var rotation_y: float = _entity_settings.get("rotation_y", 0.0)
	if (
			_placement_ghost_root != null
			and _ghost_entity_id == entity_id
			and _ghost_team_id == team_id
			and is_equal_approx(_ghost_rotation_y, rotation_y)
	):
		return
	_clear_entity_ghost()
	_ghost_entity_id = entity_id
	_ghost_team_id = team_id
	_ghost_rotation_y = rotation_y
	var ghost_placement = EntityPlacementDataScript.new()
	ghost_placement.entity_id = entity_id
	ghost_placement.team_id = team_id
	ghost_placement.rotation_y = rotation_y
	_placement_ghost_root = _create_placement_marker(ghost_placement, true)
	_placement_ghost_root.name = "EntityPlacementGhost"
	_placement_ghost_root.visible = false
	_apply_ghost_visuals(_placement_ghost_root)
	terrain.add_child(_placement_ghost_root)

func _apply_ghost_visuals(root_node: Node) -> void:
	if root_node is MeshInstance3D:
		var mesh_instance := root_node as MeshInstance3D
		var material := StandardMaterial3D.new()
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		material.albedo_color = Color(0.2, 1.0, 0.65, 0.45)
		material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mesh_instance.material_override = material
	for child in root_node.get_children():
		_apply_ghost_visuals(child)

func _hide_entity_ghost() -> void:
	if _placement_ghost_root != null:
		_placement_ghost_root.visible = false

func _clear_entity_ghost() -> void:
	if _placement_ghost_root != null:
		_placement_ghost_root.queue_free()
	_placement_ghost_root = null
	_ghost_entity_id = &""
	_ghost_team_id = -1
	_ghost_rotation_y = INF

func _show_terrain_mode() -> void:
	_set_active_mode(MODE_TERRAIN)
	_hide_entity_ghost()
	_show_tool_dock(TerrainDockScene)
	terrain_dock = right_dock_container.get_child(0) as EditorToolDock
	_wire_terrain_dock_signals(terrain_dock)
	_sync_ui_to_tools()

func _show_entities_mode() -> void:
	_end_brush_stroke()
	_set_active_mode(MODE_ENTITIES)
	terrain.set_overlay_enabled(false)
	if brush_preview != null:
		brush_preview.hide_preview()
	_show_tool_dock(EntityPlacementDockScene)
	entity_dock = right_dock_container.get_child(0)
	_wire_entity_dock_signals(entity_dock)
	_entity_settings = entity_dock.get_settings()
	_entity_tool_mode = _entity_settings.get("tool_mode", EntityPlacementDockScript.EntityToolMode.SELECT)
	_update_entity_dock_count()
	_sync_entity_dock_to_selection()
	print("Entity tool mode: Select")

func _set_active_mode(mode: StringName) -> void:
	_active_mode = mode
	menu_bar.set_active_tool_mode(mode)

func _show_tool_dock(dock_scene: PackedScene) -> void:
	for child in right_dock_container.get_children():
		child.free()
	terrain_dock = null
	entity_dock = null
	var dock := dock_scene.instantiate() as Control
	right_dock_container.add_child(dock)
	dock.set_anchors_preset(Control.PRESET_FULL_RECT)

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
	_entity_tool_mode = clampi(mode, EntityPlacementDockScript.EntityToolMode.SELECT, EntityPlacementDockScript.EntityToolMode.DELETE)
	if _entity_tool_mode != EntityPlacementDockScript.EntityToolMode.PLACE:
		_hide_entity_ghost()
	print("Entity tool mode: %s" % _get_entity_tool_mode_name(_entity_tool_mode))

func _on_entity_settings_changed(settings: Dictionary) -> void:
	_entity_settings = settings
	_entity_tool_mode = settings.get("tool_mode", _entity_tool_mode)
	if _entity_tool_mode == EntityPlacementDockScript.EntityToolMode.PLACE:
		_clear_entity_ghost()
	if _selected_placement_index < 0 or terrain.map_data == null:
		return
	if _entity_tool_mode == EntityPlacementDockScript.EntityToolMode.PLACE:
		return
	if _selected_placement_index >= terrain.map_data.entity_placements.size():
		return
	var placement := terrain.map_data.entity_placements[_selected_placement_index] as EntityPlacementData
	if placement == null:
		return
	placement.entity_id = settings.get("entity_id", placement.entity_id)
	placement.team_id = settings.get("team_id", placement.team_id)
	placement.rotation_y = settings.get("rotation_y", placement.rotation_y)
	placement.health_spawn_mode = settings.get("health_spawn_mode", placement.health_spawn_mode)
	placement.health_value = settings.get("health_value", placement.health_value)
	_map_io.mark_dirty()
	_rebuild_placement_previews()

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
	if entity_dock == null or terrain.map_data == null:
		return
	_update_entity_dock_count()
	if _selected_placement_index < 0 or _selected_placement_index >= terrain.map_data.entity_placements.size():
		return
	var placement := terrain.map_data.entity_placements[_selected_placement_index] as EntityPlacementData
	entity_dock.set_from_placement(placement)
	_entity_settings = entity_dock.get_settings()

func _update_entity_dock_count() -> void:
	if entity_dock != null and terrain.map_data != null:
		entity_dock.set_placement_count(terrain.map_data.entity_placements.size())

func _on_save_map() -> void:
	_end_brush_stroke()
	_map_io.save()

func _on_load_map() -> void:
	_end_brush_stroke()
	_map_io.load()

func _on_map_reloaded() -> void:
	_selected_placement_index = -1
	_rebuild_placement_previews()

func _on_new_map_requested(playable_chunks: Vector2i) -> void:
	_end_brush_stroke()
	_map_io.request_new(playable_chunks)

func _on_map_created() -> void:
	_selected_placement_index = -1
	_rebuild_placement_previews()

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
	menu_bar.terrain_tool_requested.connect(_show_terrain_mode)
	menu_bar.entities_tool_requested.connect(_show_entities_mode)
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
	dock.save_map_requested.connect(_on_save_map)
	dock.load_map_requested.connect(_on_load_map)

func _wire_entity_dock_signals(dock) -> void:
	dock.placement_mode_changed.connect(_on_entity_placement_mode_changed)
	dock.tool_mode_changed.connect(_on_entity_tool_mode_changed)
	dock.placement_settings_changed.connect(_on_entity_settings_changed)
	dock.delete_selected_requested.connect(_delete_selected_or_last_placement)
	dock.delete_last_requested.connect(_delete_last_placement)

func _delete_last_placement() -> void:
	_selected_placement_index = -1
	_delete_selected_or_last_placement()

func _ensure_placement_preview_root() -> void:
	if _placement_preview_root != null:
		return
	_placement_preview_root = Node3D.new()
	_placement_preview_root.name = "EntityPlacementPreviews"
	terrain.add_child(_placement_preview_root)

func _ensure_light() -> void:
	if has_node("Sun"):
		return
	var sun := DirectionalLight3D.new()
	sun.name = "Sun"
	sun.rotation_degrees = Vector3(-55.0, -35.0, 0.0)
	add_child(sun)
