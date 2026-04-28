extends Node
class_name InputComponent

var _terrain: Terrain = null
var _camera_rig: PlayerCameraRig = null
var _selection: SelectionComponent = null
var _target_source_entity: EntityBase = null
var _target_command_id: StringName
var _target_mode := CommandBase.TargetMode.NONE

func setup(terrain: Terrain, camera_rig: PlayerCameraRig, selection: SelectionComponent) -> void:
	_terrain = terrain
	_camera_rig = camera_rig
	_selection = selection

func begin_command_targeting(source_entity: EntityBase, command_id: StringName, target_mode: int) -> void:
	if source_entity == null:
		return
	_target_source_entity = source_entity
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
	if not event is InputEventMouseButton or not event.pressed:
		return

	var camera: Camera3D = _camera_rig.get_camera()

	if event.button_index == MOUSE_BUTTON_LEFT:
		if _is_targeting():
			_handle_targeting_left_click(camera, event.position)
		else:
			_handle_left_click(camera, event.position)
		get_viewport().set_input_as_handled()
	elif event.button_index == MOUSE_BUTTON_RIGHT:
		if _is_targeting():
			_cancel_targeting()
		else:
			_handle_right_click(camera, event.position)
		get_viewport().set_input_as_handled()

func _handle_left_click(camera: Camera3D, screen_pos: Vector2) -> void:
	var entity := _raycast_entity(camera, screen_pos)
	if entity != null:
		_selection.select(entity)
	else:
		_selection.deselect()

func _handle_right_click(camera: Camera3D, screen_pos: Vector2) -> void:
	if not _selection.has_selection():
		return

	var terrain_local = _terrain.get_pick_point(camera, screen_pos)
	if terrain_local == null:
		return

	var local_pos: Vector3 = terrain_local
	if not _terrain.is_ground_walkable_at_local_position(local_pos):
		return

	var selected_entity := _selection.get_selected() as EntityBase
	if selected_entity == null:
		return
	selected_entity.execute_command(&"move", {
		"target_position": _terrain.to_global(local_pos),
		"terrain": _terrain,
	})

func _handle_targeting_left_click(camera: Camera3D, screen_pos: Vector2) -> void:
	if _target_source_entity == null:
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
	_target_source_entity.execute_command(_target_command_id, {
		"target_position": _terrain.to_global(local_pos),
		"terrain": _terrain,
	})
	_cancel_targeting()

func _execute_entity_target_command(camera: Camera3D, screen_pos: Vector2) -> void:
	var target_entity := _raycast_entity(camera, screen_pos)
	if target_entity == null:
		return
	_target_source_entity.execute_command(_target_command_id, {
		"target_entity": target_entity,
	})
	_cancel_targeting()

func _is_targeting() -> bool:
	return _target_source_entity != null

func _cancel_targeting() -> void:
	_target_source_entity = null
	_target_command_id = &""
	_target_mode = CommandBase.TargetMode.NONE

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
