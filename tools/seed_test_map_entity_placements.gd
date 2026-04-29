extends SceneTree

const TerrainSerializerScript := preload("res://terrain/terrain_serializer.gd")
const EntityPlacementDataScript := preload("res://game/entities/placement/entity_placement_data.gd")

const MAP_PATH := "res://levels/test_map/map_data.res"

func _process(_delta: float) -> bool:
	var map_data = TerrainSerializerScript.load(MAP_PATH)
	if map_data == null:
		quit(1)
		return false

	var total_size: Vector2 = map_data.get_total_size()
	var center := Vector3(total_size.x * 0.5, 0.0, total_size.y * 0.5)
	var placements: Array[Resource] = []
	placements.append(_make_placement(&"test_hq", center + Vector3(-7.0, 0.0, 0.0), 1))
	placements.append(_make_placement(&"infantry", center + Vector3(5.0, 0.0, 0.0), 1))
	placements.append(_make_placement(&"scout_bike", center + Vector3(5.0, 0.0, 5.0), 1, 0.0, EntityPlacementDataScript.HealthSpawnMode.PERCENT, 0.75))
	placements.append(_make_placement(&"scout_buggy", center + Vector3(5.0, 0.0, -5.0), 1, 0.0, EntityPlacementDataScript.HealthSpawnMode.CURRENT_VALUE, 90.0))
	placements.append(_make_placement(&"enemy_test_hq", center + Vector3(-14.0, 0.0, 0.0), 2))
	placements.append(_make_placement(&"enemy_dummy_unit", center + Vector3(-10.0, 0.0, 4.0), 2))
	map_data.entity_placements = placements

	var ok := TerrainSerializerScript.save(map_data, MAP_PATH, "Test Map")
	quit(0 if ok else 1)
	return false

func _make_placement(
		entity_id: StringName,
		position: Vector3,
		team_id: int,
		rotation_y: float = 0.0,
		health_spawn_mode: int = EntityPlacementDataScript.HealthSpawnMode.FULL,
		health_value: float = 1.0
) -> Resource:
	var placement = EntityPlacementDataScript.new()
	placement.entity_id = entity_id
	placement.position = position
	placement.rotation_y = rotation_y
	placement.team_id = team_id
	placement.health_spawn_mode = health_spawn_mode
	placement.health_value = health_value
	return placement
