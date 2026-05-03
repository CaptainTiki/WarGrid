extends Node
class_name EntityPlacementController

signal placements_changed
signal selection_changed
signal placement_count_changed(count: int)
signal placement_validation_changed(is_valid: bool, reason: String)

const EntityCatalogScript := preload("res://game/entities/catalog/entity_catalog.gd")
const EntityPlacementDataScript := preload("res://game/entities/placement/entity_placement_data.gd")
const PlacementValidationResultScript := preload("res://mapeditor/entities/placement_validation_result.gd")
const PLACEMENT_SELECT_RADIUS := 2.0

var terrain: Terrain
var entity_catalog := EntityCatalogScript.new()
var entity_settings := {}
var selected_placement_index := -1

var placement_preview_root: Node3D
var placement_preview_nodes: Array[Node3D] = []

var placement_ghost_root: Node3D
var ghost_entity_id: StringName = &""
var ghost_team_id := -1
var ghost_rotation_y := INF
var last_validation_result: RefCounted = null
var placement_filter_entity_ids: Array[StringName] = []
var _footprint_info_cache := {}
var _placement_cells_by_index: Array = []
var _occupied_cell_to_indices := {}
var _occupancy_cache_dirty := true

func setup(terrain_ref: Terrain) -> void:
	terrain = terrain_ref
	mark_occupancy_cache_dirty()
	_ensure_placement_preview_root()

func create_placement(local_position: Vector3) -> void:
	var entity_id: StringName = entity_settings.get("entity_id", &"")
	var placement_position := get_snapped_or_original_position(local_position, entity_id)
	var result: RefCounted = validate_placement(placement_position, entity_id)
	_set_last_validation_result(result)
	if not result.is_valid:
		push_warning("Cannot place entity: %s" % result.reason)
		return
	var placement = EntityPlacementDataScript.new()
	placement.entity_id = entity_id
	placement.position = placement_position
	placement.rotation_y = entity_settings.get("rotation_y", 0.0)
	placement.team_id = entity_settings.get("team_id", 1)
	placement.health_spawn_mode = entity_settings.get("health_spawn_mode", EntityPlacementDataScript.HealthSpawnMode.FULL)
	placement.health_value = entity_settings.get("health_value", 1.0)
	terrain.map_data.entity_placements.append(placement)
	selected_placement_index = terrain.map_data.entity_placements.size() - 1
	mark_occupancy_cache_dirty()
	rebuild_placement_previews()
	selection_changed.emit()
	placements_changed.emit()
	print("Placed %s at %s team %d." % [placement.entity_id, placement.position, placement.team_id])

func select_nearest_placement(local_position: Vector3) -> void:
	selected_placement_index = find_nearest_placement_index(local_position)
	rebuild_placement_previews()
	selection_changed.emit()
	if selected_placement_index >= 0 and terrain != null and terrain.map_data != null:
		var placement := terrain.map_data.entity_placements[selected_placement_index] as EntityPlacementData
		if placement != null:
			print("Selected placement %s at %s." % [placement.entity_id, placement.position])

func find_nearest_placement_index(local_position: Vector3) -> int:
	if terrain == null or terrain.map_data == null:
		return -1
	var best_index := -1
	var best_distance := PLACEMENT_SELECT_RADIUS
	for i in terrain.map_data.entity_placements.size():
		var placement := terrain.map_data.entity_placements[i] as EntityPlacementData
		if placement == null:
			continue
		if not _matches_placement_filter(placement):
			continue
		var flat_distance := Vector2(local_position.x, local_position.z).distance_to(Vector2(placement.position.x, placement.position.z))
		if flat_distance <= best_distance:
			best_distance = flat_distance
			best_index = i
	return best_index

func delete_selected_or_last_placement() -> void:
	if terrain == null or terrain.map_data == null or terrain.map_data.entity_placements.is_empty():
		return
	var index := selected_placement_index
	if index < 0 or index >= terrain.map_data.entity_placements.size() or not _matches_placement_filter(terrain.map_data.entity_placements[index] as EntityPlacementData):
		index = _find_last_filtered_placement_index()
	if index < 0:
		return
	var placement := terrain.map_data.entity_placements[index] as EntityPlacementData
	var deleted_id := placement.entity_id if placement != null else &"unknown"
	terrain.map_data.entity_placements.remove_at(index)
	selected_placement_index = -1
	mark_occupancy_cache_dirty()
	rebuild_placement_previews()
	selection_changed.emit()
	placements_changed.emit()
	print("Deleted placement %s." % deleted_id)

