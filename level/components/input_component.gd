extends Node
class_name InputComponent

const DRAG_THRESHOLD := 8.0
const PLAYER_TEAM_ID := 1

var _terrain: Terrain = null
var _camera_rig: PlayerCameraRig = null
var _selection: SelectionComponent = null
var _selection_rect: ColorRect = null
var _target_source_entities: Array[EntityBase] = []
var _target_command_id: StringName
var _target_mode := CommandBase.TargetMode.NONE
var _left_mouse_down := false
var _dragging_selection := false
var _drag_start_position := Vector2.ZERO
var _drag_current_position := Vector2.ZERO

func setup(
		terrain: Terrain,
		camera_rig: PlayerCameraRig,
		selection: SelectionComponent,
		selection_rect: ColorRect = null
) -> void:
	_terrain = terrain
	_camera_rig = camera_rig
	_selection = selection
	_selection_rect = selection_rect
	_hide_selection_rect()

func begin_command_targeting(source_entities: Array[EntityBase], command_id: StringName, target_mode: int) -> void:
	var valid_sources := _get_entities_with_command(source_entities, command_id)
	if valid_sources.is_empty():
		return
	_target_source_entities = valid_sources
	_target_command_id = command_id
	_target_mode = target_mode

func _unhandled_input(event: InputEvent) -> void:
	if _terrain == null or _camera_rig == null or _selection == null:
		return
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		if _is_targeting():
			_cancel_targeting()
			get_viewport().set_input_as_handled()
		return
	if event is InputEventMouseMotion and _left_mouse_down and not _is_targeting():
		_update_drag_selection(event.position)
		return
	if not event is InputEventMouseButton:
		return

	var camera: Camera3D = _camera_rig.get_camera()

	if event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed and _is_targeting():
			_handle_targeting_left_click(camera, event.position)
			get_viewport().set_input_as_handled()
			return
		if event.pressed:
			_begin_left_mouse(event.position)
		elif _left_mouse_down:
			_finish_left_mouse(camera, event.position)
		get_viewport().set_input_as_handled()
	elif event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
		if _is_targeting():
			_cancel_targeting()
		else:
			_handle_right_click(camera, event.position)
		get_viewport().set_input_as_handled()

func _handle_left_click(camera: Camera3D, screen_pos: Vector2) -> void:
	var entity := _raycast_entity(camera, screen_pos)
	var additive := Input.is_key_pressed(KEY_SHIFT)
	if entity != null:
		if additive:
			if _selection.is_selected(entity):
				_selection.remove_from_selection(entity)
			else:
				_selection.add_to_selection(entity)
		else:
			_selection.select_single(entity)
	elif not additive:
		_selection.clear_selection()

func _handle_right_click(camera: Camera3D, screen_pos: Vector2) -> void:
	if not _selection.has_selection():
		return
	var commandable_selection := _get_commandable_selection(_selection.get_selected_entities())
	if commandable_selection.is_empty():
		print("No commandable selected entities; command ignored.")
		return

	var target_entity := _raycast_entity(camera, screen_pos)
	if target_entity != null:
		_handle_right_click_entity_target(commandable_selection, target_entity)
		return

	var terrain_local = _terrain.get_pick_point(camera, screen_pos)
	if terrain_local == null:
		return

	var local_pos: Vector3 = terrain_local
	if not _terrain.is_ground_walkable_at_local_position(local_pos):
		return

	_execute_move_command_on_entities(commandable_selection, _terrain.to_global(local_pos))

func _begin_left_mouse(screen_pos: Vector2) -> void:
	_left_mouse_down = true
	_dragging_selection = false
	_drag_start_position = screen_pos
	_drag_current_position = screen_pos
	_hide_selection_rect()

func _finish_left_mouse(camera: Camera3D, screen_pos: Vector2) -> void:
	if _dragging_selection:
		_select_units_in_rect(camera, _make_drag_rect(_drag_start_position, screen_pos))
	else:
		_handle_left_click(camera, screen_pos)
	_left_mouse_down = false
	_dragging_selection = false
	_hide_selection_rect()

func _update_drag_selection(screen_pos: Vector2) -> void:
	_drag_current_position = screen_pos
	if not _dragging_selection and _drag_start_position.distance_to(screen_pos) >= DRAG_THRESHOLD:
		_dragging_selection = true
	if _dragging_selection:
		_show_selection_rect(_make_drag_rect(_drag_start_position, screen_pos))

