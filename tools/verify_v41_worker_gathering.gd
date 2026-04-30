extends SceneTree

const LevelScene := preload("res://level/level.tscn")
const EntityCatalogScript := preload("res://game/entities/catalog/entity_catalog.gd")
const EntityPlacementDataScript := preload("res://game/entities/placement/entity_placement_data.gd")
const TerrainMapDataScript := preload("res://terrain/terrain_map_data.gd")
const TerrainSerializerScript := preload("res://terrain/terrain_serializer.gd")
const TrainWorkerRecipe := preload("res://game/production/recipes/train_worker.tres")

const TEMP_MAP_PATH := "res://tools/v41_worker_gathering_temp.res"

var _failures := 0
var _ran := false

func _initialize() -> void:
	if _ran:
		return
	_ran = true
	_run()

func _process(_delta: float) -> bool:
	if _ran:
		return false
	_ran = true
	_run()
	return true

func _run() -> void:
	var wallet := root.get_node_or_null("ResourceManager")
	if wallet != null:
		wallet.reset_to_starting_resources()

	_verify_catalog_and_recipe()
	_verify_runtime_spawn_and_gather(wallet)
	_verify_production(wallet)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(TEMP_MAP_PATH))

	if _failures == 0:
		print("v41 worker gathering verification passed.")
		quit(0)
	else:
		push_error("v41 worker gathering verification failed with %d failure(s)." % _failures)
		quit(1)

func _verify_catalog_and_recipe() -> void:
	var catalog := EntityCatalogScript.new()
	_expect(catalog.has_definition(&"worker"), "catalog has worker")
	var worker := catalog.spawn_entity(&"worker") as EntityBase
	_expect(worker != null, "catalog spawns worker")
	if worker != null:
		_expect(worker.display_name == "Worker", "worker display name is Worker")
		_expect(worker.has_command(&"move"), "worker has move command")
		_expect(worker.has_command(&"stop"), "worker has stop command")
		_expect(worker.has_command(&"gather"), "worker has gather command")
		_expect(worker.get_component(&"WorkerGatherComponent") != null, "worker has WorkerGatherComponent")
		worker.free()
	_expect(TrainWorkerRecipe.id == &"train_worker", "train_worker recipe exists")
	_expect(TrainWorkerRecipe.produced_entity_id == &"worker", "train_worker produces worker")
	_expect(TrainWorkerRecipe.costs.has(&"crystals"), "train_worker costs crystals")
	_expect(not TrainWorkerRecipe.costs.has(&"ore"), "train_worker has no ore cost")

func _verify_runtime_spawn_and_gather(wallet: Node) -> void:
	if wallet != null:
		wallet.reset_to_starting_resources()
	var level := _make_level([
		_make_placement(&"test_hq", Vector3(124.0, 0.0, 128.0), 1),
		_make_placement(&"worker", Vector3(128.0, 0.0, 128.0), 1),
		_make_placement(&"worker", Vector3(128.0, 0.0, 130.0), 1),
		_make_placement(&"tritanium_crystal_node", Vector3(132.0, 0.0, 128.0), 0),
		_make_placement(&"he3_deposit", Vector3(132.0, 0.0, 132.0), 0),
	])
	var entities_root: Node = level.get_node("Entities")
	_expect(entities_root.get_child_count() == 5, "runtime spawns worker/resource placements")
	var workers := _find_entities_by_name(entities_root, "Worker")
	var crystal := _find_entity_with_resource(entities_root, &"crystals")
	var he3 := _find_entity_with_resource(entities_root, &"he3")
	_expect(workers.size() == 2, "runtime spawns two workers")
	_expect(crystal != null, "runtime spawns crystal")
	_expect(he3 != null, "runtime spawns he3")

	if not workers.is_empty() and crystal != null:
		var worker := workers[0]
		var crystal_harvestable := crystal.get_component(&"HarvestableComponent") as HarvestableComponent
		_expect(worker.execute_command(&"gather", {"target_entity": crystal}), "worker accepts crystal gather command")
		_advance_entities(entities_root, 5.0)
		_expect(crystal_harvestable.get_remaining_amount() < 150, "crystal amount decreases after worker harvest")
		_expect(wallet == null or wallet.get_amount(&"crystals") > 500, "worker deposits crystals into wallet")
		var gather := worker.get_component(&"WorkerGatherComponent") as WorkerGatherComponent
		_expect(gather != null and gather.get_cargo_text().begins_with("Cargo:"), "worker cargo UI helper reports empty after deposit cycle")

	if not workers.is_empty() and he3 != null:
		_expect(not workers[0].execute_command(&"gather", {"target_entity": he3}), "worker rejects he3 gather for now")

	if workers.size() >= 2 and crystal != null:
		var before := (crystal.get_component(&"HarvestableComponent") as HarvestableComponent).get_remaining_amount()
		_expect(workers[0].execute_command(&"gather", {"target_entity": crystal}), "first worker accepts shared crystal")
		_expect(workers[1].execute_command(&"gather", {"target_entity": crystal}), "second worker accepts shared crystal")
		_advance_entities(entities_root, 5.0)
		var after := (crystal.get_component(&"HarvestableComponent") as HarvestableComponent).get_remaining_amount()
		_expect(after <= before - 20, "multiple workers reduce shared crystal by at least two loads")

	if not workers.is_empty() and crystal != null:
		var worker := workers[0]
		var harvestable := crystal.get_component(&"HarvestableComponent") as HarvestableComponent
		harvestable.remaining_amount = 10
		harvestable.depleted_state = false
		_expect(worker.execute_command(&"gather", {"target_entity": crystal}), "worker accepts nearly depleted crystal")
		_advance_entities(entities_root, 5.0)
		_expect(harvestable.get_remaining_amount() == 0, "crystal can be harvested to zero")
		_expect(harvestable.is_depleted(), "crystal marks depleted safely")

	if not workers.is_empty():
		var worker := workers[0]
		var far_crystal := _spawn_catalog_entity(level, &"tritanium_crystal_node", Vector3(140.0, 0.0, 128.0), 0)
		var harvestable := far_crystal.get_component(&"HarvestableComponent") as HarvestableComponent
		_expect(worker.execute_command(&"gather", {"target_entity": far_crystal}), "worker starts gather before stop")
		_expect(worker.execute_command(&"stop", {}), "stop command succeeds during gather")
		_advance_entities(entities_root, 2.0)
		_expect(harvestable.get_remaining_amount() == 150, "stop prevents later harvest")

		_expect(worker.execute_command(&"gather", {"target_entity": far_crystal}), "worker starts gather before move")
		_expect(worker.execute_command(&"move", {"target_position": Vector3(126.0, 0.0, 124.0), "terrain": level.terrain}), "move command succeeds during gather")
		var gather := worker.get_component(&"WorkerGatherComponent") as WorkerGatherComponent
		_expect(gather.current_target == null, "move clears gather target")

	level.free()

