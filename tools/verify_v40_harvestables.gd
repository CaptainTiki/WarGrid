extends SceneTree

const LevelScene := preload("res://level/level.tscn")
const EntityCatalogScript := preload("res://game/entities/catalog/entity_catalog.gd")
const EntityPlacementDataScript := preload("res://game/entities/placement/entity_placement_data.gd")
const TerrainMapDataScript := preload("res://terrain/terrain_map_data.gd")
const TerrainSerializerScript := preload("res://terrain/terrain_serializer.gd")
const TrainInfantryRecipe := preload("res://game/production/recipes/train_infantry.tres")

const TEMP_MAP_PATH := "res://tools/v40_harvestables_temp.res"

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
	_verify_resources()
	_verify_catalog_and_harvestables()
	_verify_map_spawn_and_scan()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(TEMP_MAP_PATH))

	if _failures == 0:
		print("v40 harvestables verification passed.")
		quit(0)
	else:
		push_error("v40 harvestables verification failed with %d failure(s)." % _failures)
		quit(1)

func _verify_resources() -> void:
	var wallet := root.get_node_or_null("ResourceManager")
	_expect(wallet != null, "ResourceManager autoload exists")
	if wallet != null:
		wallet.reset_to_starting_resources()
		_expect(wallet.get_amount(&"crystals") == 500, "starting crystals is 500")
		_expect(wallet.get_amount(&"he3") == 0, "starting he3 is 0")
		_expect(wallet.get_amount(&"ore") == 0, "old ore resource is not seeded")
		_expect(wallet.can_afford({&"crystals": 50}), "wallet can afford crystals cost")
		_expect(wallet.spend({&"crystals": 50}), "wallet spends crystals")
		_expect(wallet.get_amount(&"crystals") == 450, "crystals decrease after spend")
		wallet.reset_to_starting_resources()
	_expect(TrainInfantryRecipe.costs.has(&"crystals"), "train_infantry costs crystals")
	_expect(not TrainInfantryRecipe.costs.has(&"ore"), "train_infantry has no ore cost")

func _verify_catalog_and_harvestables() -> void:
	var catalog := EntityCatalogScript.new()
	_expect(catalog.has_definition(&"tritanium_crystal_node"), "catalog has tritanium_crystal_node")
	_expect(catalog.has_definition(&"he3_deposit"), "catalog has he3_deposit")
	_expect(catalog.spawn_entity(&"missing_test_entity") == null, "missing catalog entity returns null")

	var crystal := catalog.spawn_entity(&"tritanium_crystal_node") as EntityBase
	_expect(crystal != null, "catalog spawns crystal node")
	if crystal != null:
		_expect(crystal.team_id == 0, "crystal node is neutral")
		_expect(crystal.get_available_commands().is_empty(), "crystal node is not commandable")
		var harvestable := crystal.get_component(&"HarvestableComponent") as HarvestableComponent
		_expect(harvestable != null, "crystal has HarvestableComponent")
		if harvestable != null:
			_expect(harvestable.get_resource_id() == &"crystals", "crystal resource id is crystals")
			_expect(harvestable.has_resources(), "crystal reports resources")
			_expect(harvestable.can_harvest(), "crystal is directly harvestable metadata")
			_expect(harvestable.allow_multiple_workers, "crystal allows multiple workers")
			_expect(harvestable.harvest_amount(10) == 10, "crystal harvest returns requested load")
			_expect(harvestable.get_remaining_amount() == 140, "crystal harvest reduces remaining")
			var depleted_emitted := false
			harvestable.depleted.connect(func(_node): depleted_emitted = true)
			_expect(harvestable.harvest_amount(999) == 140, "crystal harvest clamps to remaining")
			_expect(harvestable.get_remaining_amount() == 0, "crystal reaches zero")
			_expect(harvestable.is_depleted(), "crystal marks depleted")
			_expect(depleted_emitted, "crystal emits depleted")
		crystal.free()

	var he3 := catalog.spawn_entity(&"he3_deposit") as EntityBase
	_expect(he3 != null, "catalog spawns he3 deposit")
	if he3 != null:
		_expect(he3.team_id == 0, "he3 deposit is neutral")
		_expect(he3.get_available_commands().is_empty(), "he3 deposit is not commandable")
		var harvestable := he3.get_component(&"HarvestableComponent") as HarvestableComponent
		_expect(harvestable != null, "he3 has HarvestableComponent")
		if harvestable != null:
			_expect(harvestable.get_resource_id() == &"he3", "he3 resource id is he3")
			_expect(harvestable.requires_extractor, "he3 requires extractor")
			_expect(not harvestable.allow_multiple_workers, "he3 does not allow multiple workers")
			_expect(harvestable.worker_slot_limit == 1, "he3 worker slot limit is one")
			_expect(not harvestable.can_harvest(), "he3 is not directly harvestable")
			_expect(harvestable.harvest_amount(10) == 0, "he3 direct harvest returns zero")
		he3.free()