func delete_last_placement() -> void:
	selected_placement_index = -1
	delete_selected_or_last_placement()

func delete_nearest_placement(local_position: Vector3) -> void:
	var index := find_nearest_placement_index(local_position)
	if index < 0 or terrain == null or terrain.map_data == null:
		return
	var placement := terrain.map_data.entity_placements[index] as EntityPlacementData
	var deleted_id := placement.entity_id if placement != null else &"unknown"
	terrain.map_data.entity_placements.remove_at(index)
	if selected_placement_index == index:
		selected_placement_index = -1
		selection_changed.emit()
	elif selected_placement_index > index:
		selected_placement_index -= 1
		selection_changed.emit()
	mark_occupancy_cache_dirty()
	rebuild_placement_previews()
	placements_changed.emit()
	print("Deleted placement %s." % deleted_id)

func move_selected_placement(local_position: Vector3) -> void:
	var placement := get_selected_placement()
	if placement == null:
		return
	var placement_position := get_snapped_or_original_position(local_position, placement.entity_id)
	var result: RefCounted = validate_placement(placement_position, placement.entity_id, placement.rotation_y, selected_placement_index)
	_set_last_validation_result(result)
	if not result.is_valid:
		push_warning("Cannot move entity: %s" % result.reason)
		return
	placement.position = placement_position
	mark_occupancy_cache_dirty()
	rebuild_placement_previews()
	placements_changed.emit()
	print("Moved selected placement to %s." % placement_position)

func rotate_selected_placement(delta_radians: float) -> void:
	var placement := get_selected_placement()
	if placement == null:
		return
	placement.rotation_y = wrapf(placement.rotation_y + delta_radians, -PI, PI)
	entity_settings["rotation_y"] = placement.rotation_y
	mark_occupancy_cache_dirty()
	rebuild_placement_previews()
	placements_changed.emit()
	print("Rotated selected placement to %.0f degrees." % rad_to_deg(placement.rotation_y))

func get_selected_placement() -> EntityPlacementData:
	if terrain == null or terrain.map_data == null:
		return null
	if selected_placement_index < 0 or selected_placement_index >= terrain.map_data.entity_placements.size():
		return null
	return terrain.map_data.entity_placements[selected_placement_index] as EntityPlacementData

func get_selected_placement_index() -> int:
	return selected_placement_index

func has_selected_placement() -> bool:
	return get_selected_placement() != null

func get_placement_count() -> int:
	if terrain == null or terrain.map_data == null:
		return 0
	return terrain.map_data.entity_placements.size()

func get_filtered_placement_count() -> int:
	if terrain == null or terrain.map_data == null:
		return 0
	if placement_filter_entity_ids.is_empty():
		return get_placement_count()
	var count := 0
	for placement_resource in terrain.map_data.entity_placements:
		var placement := placement_resource as EntityPlacementData
		if placement != null and _matches_placement_filter(placement):
			count += 1
	return count

func should_snap_entity_to_grid(entity_id: StringName) -> bool:
	var checked_entity_id := entity_id
	if checked_entity_id == &"":
		checked_entity_id = entity_settings.get("entity_id", &"")
	var definition: EntityDefinition = entity_catalog.get_definition(checked_entity_id)
	if definition == null:
		return true
	return definition.editor_snap_mode == EntityDefinition.EditorPlacementSnapMode.GRID_CENTER

func snap_position_for_entity(local_position: Vector3, entity_id: StringName) -> Vector3:
	if terrain == null or terrain.map_data == null:
		return local_position
	if not should_snap_entity_to_grid(entity_id):
		return local_position
	var visual_cell := terrain.get_visual_cell_from_local_position(local_position)
	if not terrain.map_data.is_visual_cell_in_playable_area(visual_cell):
		return local_position
	var cell_size := terrain.map_data.cell_size
	var snapped_position := Vector3(
		(float(visual_cell.x) + 0.5) * cell_size,
		0.0,
		(float(visual_cell.y) + 0.5) * cell_size
	)
	snapped_position.y = terrain.get_height_at_local_position(snapped_position)
	return snapped_position

