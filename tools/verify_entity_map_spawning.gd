extends SceneTree

const LevelScene := preload("res://level/level.tscn")
const EntityCatalogScript := preload("res://game/entities/catalog/entity_catalog.gd")
const EntityPlacementDataScript := preload("res://game/entities/placement/entity_placement_data.gd")

const MAP_PATH := "res://levels/test_map/map_data.res"

var _failures := 0
var _ran := false

func _process(_delta: float) -> bool:
	if _ran:
		return false
	_ran = true
	_run()
	return true

func _run() -> void:
	var catalog = EntityCatalogScript.new()
	for entity_id in [&"infantry", &"scout_bike", &"scout_buggy", &"test_hq", &"enemy_test_hq", &"enemy_dummy_unit"]:
		_expect(catalog.has_definition(entity_id), "catalog has %s" % entity_id)
		var catalog_entity = catalog.spawn_entity(entity_id)
		_expect(catalog_entity != null, "catalog spawns %s" % entity_id)
		if catalog_entity != null:
			catalog_entity.free()
	_expect(catalog.spawn_entity(&"missing_test_entity") == null, "missing catalog entity returns null")

	var level = LevelScene.instantiate()
	root.add_child(level)
	_expect(level.load_map(MAP_PATH), "level loads map")
	var entities_root: Node = level.get_node("Entities")
	_expect(entities_root.get_child_count() == 6, "map spawns six known entities")

	_expect(_find_entity(entities_root, "Infantry", 1) != null, "infantry spawned as player")
	_expect(_find_entity(entities_root, "Test HQ", 1) != null, "test hq spawned as player")
	_expect(_find_entity(entities_root, "Enemy Test HQ", 2) != null, "enemy test hq spawned as enemy")
	_expect(_find_entity(entities_root, "Enemy Dummy Unit", 2) != null, "enemy dummy unit spawned as enemy")

	var scout_bike = _find_entity(entities_root, "Scout Bike", 1)
	_expect(_has_health(scout_bike, 90.0, 120.0), "percent health placement applied to scout bike")
	var scout_buggy = _find_entity(entities_root, "Scout Buggy", 1)
	_expect(_has_health(scout_buggy, 90.0, 180.0), "current-value health placement applied to scout buggy")

	var fake = EntityPlacementDataScript.new()
	fake.entity_id = &"missing_test_entity"
	fake.position = Vector3.ZERO
	fake.team_id = 2
	level.terrain.map_data.entity_placements.append(fake)
	level._clear_spawned_entities()
	level._spawn_map_entities()
	_expect(entities_root.get_child_count() == 6, "missing map entity id is skipped safely")

	level.free()
	if _failures == 0:
		print("Entity map spawning verification passed.")
		quit(0)
	else:
		push_error("Entity map spawning verification failed with %d failure(s)." % _failures)
		quit(1)

func _find_entity(root_node: Node, display_name: String, team_id: int) -> EntityBase:
	for child in root_node.get_children():
		var entity := child as EntityBase
		if entity != null and entity.display_name == display_name and entity.team_id == team_id:
			return entity
	return null

func _has_health(entity: EntityBase, current_health: float, max_health: float) -> bool:
	if entity == null:
		return false
	var health := entity.get_health_component() as HealthComponent
	if health == null:
		return false
	return is_equal_approx(health.current_health, current_health) and is_equal_approx(health.max_health, max_health)

func _expect(condition: bool, message: String) -> void:
	if condition:
		print("PASS: %s" % message)
	else:
		_failures += 1
		push_error("FAIL: %s" % message)