func _select_units_in_rect(camera: Camera3D, rect: Rect2) -> void:
	var selected_units: Array[EntityBase] = []
	for node in get_tree().get_nodes_in_group("selectable_units"):
		var entity := node as EntityBase
		if entity == null:
			continue
		var screen_pos := camera.unproject_position(entity.global_position)
		if rect.has_point(screen_pos):
			selected_units.append(entity)
	_selection.select_many(selected_units)

func _make_drag_rect(a: Vector2, b: Vector2) -> Rect2:
	var min_pos := Vector2(minf(a.x, b.x), minf(a.y, b.y))
	var max_pos := Vector2(maxf(a.x, b.x), maxf(a.y, b.y))
	return Rect2(min_pos, max_pos - min_pos)

func _show_selection_rect(rect: Rect2) -> void:
	if _selection_rect == null:
		return
	_selection_rect.visible = true
	_selection_rect.position = rect.position
	_selection_rect.size = rect.size

func _hide_selection_rect() -> void:
	if _selection_rect != null:
		_selection_rect.visible = false

func _handle_targeting_left_click(camera: Camera3D, screen_pos: Vector2) -> void:
	if _target_source_entities.is_empty():
		_cancel_targeting()
		return
	if _target_mode == CommandBase.TargetMode.POINT or _target_mode == CommandBase.TargetMode.AREA:
		_execute_point_target_command(camera, screen_pos)
	elif _target_mode == CommandBase.TargetMode.ENTITY:
		_execute_entity_target_command(camera, screen_pos)
	else:
		_cancel_targeting()

func _execute_point_target_command(camera: Camera3D, screen_pos: Vector2) -> void:
	var terrain_local = _terrain.get_pick_point(camera, screen_pos)
	if terrain_local == null:
		return
	var local_pos: Vector3 = terrain_local
	if not _terrain.is_ground_walkable_at_local_position(local_pos):
		return
	var target_position := _terrain.to_global(local_pos)
	if _target_command_id == &"move":
		_execute_move_command_on_entities(_target_source_entities, target_position)
	else:
		_execute_command_on_entities(_target_source_entities, _target_command_id, {
			"target_position": target_position,
			"terrain": _terrain,
		})
	_cancel_targeting()

func _execute_entity_target_command(camera: Camera3D, screen_pos: Vector2) -> void:
	var target_entity := _raycast_entity(camera, screen_pos)
	if target_entity == null:
		return
	if _target_command_id == &"attack" and not _can_any_source_attack_target(_target_source_entities, target_entity):
		_print_attack_target_rejection(target_entity)
		_cancel_targeting()
		return
	_execute_command_on_entities(_target_source_entities, _target_command_id, {
		"target_entity": target_entity,
	})
	_cancel_targeting()

func _is_targeting() -> bool:
	return not _target_source_entities.is_empty()

func _cancel_targeting() -> void:
	_target_source_entities.clear()
	_target_command_id = &""
	_target_mode = CommandBase.TargetMode.NONE

func _get_entities_with_command(entities: Array[EntityBase], command_id: StringName) -> Array[EntityBase]:
	var valid_entities: Array[EntityBase] = []
	for entity in entities:
		if _is_commandable_by_player(entity) and entity.has_command(command_id):
			valid_entities.append(entity)
	return valid_entities

func _execute_command_on_entities(entities: Array[EntityBase], command_id: StringName, context: Dictionary) -> int:
	var success_count := 0
	var attempted_count := 0
	for entity in entities:
		if not is_instance_valid(entity) or entity == null or not entity.has_command(command_id):
			continue
		attempted_count += 1
		if entity.execute_command(command_id, context):
			success_count += 1
	print("Command %s succeeded on %d/%d commandable entities." % [command_id, success_count, attempted_count])
	return success_count

