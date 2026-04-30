extends RefCounted
class_name MovementQuery

static var _logged_blocked_cells: Dictionary = {}

static func is_direct_route_walkable(
		terrain: Terrain,
		start_world: Vector3,
		end_world: Vector3,
		sample_spacing: float = 1.0,
		radius: float = 0.0,
		ignore_entity: EntityBase = null
) -> bool:
	if terrain == null:
		return false

	var spacing: float = maxf(sample_spacing, 0.01)
	var distance: float = start_world.distance_to(end_world)
	var sample_count: int = maxi(1, int(ceil(distance / spacing)))

	for i in range(sample_count + 1):
		var t: float = float(i) / float(sample_count)
		var sample_world: Vector3 = start_world.lerp(end_world, t)
		if terrain.runtime_state != null:
			if not terrain.runtime_state.can_ground_unit_stand_at(sample_world, radius):
				var cell := terrain.runtime_state.world_to_cell(sample_world)
				if terrain.runtime_state.is_cell_occupied(cell) and not _logged_blocked_cells.has(cell):
					_logged_blocked_cells[cell] = true
					print("Path blocked by occupied cell %s." % cell)
				return false
		else:
			var sample_local: Vector3 = terrain.to_local(sample_world)
			if not terrain.is_ground_walkable_at_local_position(sample_local):
				return false
		if radius > 0.0 and not MovementSpaceQuery.is_circle_space_clear(sample_world, radius, terrain, ignore_entity):
			return false
	return true