func get_snapped_or_original_position(local_position: Vector3, entity_id: StringName = &"") -> Vector3:
	var checked_entity_id := entity_id
	if checked_entity_id == &"":
		checked_entity_id = entity_settings.get("entity_id", &"")
	return snap_position_for_entity(local_position, checked_entity_id)

func get_entity_footprint_cells(entity_id: StringName, local_position: Vector3, rotation_y: float) -> Array[Vector2i]:
	var definition: EntityDefinition = entity_catalog.get_definition(entity_id)
	if definition == null:
		return [_get_visual_cell(local_position)]
	var footprint_info := _get_footprint_info(definition.id)
	if not footprint_info.get("has_footprint", false):
		return [_get_visual_cell(local_position)]
	return _get_footprint_cells(local_position, rotation_y, footprint_info)

func get_blocked_cells_near(
		entity_id: StringName,
		local_position: Vector3,
		rotation_y: float,
		radius: int = 4,
		ignored_placement_index: int = -1
) -> Dictionary:
	var result := {
		"occupied": [] as Array[Vector2i],
		"non_buildable": [] as Array[Vector2i],
		"non_walkable": [] as Array[Vector2i],
	}
	if terrain == null or terrain.map_data == null:
		return result
	var definition: EntityDefinition = entity_catalog.get_definition(entity_id)
	if definition == null:
		return result
	var candidate_cells := get_entity_footprint_cells(entity_id, local_position, rotation_y)
	if candidate_cells.is_empty():
		candidate_cells = [_get_visual_cell(local_position)]
	var bounds := _get_cell_bounds(candidate_cells)
	var min_cell: Vector2i = bounds.position - Vector2i(radius, radius)
	var max_cell: Vector2i = bounds.end + Vector2i(radius, radius)
	var occupied_cells := get_occupied_cells_near(Rect2i(min_cell, max_cell - min_cell), ignored_placement_index)
	for occupied_cell in occupied_cells:
		(result["occupied"] as Array[Vector2i]).append(occupied_cell)
	for z in range(min_cell.y, max_cell.y):
		for x in range(min_cell.x, max_cell.x):
			var cell := Vector2i(x, z)
			if not terrain.map_data.is_visual_cell_in_playable_area(cell):
				continue
			if definition.category == &"building" and not _is_buildable_cell(cell):
				(result["non_buildable"] as Array[Vector2i]).append(cell)
			elif definition.category == &"unit" and not _is_walkable_cell(cell):
				(result["non_walkable"] as Array[Vector2i]).append(cell)
			elif definition.category == &"resource" and not _is_walkable_cell(cell) and not _is_buildable_cell(cell):
				(result["non_buildable"] as Array[Vector2i]).append(cell)
	return result

func get_current_hover_validation(
		entity_id: StringName,
		local_position: Vector3,
		rotation_y: float,
		ignored_placement_index: int = -1
) -> RefCounted:
	return validate_placement(local_position, entity_id, rotation_y, ignored_placement_index)

func mark_occupancy_cache_dirty() -> void:
	_occupancy_cache_dirty = true

func rebuild_occupancy_cache() -> void:
	_placement_cells_by_index.clear()
	_occupied_cell_to_indices.clear()
	_occupancy_cache_dirty = false
	if terrain == null or terrain.map_data == null:
		return
	_placement_cells_by_index.resize(terrain.map_data.entity_placements.size())
	for i in terrain.map_data.entity_placements.size():
		var placement := terrain.map_data.entity_placements[i] as EntityPlacementData
		var cells: Array[Vector2i] = []
		if placement != null:
			var definition: EntityDefinition = entity_catalog.get_definition(placement.entity_id)
			if definition != null:
				cells = _get_cells_for_existing_placement(placement, definition)
		_placement_cells_by_index[i] = cells
		for cell in cells:
			if not _occupied_cell_to_indices.has(cell):
				_occupied_cell_to_indices[cell] = []
			(_occupied_cell_to_indices[cell] as Array).append(i)

func get_occupied_cells_near(bounds: Rect2i, ignored_placement_index: int = -1) -> Array[Vector2i]:
	_ensure_occupancy_cache()
	var cells: Array[Vector2i] = []
	if bounds.size.x <= 0 or bounds.size.y <= 0:
		return cells
	for z in range(bounds.position.y, bounds.end.y):
		for x in range(bounds.position.x, bounds.end.x):
			var cell := Vector2i(x, z)
			if is_visual_cell_occupied(cell, ignored_placement_index):
				cells.append(cell)
	return cells