func _execute_move_command_on_entities(entities: Array[EntityBase], target_position: Vector3) -> int:
	var movable_entities := _get_entities_with_command(entities, &"move")
	if movable_entities.size() < 2:
		return _execute_command_on_entities(movable_entities, &"move", {
			"target_position": target_position,
			"terrain": _terrain,
		})

	var center := Vector3.ZERO
	for entity in movable_entities:
		if not is_instance_valid(entity):
			continue
		center += entity.global_position
	center /= movable_entities.size()

	var success_count := 0
	var attempted_count := 0
	for entity in movable_entities:
		if not is_instance_valid(entity):
			continue
		attempted_count += 1
		var offset := entity.global_position - center
		offset.y = 0.0
		var assigned_target := _snap_world_position_to_terrain(target_position + offset)
		if entity.execute_command(&"move", {
			"target_position": assigned_target,
			"terrain": _terrain,
		}):
			success_count += 1
	print("Command move succeeded on %d/%d commandable entities." % [success_count, attempted_count])
	return success_count

func _handle_right_click_entity_target(commandable_entities: Array[EntityBase], target_entity: EntityBase) -> void:
	if _is_harvestable_target(target_entity):
		var gatherers := _get_entities_with_command(commandable_entities, &"gather")
		if gatherers.is_empty():
			print("Right-click resource target ignored: no selected workers can gather.")
			return
		_execute_command_on_entities(gatherers, &"gather", {
			"target_entity": target_entity,
		})
		return
	if _can_any_source_attack_target(commandable_entities, target_entity):
		_execute_command_on_entities(commandable_entities, &"attack", {
			"target_entity": target_entity,
		})
		return
	_print_attack_target_rejection(target_entity)

func _can_any_source_attack_target(source_entities: Array[EntityBase], target_entity: EntityBase) -> bool:
	if target_entity == null or not is_instance_valid(target_entity) or not target_entity.can_be_attacked():
		return false
	for source in source_entities:
		if not is_instance_valid(source) or source == null or not source.has_command(&"attack"):
			continue
		if source.is_hostile_to(target_entity):
			return true
	return false

func _is_harvestable_target(target_entity: EntityBase) -> bool:
	if target_entity == null or not is_instance_valid(target_entity):
		return false
	return target_entity.get_component(&"HarvestableComponent") != null

func _get_commandable_selection(entities: Array[EntityBase]) -> Array[EntityBase]:
	var commandable_entities: Array[EntityBase] = []
	for entity in entities:
		if _is_commandable_by_player(entity):
			commandable_entities.append(entity)
	return commandable_entities

func _is_commandable_by_player(entity: EntityBase) -> bool:
	if entity == null or not is_instance_valid(entity):
		return false
	if entity.has_method("is_alive") and not entity.is_alive():
		return false
	return entity.has_method("get_team_id") and entity.get_team_id() == PLAYER_TEAM_ID and not entity.get_available_commands().is_empty()

func _print_attack_target_rejection(target_entity: EntityBase) -> void:
	if target_entity == null or not is_instance_valid(target_entity):
		print("Right-click target is invalid; no command issued.")
		return
	if not target_entity.can_be_attacked():
		print("Right-click target is not attackable; no command issued.")
		return
	var selected_entities := _selection.get_selected_entities()
	var source := selected_entities[0] if not selected_entities.is_empty() else null
	if source != null and is_instance_valid(source) and source.is_same_team(target_entity):
		print("Right-click target is friendly; no command issued.")
	elif target_entity.get_team_id() == 0:
		print("Right-click target is neutral; no command issued.")
	else:
		print("Right-click target is not hostile; no command issued.")

func _snap_world_position_to_terrain(world_position: Vector3) -> Vector3:
	if _terrain == null:
		return world_position
	var local_position := _terrain.to_local(world_position)
	var height := _terrain.get_height_at_local_position(local_position)
	return _terrain.to_global(Vector3(local_position.x, height, local_position.z))

func _raycast_entity(camera: Camera3D, screen_pos: Vector2) -> EntityBase:
	var from: Vector3 = camera.project_ray_origin(screen_pos)
	var to: Vector3 = from + camera.project_ray_normal(screen_pos) * 4096.0
	var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(from, to)
	query.collide_with_areas = true
	query.collide_with_bodies = false
	var hit: Dictionary = _terrain.get_world_3d().direct_space_state.intersect_ray(query)
	if hit.is_empty():
		return null
	var collider = hit.get("collider")
	if collider == null or not collider.is_in_group("entity_clickable"):
		return null
	if collider.has_method("get_entity_parent"):
		return collider.get_entity_parent()
	push_warning("%s is in entity_clickable but does not expose an entity_parent." % collider.name)
	return null
