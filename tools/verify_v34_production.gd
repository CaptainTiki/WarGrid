extends SceneTree

const EntityCatalogScript := preload("res://game/entities/catalog/entity_catalog.gd")
const TestHQScene := preload("res://game/entities/buildings/test_hq/test_hq.tscn")
const TrainInfantryRecipe := preload("res://game/production/recipes/train_infantry.tres")

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
	var catalog := EntityCatalogScript.new()
	_expect(TrainInfantryRecipe.id == &"train_infantry", "train_infantry recipe exists")
	_expect(TrainInfantryRecipe.produced_entity_id == &"infantry", "recipe produces infantry entity id")
	_expect(catalog.has_definition(TrainInfantryRecipe.produced_entity_id), "produced entity resolves through EntityCatalog")

	var wallet := root.get_node_or_null("ResourceManager")
	_expect(wallet != null, "ResourceManager autoload exists")
	if wallet != null:
		wallet.reset_to_starting_resources()
		_expect(wallet.get_amount(&"ore") == 500, "starting ore is 500")
		_expect(wallet.can_afford({&"ore": 50}), "wallet can afford infantry")
		_expect(wallet.spend({&"ore": 50}), "wallet spends ore")
		_expect(wallet.get_amount(&"ore") == 450, "ore decreases after spend")
		_expect(not wallet.can_afford({&"ore": 999}), "wallet detects insufficient resources")
		wallet.reset_to_starting_resources()

	var entities := Node3D.new()
	entities.name = "Entities"
	root.add_child(entities)

	var hq = TestHQScene.instantiate()
	entities.add_child(hq)
	hq.team_id = 1

	var production := hq.get_component(&"ProductionComponent")
	_expect(production != null, "player TestHQ has ProductionComponent")
	_expect(production.get_recipe(&"train_infantry") == TrainInfantryRecipe, "TestHQ has train_infantry recipe")
	_expect(hq.has_command(&"train_infantry"), "player TestHQ exposes Train Infantry command")

	var queued: bool = hq.execute_command(&"train_infantry", {})
	_expect(queued, "Train Infantry command queues production")
	_expect(wallet.get_amount(&"ore") == 450, "queue spends ore")
	_expect(production.get_active_order() != null, "queued item starts active order")

	_advance_production(production, 3.2)
	var spawned := _find_child_by_name(entities, "Infantry")
	_expect(spawned != null, "production spawns infantry")
	_expect(spawned != null and spawned.team_id == 1, "spawned infantry inherits team 1")
	_expect(spawned != null and spawned.has_command(&"move"), "spawned infantry is commandable")
	_expect(spawned != null and spawned.has_command(&"attack"), "spawned infantry can attack")

	var hq_queue = TestHQScene.instantiate()
	entities.add_child(hq_queue)
	hq_queue.team_id = 1
	var queue_production := hq_queue.get_component(&"ProductionComponent")
	wallet.reset_to_starting_resources()
	for i in range(5):
		_expect(hq_queue.execute_command(&"train_infantry", {}), "queue accepts order %d" % (i + 1))
	_expect(queue_production.get_queue_count() == 5, "queue count reaches limit")
	_expect(not hq_queue.execute_command(&"train_infantry", {}), "queue limit rejects extra order")

	var hq_poor = TestHQScene.instantiate()
	entities.add_child(hq_poor)
	hq_poor.team_id = 1
	wallet.reset_to_starting_resources()
	_expect(wallet.spend({&"ore": 480}), "test spends ore down below recipe cost")
	_expect(not hq_poor.execute_command(&"train_infantry", {}), "insufficient resources fail cleanly")

	if _failures == 0:
		print("v34 production verification passed.")
		quit(0)
	else:
		push_error("v34 production verification failed with %d failure(s)." % _failures)
		quit(1)

func _advance_production(production: Node, seconds: float) -> void:
	var elapsed := 0.0
	while elapsed < seconds:
		production._process(0.1)
		elapsed += 0.1

func _find_child_by_name(parent: Node, child_name: String) -> Node:
	for child in parent.get_children():
		if child.name == child_name:
			return child
	return null

func _expect(condition: bool, message: String) -> void:
	if condition:
		print("PASS: %s" % message)
	else:
		_failures += 1
		push_error("FAIL: %s" % message)