func is_visual_cell_occupied(cell: Vector2i, ignored_placement_index: int = -1) -> bool:
	_ensure_occupancy_cache()
	if not _occupied_cell_to_indices.has(cell):
		return false
	var indices := _occupied_cell_to_indices[cell] as Array
	for index in indices:
		if index is int and index != ignored_placement_index:
			return true
	return false

func _ensure_occupancy_cache() -> void:
	if _occupancy_cache_dirty:
		rebuild_occupancy_cache()

func set_placement_filter_entity_ids(ids: Array[StringName]) -> void:
	placement_filter_entity_ids = ids.duplicate()

func clear_placement_filter() -> void:
	placement_filter_entity_ids.clear()

func validate_placement(
		local_position: Vector3,
		entity_id: StringName = &"",
		rotation_y: float = INF,
		ignored_placement_index: int = -1
) -> RefCounted:
	if terrain == null:
		return PlacementValidationResultScript.invalid("No terrain", local_position)
	if terrain.map_data == null:
		return PlacementValidationResultScript.invalid("No map data", local_position)

	var checked_entity_id := entity_id
	if checked_entity_id == &"":
		checked_entity_id = entity_settings.get("entity_id", &"")
	if checked_entity_id == &"":
		return PlacementValidationResultScript.invalid("No entity selected", local_position)

	var definition: EntityDefinition = entity_catalog.get_definition(checked_entity_id)
	if definition == null:
		return PlacementValidationResultScript.invalid("Missing entity definition", local_position)
	if not _is_inside_playable_area(local_position):
		return PlacementValidationResultScript.invalid("Outside playable area", local_position)

	var playable_cell := _get_playable_cell(local_position)
	var visual_cell := _get_visual_cell(local_position)
	var checked_rotation_y := rotation_y
	if is_inf(checked_rotation_y):
		checked_rotation_y = entity_settings.get("rotation_y", 0.0)

	var footprint_result: RefCounted = _validate_footprint(definition, local_position, checked_rotation_y, ignored_placement_index)
	if footprint_result != null and not footprint_result.is_valid:
		return footprint_result

	match definition.category:
		&"building":
			if not _is_buildable_cell(visual_cell):
				return PlacementValidationResultScript.invalid("Requires buildable terrain", local_position, playable_cell)
		&"unit":
			if not _is_walkable_cell(visual_cell):
				return PlacementValidationResultScript.invalid("Requires walkable terrain", local_position, playable_cell)
		&"resource":
			if not _is_walkable_cell(visual_cell) and not _is_buildable_cell(visual_cell):
				return PlacementValidationResultScript.invalid("No terrain under cursor", local_position, playable_cell)
		_:
			# TODO: Replace the default center-cell rule as placement metadata expands.
			if not _is_walkable_cell(visual_cell):
				return PlacementValidationResultScript.invalid("Requires walkable terrain", local_position, playable_cell)

	if _is_visual_cell_blocked_by_existing_placement(visual_cell, ignored_placement_index):
		return PlacementValidationResultScript.invalid("Footprint blocked", local_position, playable_cell)
	return PlacementValidationResultScript.valid(local_position, playable_cell)

func get_last_validation_result() -> RefCounted:
	return last_validation_result

func is_last_placement_valid() -> bool:
	return last_validation_result != null and last_validation_result.is_valid

func set_entity_settings(settings: Dictionary, apply_to_selected: bool = false) -> void:
	entity_settings = settings.duplicate()
	if apply_to_selected:
		_apply_settings_to_selected_placement()

func get_entity_settings() -> Dictionary:
	return entity_settings

func reset_selection() -> void:
	if selected_placement_index == -1:
		return
	selected_placement_index = -1
	selection_changed.emit()

func rebuild_placement_previews() -> void:
	mark_occupancy_cache_dirty()
	_ensure_placement_preview_root()
	for child in placement_preview_root.get_children():
		child.queue_free()
	placement_preview_nodes.clear()
	if terrain == null or terrain.map_data == null:
		placement_count_changed.emit(0)
		return
	for i in terrain.map_data.entity_placements.size():
		var placement := terrain.map_data.entity_placements[i] as EntityPlacementData
		if placement == null:
			continue
		var marker := _create_placement_marker(placement, i == selected_placement_index)
		placement_preview_root.add_child(marker)
		placement_preview_nodes.append(marker)
	print("Loaded %d entity placements." % terrain.map_data.entity_placements.size())
	placement_count_changed.emit(terrain.map_data.entity_placements.size())

