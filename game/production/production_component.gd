extends Node
class_name ProductionComponent

const EntityCatalogScript := preload("res://game/entities/catalog/entity_catalog.gd")
const ProductionOrderScript := preload("res://game/production/production_order.gd")
const MovementSpaceQueryScript := preload("res://game/entities/movement/movement_space_query.gd")

signal production_changed

@export_node_path("Node3D") var entity_parent: NodePath
@export var available_recipes: Array[Resource] = []
@export var queue_limit: int = 5
@export var spawn_offset: Vector3 = Vector3(3.0, 0.0, 0.0)
@export var spawn_search_radius: float = 8.0
@export var spawn_search_step: float = 1.0

var queue: Array = []
var active_order = null
var rally_point: Vector3 = Vector3.ZERO
var has_rally_point := false

var _entity_catalog := EntityCatalogScript.new()
var _last_progress_ratio := -1.0

func _process(delta: float) -> void:
	if active_order == null:
		_start_next_order()
		return
	active_order.remaining_time -= delta
	_emit_progress_changed_if_needed()
	if active_order.remaining_time > 0.0:
		return
	var completed_order = active_order
	active_order = null
	_complete_order(completed_order)
	_start_next_order()
	production_changed.emit()

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
	production_changed.emit()
	return true

func queue_recipe_by_id(recipe_id: StringName) -> bool:
	return queue_recipe(get_recipe(recipe_id))

func cancel_order(index: int) -> bool:
	if index < 0 or index >= queue.size():
		return false
	queue.remove_at(index)
	production_changed.emit()
	return true

func get_queue_count() -> int:
	return queue.size() + (1 if active_order != null else 0)

func get_active_order():
	return active_order

func get_progress_ratio() -> float:
	if active_order == null:
		return 0.0
	return active_order.get_progress_ratio()

func get_queued_orders() -> Array:
	return queue.duplicate()

func get_available_recipes() -> Array:
	return available_recipes.duplicate()

func set_rally_point(target_position: Vector3) -> void:
	rally_point = target_position
	has_rally_point = true
	print("Rally point set to %s." % rally_point)
	production_changed.emit()

func clear_rally_point() -> void:
	has_rally_point = false
	production_changed.emit()

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
	_last_progress_ratio = -1.0
	print("Started production: %s." % _get_recipe_display_name(active_order.recipe))
	production_changed.emit()

func _complete_order(order) -> void:
	if order == null or order.recipe == null:
		return
	var recipe = order.recipe
	print("Production complete: %s." % _get_recipe_display_name(recipe))
	_spawn_produced_entity(recipe)

func _spawn_produced_entity(recipe: Resource) -> Node:
	if recipe.produced_entity_id == &"":
		push_warning("Production recipe %s has no produced_entity_id." % recipe.id)
		_refund(recipe.costs)
		return null
	var entity := _entity_catalog.spawn_entity(recipe.produced_entity_id)
	if entity == null:
		push_warning("Production recipe %s produced unknown entity_id: %s" % [recipe.id, recipe.produced_entity_id])
		_refund(recipe.costs)
		return null
	var producer := get_entity_parent()
	var spawn_parent := _get_spawn_parent(producer)
	var terrain := _find_level_terrain(spawn_parent)
	var spawn_origin := spawn_offset
	if producer is Node3D:
		spawn_origin = (producer as Node3D).global_position + spawn_offset
	var unit_radius := _get_entity_spawn_radius(entity)
	var spawn_position = find_nearest_open_spawn_position(spawn_origin, unit_radius, spawn_search_radius, terrain)
	if spawn_position == null:
		push_warning("Production recipe %s could not find an open spawn position; refunded resources." % recipe.id)
		_refund(recipe.costs)
		entity.free()
		return null
	spawn_parent.add_child(entity)
	if producer != null and "team_id" in producer and "team_id" in entity:
		entity.team_id = producer.team_id
	if entity is Node3D:
		var entity_3d := entity as Node3D
		entity_3d.global_position = spawn_position
	if terrain != null and entity.has_method("set_terrain"):
		entity.set_terrain(terrain)
	if has_rally_point and entity.has_command(&"move") and terrain != null:
		entity.execute_command(&"move", {
			"target_position": rally_point,
			"terrain": terrain,
		})
	var team_id: int = entity.team_id if "team_id" in entity else 0
	print("Spawned %s for team %d." % [_get_entity_display_name(entity), team_id])
	return entity

func find_nearest_open_spawn_position(
		origin: Vector3,
		unit_radius: float,
		search_radius: float,
		terrain: Terrain = null
):
	return MovementSpaceQueryScript.find_nearest_open_position(
		origin,
		unit_radius,
		search_radius,
		terrain,
		null,
		spawn_search_step
	)

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

func _refund(costs: Dictionary) -> void:
	var wallet := _get_resource_wallet()
	if wallet == null:
		return
	for resource_id in costs.keys():
		if wallet.has_method("add_resource"):
			wallet.add_resource(resource_id, int(costs[resource_id]))

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

func _get_entity_spawn_radius(entity: Node) -> float:
	if entity == null or not entity.has_method("get_footprint_component"):
		return 0.5
	var footprint: Node = entity.get_footprint_component()
	if footprint == null:
		return 0.5
	if footprint.has_method("get_separation_radius"):
		return maxf(footprint.get_separation_radius(), 0.1)
	return 0.5

func _emit_progress_changed_if_needed() -> void:
	var progress := get_progress_ratio()
	if absf(progress - _last_progress_ratio) < 0.01:
		return
	_last_progress_ratio = progress
	production_changed.emit()