func _verify_map_spawn_and_scan() -> void:
	var map_data = TerrainMapDataScript.new()
	map_data.create_flat_grass_map(Vector2i(2, 2), 0.0)
	map_data.entity_placements = [
		_make_placement(&"tritanium_crystal_node", Vector3(126.0, 0.0, 128.0), 0),
		_make_placement(&"tritanium_crystal_node", Vector3(128.0, 0.0, 128.0), 0),
		_make_placement(&"he3_deposit", Vector3(132.0, 0.0, 128.0), 0),
	]
	_expect(TerrainSerializerScript.save(map_data, TEMP_MAP_PATH, "v40 Harvestables"), "temporary harvestable map saves")
	var reloaded = TerrainSerializerScript.load(TEMP_MAP_PATH)
	_expect(reloaded != null, "temporary harvestable map reloads")
	if reloaded != null:
		_expect(reloaded.entity_placements.size() == 3, "reload preserves harvestable placements")
		_expect(reloaded.entity_placements[0].entity_id == &"tritanium_crystal_node", "reload preserves crystal id")
		_expect(reloaded.entity_placements[2].entity_id == &"he3_deposit", "reload preserves he3 id")

	var level = LevelScene.instantiate()
	root.add_child(level)
	_expect(level.load_map(TEMP_MAP_PATH), "level loads harvestable map")
	var entities_root: Node = level.get_node("Entities")
	_expect(entities_root.get_child_count() == 3, "runtime spawns harvestable placements")
	var crystal := _find_entity_with_component(entities_root, &"crystals")
	var he3 := _find_entity_with_component(entities_root, &"he3")
	_expect(crystal != null, "runtime crystal spawned")
	_expect(he3 != null, "runtime he3 spawned")
	var panel: CommandPanel = level.get_node("UI/CommandPanel")
	if crystal != null:
		panel.set_selected_entities([crystal])
		_expect(panel.get_node("SelectedEntityLabel").text == "Tritanium Crystal", "crystal scan shows name")
		_expect(panel.get_node("StatusLabel").text == "Status: Neutral / Resource", "crystal scan shows resource status")
		_expect(panel.get_node("HealthLabel").text.contains("Resource: Crystals"), "crystal scan shows resource type")
		_expect(panel.get_node("HealthLabel").text.contains("Remaining: 150 / 150"), "crystal scan shows remaining")
		_expect(panel.get_node("CommandScroll/CommandList").get_child_count() == 0, "crystal scan has no command buttons")
	if he3 != null:
		panel.set_selected_entities([he3])
		_expect(panel.get_node("SelectedEntityLabel").text == "Helium-3 Deposit", "he3 scan shows name")
		_expect(panel.get_node("HealthLabel").text.contains("Resource: He3"), "he3 scan shows resource type")
		_expect(panel.get_node("HealthLabel").text.contains("Requires Extractor: Yes"), "he3 scan shows extractor requirement")
		_expect(panel.get_node("CommandScroll/CommandList").get_child_count() == 0, "he3 scan has no command buttons")
	level.free()

func _make_placement(entity_id: StringName, position: Vector3, team_id: int) -> Resource:
	var placement = EntityPlacementDataScript.new()
	placement.entity_id = entity_id
	placement.position = position
	placement.team_id = team_id
	return placement

func _find_entity_with_component(parent: Node, resource_id: StringName) -> EntityBase:
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