func update_ghost(camera: Camera3D, mouse_position: Vector2) -> void:
	if terrain == null:
		hide_ghost()
		_set_last_validation_result(PlacementValidationResultScript.invalid("No terrain"))
		return
	if terrain.map_data == null:
		hide_ghost()
		_set_last_validation_result(PlacementValidationResultScript.invalid("No map data"))
		return
	var pick_point = terrain.get_pick_point(camera, mouse_position)
	if pick_point == null:
		hide_ghost()
		_set_last_validation_result(PlacementValidationResultScript.invalid("No terrain under cursor"))
		return
	var picked_position: Vector3 = pick_point
	var entity_id: StringName = entity_settings.get("entity_id", &"")
	var local_position := get_snapped_or_original_position(picked_position, entity_id)
	_ensure_entity_ghost()
	placement_ghost_root.visible = true
	placement_ghost_root.position = local_position
	placement_ghost_root.rotation.y = entity_settings.get("rotation_y", 0.0)
	var result: RefCounted = validate_placement(local_position)
	_set_last_validation_result(result)
	_apply_ghost_validation_visuals(result.is_valid)

func hide_ghost() -> void:
	if placement_ghost_root != null:
		placement_ghost_root.visible = false

func clear_ghost() -> void:
	if placement_ghost_root != null:
		placement_ghost_root.queue_free()
	placement_ghost_root = null
	ghost_entity_id = &""
	ghost_team_id = -1
	ghost_rotation_y = INF

func _apply_settings_to_selected_placement() -> void:
	var placement := get_selected_placement()
	if placement == null:
		return
	placement.entity_id = entity_settings.get("entity_id", placement.entity_id)
	placement.team_id = entity_settings.get("team_id", placement.team_id)
	placement.rotation_y = entity_settings.get("rotation_y", placement.rotation_y)
	placement.health_spawn_mode = entity_settings.get("health_spawn_mode", placement.health_spawn_mode)
	placement.health_value = entity_settings.get("health_value", placement.health_value)
	mark_occupancy_cache_dirty()
	rebuild_placement_previews()
	placements_changed.emit()
	_set_last_validation_result(validate_placement(placement.position, placement.entity_id, placement.rotation_y, selected_placement_index))

func _ensure_placement_preview_root() -> void:
	if placement_preview_root != null:
		return
	if terrain == null:
		return
	placement_preview_root = Node3D.new()
	placement_preview_root.name = "EntityPlacementPreviews"
	terrain.add_child(placement_preview_root)

func _create_placement_marker(placement: EntityPlacementData, selected: bool) -> Node3D:
	var marker := Node3D.new()
	marker.name = "Placement_%s" % placement.entity_id
	marker.position = placement.position
	marker.rotation.y = placement.rotation_y

	var entity := entity_catalog.spawn_entity(placement.entity_id)
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

func _ensure_entity_ghost() -> void:
	var entity_id: StringName = entity_settings.get("entity_id", &"infantry")
	var team_id: int = entity_settings.get("team_id", 1)
	var rotation_y: float = entity_settings.get("rotation_y", 0.0)
	if (
			placement_ghost_root != null
			and ghost_entity_id == entity_id
			and ghost_team_id == team_id
			and is_equal_approx(ghost_rotation_y, rotation_y)
	):
		return
	clear_ghost()
	ghost_entity_id = entity_id
	ghost_team_id = team_id
	ghost_rotation_y = rotation_y
	var ghost_placement = EntityPlacementDataScript.new()
	ghost_placement.entity_id = entity_id
	ghost_placement.team_id = team_id
	ghost_placement.rotation_y = rotation_y
	placement_ghost_root = _create_placement_marker(ghost_placement, true)
	placement_ghost_root.name = "EntityPlacementGhost"
	placement_ghost_root.visible = false
	_apply_ghost_visuals(placement_ghost_root)
	terrain.add_child(placement_ghost_root)

func _apply_ghost_visuals(root_node: Node) -> void:
	if root_node is MeshInstance3D:
		var mesh_instance := root_node as MeshInstance3D
		var material := StandardMaterial3D.new()
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		material.albedo_color = Color(0.2, 1.0, 0.65, 0.42)
		material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mesh_instance.material_override = material
	for child in root_node.get_children():
		_apply_ghost_visuals(child)