func _verify_production(wallet: Node) -> void:
	if wallet != null:
		wallet.reset_to_starting_resources()
	var level := _make_level([
		_make_placement(&"test_hq", Vector3(128.0, 0.0, 128.0), 1),
	])
	var entities_root: Node = level.get_node("Entities")
	var hq := _find_entity_by_display_name(entities_root, "Test HQ")
	_expect(hq != null, "player HQ spawned for worker production")
	if hq != null:
		_expect(hq.has_command(&"train_worker"), "HQ exposes train worker command")
		var production := hq.get_component(&"ProductionComponent") as ProductionComponent
		_expect(production != null and production.get_recipe(&"train_worker") == TrainWorkerRecipe, "HQ has train_worker recipe")
		_expect(hq.execute_command(&"set_rally_point", {"target_position": Vector3(136.0, 0.0, 128.0), "terrain": level.terrain}), "HQ rally point set")
		_expect(hq.execute_command(&"train_worker", {}), "HQ queues worker production")
		_expect(wallet == null or wallet.get_amount(&"crystals") == 450, "train_worker spends crystals")
		_advance_entities(entities_root, 4.0)
		var worker := _find_entity_by_display_name(entities_root, "Worker")
		_expect(worker != null, "production spawns worker")
		if worker != null:
			_expect(worker.team_id == 1, "produced worker inherits team")
			var movement := worker.get_component(&"MovementComponent") as MovementComponent
			_expect(movement != null and movement.has_path(), "produced worker receives rally move")
	level.free()

func _advance_entities(entities_root: Node, seconds: float) -> void:
	var elapsed := 0.0
	while elapsed < seconds:
		for entity in entities_root.get_children():
			if entity == null or not is_instance_valid(entity):
				continue
			var production := entity.get_component(&"ProductionComponent") if entity is EntityBase else null
			if production != null:
				production._process(0.1)
			var movement := entity.get_component(&"MovementComponent") if entity is EntityBase else null
			if movement != null:
				movement._process(0.1)
			var gather := entity.get_component(&"WorkerGatherComponent") if entity is EntityBase else null
			if gather != null:
				gather._process(0.1)
		elapsed += 0.1

func _make_level(placements: Array) -> Level:
	var map_data = TerrainMapDataScript.new()
	map_data.create_flat_grass_map(Vector2i(2, 2), 0.0)
	map_data.entity_placements = placements
	_expect(TerrainSerializerScript.save(map_data, TEMP_MAP_PATH, "v41 Worker Gathering"), "temporary v41 map saves")
	var level = LevelScene.instantiate()
	root.add_child(level)
	_expect(level.load_map(TEMP_MAP_PATH), "level loads temporary v41 map")
	return level

func _make_placement(entity_id: StringName, position: Vector3, team_id: int) -> Resource:
	var placement = EntityPlacementDataScript.new()
	placement.entity_id = entity_id
	placement.position = position
	placement.team_id = team_id
	return placement

func _spawn_catalog_entity(level: Level, entity_id: StringName, position: Vector3, team_id: int) -> EntityBase:
	var catalog := EntityCatalogScript.new()
	var entity := catalog.spawn_entity(entity_id) as EntityBase
	level.get_node("Entities").add_child(entity)
	entity.team_id = team_id
	entity.global_position = position
	if entity.has_method("set_terrain"):
		entity.set_terrain(level.terrain)
	return entity

func _find_entities_by_name(parent: Node, display_name: String) -> Array[EntityBase]:
	var matches: Array[EntityBase] = []
	for child in parent.get_children():
		var entity := child as EntityBase
		if entity != null and entity.display_name == display_name:
			matches.append(entity)
	return matches

func _find_entity_by_display_name(parent: Node, display_name: String) -> EntityBase:
	for child in parent.get_children():
		var entity := child as EntityBase
		if entity != null and entity.display_name == display_name:
			return entity
	return null

func _find_entity_with_resource(parent: Node, resource_id: StringName) -> EntityBase:
	for child in parent.get_children():
		var entity := child as EntityBase
		if entity == null:
			continue
		var harvestable := entity.get_component(&"HarvestableComponent") as HarvestableComponent
		if harvestable != null and harvestable.get_resource_id() == resource_id:
			return entity
	return null

func _expect(condition: bool, message: String) -> void:
	if condition:
		print("PASS: %s" % message)
	else:
		_failures += 1
		push_error("FAIL: %s" % message)
