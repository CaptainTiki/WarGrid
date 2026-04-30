extends RefCounted
class_name MovementSpaceQuery

static func is_circle_space_clear(
		world_position: Vector3,
		radius: float,
		terrain: Terrain,
		ignore_entity: EntityBase = null
) -> bool:
	if terrain != null:
		if terrain.runtime_state != null:
			if not terrain.runtime_state.can_ground_unit_stand_at(world_position, radius):
				return false
		else:
			var local := terrain.to_local(world_position)
			if not terrain.is_ground_walkable_at_local_position(local):
				return false
	for node in _get_entity_footprints():
		var footprint := node as EntityFootprintComponent
		if footprint == null or not footprint.blocks_units:
			continue
		var entity := footprint.get_entity_parent()
		if entity == null or not is_instance_valid(entity) or entity == ignore_entity:
			continue
		if entity.is_queued_for_deletion() or (entity.has_method("is_alive") and not entity.is_alive()):
			continue
		if _does_circle_overlap_footprint(world_position, radius, entity.global_position, footprint):
			return false
	return true

static func find_nearest_open_position(
		origin: Vector3,
		radius: float,
		search_radius: float,
		terrain: Terrain,
		ignore_entity: EntityBase = null,
		search_step: float = 1.0
):
	var checked_origin := snap_world_position_to_terrain(origin, terrain)
	if is_circle_space_clear(checked_origin, radius, terrain, ignore_entity):
		return checked_origin

	var step := maxf(search_step, maxf(radius * 2.0, 0.25))
	var ring_radius := step
	while ring_radius <= search_radius + 0.001:
		var sample_count := maxi(8, int(ceil(TAU * ring_radius / step)))
		for i in range(sample_count):
			var angle := TAU * float(i) / float(sample_count)
			var candidate := origin + Vector3(cos(angle) * ring_radius, 0.0, sin(angle) * ring_radius)
			candidate = snap_world_position_to_terrain(candidate, terrain)
			if is_circle_space_clear(candidate, radius, terrain, ignore_entity):
				return candidate
		ring_radius += step
	return null

static func snap_world_position_to_terrain(world_position: Vector3, terrain: Terrain) -> Vector3:
	if terrain == null:
		return world_position
	var local := terrain.to_local(world_position)
	var height := terrain.get_height_at_local_position(local)
	return terrain.to_global(Vector3(local.x, height, local.z))

static func _get_entity_footprints() -> Array[Node]:
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null:
		return []
	return tree.get_nodes_in_group("entity_footprints")

static func _does_circle_overlap_footprint(
		position: Vector3,
		radius: float,
		other_position: Vector3,
		other_footprint: EntityFootprintComponent
) -> bool:
	if other_footprint.shape == EntityFootprintComponent.Shape.RECTANGLE:
		var min_x := other_position.x - other_footprint.half_extents.x
		var max_x := other_position.x + other_footprint.half_extents.x
		var min_z := other_position.z - other_footprint.half_extents.y
		var max_z := other_position.z + other_footprint.half_extents.y
		var closest_x := clampf(position.x, min_x, max_x)
		var closest_z := clampf(position.z, min_z, max_z)
		var delta := Vector2(position.x - closest_x, position.z - closest_z)
		return delta.length() < radius
	var delta := Vector2(position.x - other_position.x, position.z - other_position.z)
	return delta.length() < radius + other_footprint.radius