func _apply_ghost_validation_visuals(is_valid: bool) -> void:
	if placement_ghost_root == null:
		return
	var tint := Color(0.2, 1.0, 0.65, 0.42) if is_valid else Color(1.0, 0.18, 0.12, 0.45)
	_apply_ghost_tint(placement_ghost_root, tint)

func _apply_ghost_tint(root_node: Node, tint: Color) -> void:
	if root_node is MeshInstance3D:
		var mesh_instance := root_node as MeshInstance3D
		var material := mesh_instance.material_override as StandardMaterial3D
		if material == null:
			material = StandardMaterial3D.new()
			material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			mesh_instance.material_override = material
		material.albedo_color = tint
	for child in root_node.get_children():
		_apply_ghost_tint(child, tint)

func _set_last_validation_result(result: RefCounted) -> void:
	var changed: bool = (
		last_validation_result == null
		or result == null
		or last_validation_result.is_valid != result.is_valid
		or last_validation_result.reason != result.reason
	)
	last_validation_result = result
	if changed and result != null:
		placement_validation_changed.emit(result.is_valid, result.reason)

func _is_inside_playable_area(local_position: Vector3) -> bool:
	return terrain != null and terrain.map_data != null and terrain.map_data.is_local_position_in_playable_area(local_position)

func _get_playable_cell(local_position: Vector3) -> Vector2i:
	if terrain == null or terrain.map_data == null:
		return Vector2i(-1, -1)
	return terrain.get_playable_cell_from_local_position(local_position)

func _get_visual_cell(local_position: Vector3) -> Vector2i:
	if terrain == null or terrain.map_data == null:
		return Vector2i(-1, -1)
	return terrain.get_visual_cell_from_local_position(local_position)

func _is_walkable_cell(cell: Vector2i) -> bool:
	if terrain == null or terrain.map_data == null:
		return false
	return terrain.map_data.get_walkable_value_for_visual_cell(cell) == TerrainMapData.Walkable.ALL

func _is_buildable_cell(cell: Vector2i) -> bool:
	if terrain == null or terrain.map_data == null:
		return false
	return terrain.map_data.get_buildable_value_for_visual_cell(cell) == TerrainMapData.Buildable.OPEN

func _validate_footprint(
		definition: EntityDefinition,
		local_position: Vector3,
		rotation_y: float,
		ignored_placement_index: int = -1
) -> RefCounted:
	var footprint_info := _get_footprint_info(definition.id)
	if not footprint_info.get("has_footprint", false):
		return null

	var cells := _get_footprint_cells(local_position, rotation_y, footprint_info)
	var playable_cell := _get_playable_cell(local_position)
	if cells.is_empty():
		return null
	for cell in cells:
		if not terrain.map_data.is_visual_cell_in_playable_area(cell):
			return PlacementValidationResultScript.invalid("Outside playable area", local_position, playable_cell)
		if definition.category == &"building" and not _is_buildable_cell(cell):
			return PlacementValidationResultScript.invalid("Requires buildable terrain", local_position, playable_cell)
		if _is_visual_cell_blocked_by_existing_placement(cell, ignored_placement_index):
			return PlacementValidationResultScript.invalid("Footprint blocked", local_position, playable_cell)
	return PlacementValidationResultScript.valid(local_position, playable_cell)

func _get_footprint_info(entity_id: StringName) -> Dictionary:
	if _footprint_info_cache.has(entity_id):
		return _footprint_info_cache[entity_id]
	var info := {
		"has_footprint": false,
		"shape": EntityFootprintComponent.Shape.CIRCLE,
		"radius": 0.0,
		"half_extents": Vector2.ZERO,
	}
	var definition: EntityDefinition = entity_catalog.get_definition(entity_id)
	if definition == null:
		_footprint_info_cache[entity_id] = info
		return info
	var entity := entity_catalog.spawn_entity(definition.id)
	if entity == null:
		_footprint_info_cache[entity_id] = info
		return info
	var footprint := _find_footprint(entity)
	if footprint != null:
		info["has_footprint"] = true
		info["shape"] = footprint.shape
		info["radius"] = footprint.radius
		info["half_extents"] = footprint.half_extents
	entity.free()
	_footprint_info_cache[entity_id] = info
	return info

