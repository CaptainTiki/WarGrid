extends RefCounted
class_name MovementQuery

static func is_direct_route_walkable(
		terrain: Terrain,
		start_world: Vector3,
		end_world: Vector3,
		sample_spacing: float = 1.0
) -> bool:
	if terrain == null:
		return false

	var spacing: float = maxf(sample_spacing, 0.01)
	var distance: float = start_world.distance_to(end_world)
	var sample_count: int = maxi(1, int(ceil(distance / spacing)))

	for i in range(sample_count + 1):
		var t: float = float(i) / float(sample_count)
		var sample_world: Vector3 = start_world.lerp(end_world, t)
		var sample_local: Vector3 = terrain.to_local(sample_world)
		if not terrain.is_ground_walkable_at_local_position(sample_local):
			return false
	return true
