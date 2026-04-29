extends Resource
class_name EntityCatalog

const EntityDefinitionScript := preload("res://game/entities/catalog/entity_definition.gd")

const DEFINITIONS := {
	&"infantry": {
		"display_name": "Infantry",
		"scene": preload("res://game/entities/units/infantry/infantry.tscn"),
		"category": &"unit",
		"default_team_id": 1,
	},
	&"scout_bike": {
		"display_name": "Scout Bike",
		"scene": preload("res://game/entities/units/scout_bike/scout_bike.tscn"),
		"category": &"unit",
		"default_team_id": 1,
	},
	&"scout_buggy": {
		"display_name": "Scout Buggy",
		"scene": preload("res://game/entities/units/scout_buggy/scout_buggy.tscn"),
		"category": &"unit",
		"default_team_id": 1,
	},
	&"test_hq": {
		"display_name": "Test HQ",
		"scene": preload("res://game/entities/buildings/test_hq/test_hq.tscn"),
		"category": &"building",
		"default_team_id": 1,
	},
	&"enemy_test_hq": {
		"display_name": "Enemy Test HQ",
		"scene": preload("res://game/entities/buildings/hostile_dummy/hostile_dummy_building.tscn"),
		"category": &"building",
		"default_team_id": 2,
	},
	&"enemy_dummy_unit": {
		"display_name": "Enemy Dummy Unit",
		"scene": preload("res://game/entities/units/hostile_dummy/hostile_dummy_unit.tscn"),
		"category": &"unit",
		"default_team_id": 2,
	},
}

func get_definition(entity_id: StringName) -> Resource:
	if not DEFINITIONS.has(entity_id):
		return null
	var data: Dictionary = DEFINITIONS[entity_id]
	var definition = EntityDefinitionScript.new()
	definition.id = entity_id
	definition.display_name = data.get("display_name", "")
	definition.scene = data.get("scene")
	definition.category = data.get("category", &"unit")
	definition.default_team_id = data.get("default_team_id", 1)
	return definition

func has_definition(entity_id: StringName) -> bool:
	return DEFINITIONS.has(entity_id)

func get_entity_ids() -> Array[StringName]:
	var ids: Array[StringName] = []
	for id in DEFINITIONS.keys():
		ids.append(id)
	return ids

func spawn_entity(entity_id: StringName) -> Node:
	var definition := get_definition(entity_id)
	if definition == null or definition.scene == null:
		return null
	var entity = definition.scene.instantiate()
	if entity != null:
		if "display_name" in entity and definition.display_name.strip_edges() != "":
			entity.display_name = definition.display_name
		if "team_id" in entity:
			entity.team_id = definition.default_team_id
	return entity