func _find_footprint(root_node: Node) -> EntityFootprintComponent:
	if root_node is EntityFootprintComponent:
		return root_node as EntityFootprintComponent
	for child in root_node.get_children():
		var footprint := _find_footprint(child)
		if footprint != null:
			return footprint
	return null

func _get_footprint_cells(local_position: Vector3, rotation_y: float, footprint_info: Dictionary) -> Array[Vector2i]:
	if terrain == null or terrain.map_data == null:
		return []
	if footprint_info.get("shape", EntityFootprintComponent.Shape.CIRCLE) == EntityFootprintComponent.Shape.RECTANGLE:
		return _get_rectangle_footprint_cells(local_position, rotation_y, footprint_info.get("half_extents", Vector2.ONE))
	return _get_circle_footprint_cells(local_position, footprint_info.get("radius", 0.5))

func _get_circle_footprint_cells(local_position: Vector3, radius: float) -> Array[Vector2i]:
	var cell_size := terrain.map_data.cell_size
	var footprint_radius := maxf(radius, cell_size * 0.5)
	var epsilon := 0.001
	var min_cell := Vector2i(
		int(floor((local_position.x - footprint_radius) / cell_size)),
		int(floor((local_position.z - footprint_radius) / cell_size))
	)
	var max_cell := Vector2i(
		int(floor((local_position.x + footprint_radius - epsilon) / cell_size)),
		int(floor((local_position.z + footprint_radius - epsilon) / cell_size))
	)
	var cells: Array[Vector2i] = []
	for z in range(min_cell.y, max_cell.y + 1):
		for x in range(min_cell.x, max_cell.x + 1):
			cells.append(Vector2i(x, z))
	return cells

func _get_rectangle_footprint_cells(local_position: Vector3, rotation_y: float, half_extents: Vector2) -> Array[Vector2i]:
	var cell_size := terrain.map_data.cell_size
	var radius := half_extents.length()
	var min_cell := Vector2i(
		int(floor((local_position.x - radius) / cell_size)),
		int(floor((local_position.z - radius) / cell_size))
	)
	var max_cell := Vector2i(
		int(floor((local_position.x + radius) / cell_size)),
		int(floor((local_position.z + radius) / cell_size))
	)
	var cells: Array[Vector2i] = []
	for z in range(min_cell.y, max_cell.y + 1):
		for x in range(min_cell.x, max_cell.x + 1):
			var center := Vector2((float(x) + 0.5) * cell_size, (float(z) + 0.5) * cell_size)
			var offset := center - Vector2(local_position.x, local_position.z)
			var local_offset := offset.rotated(-rotation_y)
			if absf(local_offset.x) <= half_extents.x and absf(local_offset.y) <= half_extents.y:
				cells.append(Vector2i(x, z))
	return cells

func _is_visual_cell_blocked_by_existing_placement(cell: Vector2i, ignored_placement_index: int = -1) -> bool:
	return is_visual_cell_occupied(cell, ignored_placement_index)

func _get_cells_for_existing_placement(placement: EntityPlacementData, definition: EntityDefinition) -> Array[Vector2i]:
	var footprint_info := _get_footprint_info(definition.id)
	if not footprint_info.get("has_footprint", false):
		return [_get_visual_cell(placement.position)]
	return _get_footprint_cells(placement.position, placement.rotation_y, footprint_info)

func _get_cell_bounds(cells: Array[Vector2i]) -> Rect2i:
	if cells.is_empty():
		return Rect2i(Vector2i.ZERO, Vector2i.ONE)
	var min_cell := cells[0]
	var max_cell := cells[0]
	for cell in cells:
		min_cell.x = mini(min_cell.x, cell.x)
		min_cell.y = mini(min_cell.y, cell.y)
		max_cell.x = maxi(max_cell.x, cell.x)
		max_cell.y = maxi(max_cell.y, cell.y)
	return Rect2i(min_cell, max_cell - min_cell + Vector2i.ONE)

func _matches_placement_filter(placement: EntityPlacementData) -> bool:
	if placement == null:
		return false
	return placement_filter_entity_ids.is_empty() or placement_filter_entity_ids.has(placement.entity_id)

func _find_last_filtered_placement_index() -> int:
	if terrain == null or terrain.map_data == null:
		return -1
	for i in range(terrain.map_data.entity_placements.size() - 1, -1, -1):
		var placement := terrain.map_data.entity_placements[i] as EntityPlacementData
		if _matches_placement_filter(placement):
			return i
	return -1
