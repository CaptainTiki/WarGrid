extends Node
class_name ProductionComponent

const EntityCatalogScript := preload("res://game/entities/catalog/entity_catalog.gd")
const ProductionOrderScript := preload("res://game/production/production_order.gd")

@export_node_path("Node3D") var entity_parent: NodePath
@export var available_recipes: Array[Resource] = []
@export var queue_limit: int = 5
@export var spawn_offset: Vector3 = Vector3(3.0, 0.0, 0.0)

var queue: Array = []
var active_order = null

var _entity_catalog := EntityCatalogScript.new()

func _process(delta: float) -> void:
	if active_order == null:
		_start_next_order()
		return
	active_order.remaining_time -= delta
	if active_order.remaining_time > 0.0:
		return
	var completed_order = active_order
	active_order = null
	_complete_order(completed_order)
	_start_next_order()

func can_queue_recipe(recipe: Resource) -> bool:
	if recipe == null:
		return false
	if not _has_recipe(recipe.id):
		return false
	if get_queue_count() >= queue_limit:
		return false
	return _can_afford(recipe.costs)

func queue_recipe(recipe: Resource) -> bool:
	if recipe == null:
		return false
	var recipe_name := _get_recipe_display_name(recipe)
	if not _has_recipe(recipe.id):
		print("Cannot queue %s: recipe unavailable." % recipe_name)
		return false
	if get_queue_count() >= queue_limit:
		print("Cannot queue %s: queue full." % recipe_name)
		return false
	if not _can_afford(recipe.costs):
		print("Cannot queue %s: insufficient resources." % recipe_name)
		return false
	if not _spend(recipe.costs):
		print("Cannot queue %s: insufficient resources." % recipe_name)
		return false
	queue.append(ProductionOrderScript.new(recipe))
	print("Queued %s." % recipe_name)
	if active_order == null:
		_start_next_order()
	return true

func queue_recipe_by_id(recipe_id: StringName) -> bool:
	return queue_recipe(get_recipe(recipe_id))

func cancel_order(index: int) -> bool:
	if index < 0 or index >= queue.size():
		return false
	queue.remove_at(index)
	return true

func get_queue_count() -> int:
	return queue.size() + (1 if active_order != null else 0)

func get_active_order():
	return active_order

func get_progress_ratio() -> float:
	if active_order == null:
		return 0.0
	return active_order.get_progress_ratio()

func get_recipe(recipe_id: StringName) -> Resource:
	for recipe in available_recipes:
		if recipe != null and recipe.id == recipe_id:
			return recipe
	return null

func _start_next_order() -> void:
	if active_order != null or queue.is_empty():
		return
	active_order = queue.pop_front()
	if active_order == null or active_order.recipe == null:
		active_order = null
		return
	print("Started production: %s." % _get_recipe_display_name(active_order.recipe))

func _complete_order(order) -> void:
	if order == null or order.recipe == null:
		return
	var recipe = order.recipe
	print("Production complete: %s." % _get_recipe_display_name(recipe))
	_spawn_produced_entity(recipe)

func _spawn_produced_entity(recipe: Resource) -> Node:
	if recipe.produced_entity_id == &"":
		push_warning("Production recipe %s has no produced_entity_id." % recipe.id)
		return null
	var entity := _entity_catalog.spawn_entity(recipe.produced_entity_id)
	if entity == null:
		push_warning("Production recipe %s produced unknown entity_id: %s" % [recipe.id, recipe.produced_entity_id])
		return null
	var producer := get_entity_parent()
	var spawn_parent := _get_spawn_parent(producer)
	spawn_parent.add_child(entity)
	if producer != null and "team_id" in producer and "team_id" in entity:
		entity.team_id = producer.team_id
	if entity is Node3D:
		var entity_3d := entity as Node3D
		if producer is Node3D:
			entity_3d.global_position = (producer as Node3D).global_position + spawn_offset
		else:
			entity_3d.global_position = spawn_offset
	var terrain := _find_level_terrain(spawn_parent)
	if terrain != null and entity.has_method("set_terrain"):
		entity.set_terrain(terrain)
	var team_id: int = entity.team_id if "team_id" in entity else 0
	print("Spawned %s for team %d." % [_get_entity_display_name(entity), team_id])
	return entity

func get_entity_parent() -> EntityBase:
	var entity := get_node_or_null(entity_parent) as EntityBase
	if entity != null:
		return entity
	var candidate := get_parent()
	while candidate != null:
		if candidate is EntityBase:
			return candidate
		candidate = candidate.get_parent()
	return null

func _get_spawn_parent(producer: EntityBase) -> Node:
	if producer != null and producer.get_parent() != null:
		return producer.get_parent()
	return get_tree().current_scene if get_tree().current_scene != null else get_tree().root

func _find_level_terrain(start: Node) -> Terrain:
	var current := start
	while current != null:
		if current.has_node("Terrain"):
			return current.get_node("Terrain") as Terrain
		current = current.get_parent()
	return null

func _has_recipe(recipe_id: StringName) -> bool:
	return get_recipe(recipe_id) != null

func _can_afford(costs: Dictionary) -> bool:
	var wallet := _get_resource_wallet()
	if wallet == null:
		return true
	return wallet.can_afford(costs)

func _spend(costs: Dictionary) -> bool:
	var wallet := _get_resource_wallet()
	if wallet == null:
		return true
	return wallet.spend(costs)

func _get_resource_wallet() -> Node:
	return get_node_or_null("/root/ResourceManager")

func _get_recipe_display_name(recipe: Resource) -> String:
	if recipe == null:
		return "Unknown Recipe"
	if recipe.display_name.strip_edges() != "":
		return recipe.display_name
	return String(recipe.id)

func _get_entity_display_name(entity: Node) -> String:
	if entity != null and "display_name" in entity and entity.display_name.strip_edges() != "":
		return entity.display_name
	return entity.name if entity != null else "Unknown Entity"
