extends Node
class_name WorkerGatherComponent

signal gather_changed

enum GatherState {
	IDLE,
	MOVING_TO_RESOURCE,
	HARVESTING,
	CARRYING,
	RETURNING,
	DEPOSITING,
}

@export_node_path("Node3D") var entity_parent: NodePath
@export var gather_range: float = 1.5
@export var harvest_time: float = 1.0
@export var carry_capacity: int = 10
@export var accepted_resource_ids: Array[StringName] = [&"crystals"]

var current_target: EntityBase = null
var carried_resource_id: StringName = &""
var carried_amount: int = 0
var state := GatherState.IDLE

var _harvest_timer := 0.0
var _drop_off: DropOffComponent = null
var _warned_missing_entity_parent := false

func _process(delta: float) -> void:
	match state:
		GatherState.MOVING_TO_RESOURCE:
			_process_moving_to_resource()
		GatherState.HARVESTING:
			_process_harvesting(delta)
		GatherState.CARRYING:
			_process_carrying()
		GatherState.RETURNING:
			_process_returning()

func get_entity_parent() -> EntityBase:
	var entity := get_node_or_null(entity_parent) as EntityBase
	if entity != null:
		return entity
	if not _warned_missing_entity_parent:
		push_warning("%s has no entity_parent assigned." % name)
		_warned_missing_entity_parent = true
	return null

func can_gather_target(target: EntityBase) -> bool:
	return _get_invalid_gather_reason(target) == ""

func get_invalid_gather_reason(target: EntityBase) -> String:
	return _get_invalid_gather_reason(target)

func start_gather(target: EntityBase) -> bool:
	var invalid_reason := _get_invalid_gather_reason(target)
	if invalid_reason != "":
		print("Gather failed: %s" % invalid_reason)
		return false
	current_target = target
	_harvest_timer = 0.0
	_drop_off = null
	var target_name := _get_entity_display_name(target)
	print("Worker accepted gather target %s." % target_name)
	if carried_amount > 0 and carried_resource_id != &"":
		state = GatherState.CARRYING
		gather_changed.emit()
		return true
	_move_to_resource()
	gather_changed.emit()
	return true

func cancel_gather(keep_cargo: bool = true) -> void:
	if state == GatherState.IDLE and current_target == null:
		return
	current_target = null
	_drop_off = null
	_harvest_timer = 0.0
	state = GatherState.IDLE
	if not keep_cargo:
		carried_resource_id = &""
		carried_amount = 0
	print("Gather canceled.")
	gather_changed.emit()

func get_cargo_text() -> String:
	if carried_amount <= 0 or carried_resource_id == &"":
		return "Cargo: Empty"
	return "Carrying: %d %s" % [carried_amount, _get_resource_display_name(carried_resource_id)]

func _process_moving_to_resource() -> void:
	if not _is_valid_target(current_target):
		cancel_gather()
		return
	if _is_in_range(current_target, gather_range):
		_start_harvesting()
		return
	var movement := _get_movement()
	if movement != null and not movement.has_move_target():
		_move_to_resource()

func _process_harvesting(delta: float) -> void:
	if not _is_valid_target(current_target):
		cancel_gather()
		return
	if not _is_in_range(current_target, gather_range):
		_move_to_resource()
		return
	_harvest_timer -= delta
	if _harvest_timer > 0.0:
		return
	var harvestable := _get_harvestable(current_target)
	if harvestable == null:
		cancel_gather()
		return
	var harvested := int(harvestable.harvest_amount(carry_capacity))
	if harvested <= 0:
		print("Gather failed: target has no remaining resources.")
		cancel_gather()
		return
	carried_resource_id = harvestable.get_resource_id()
	carried_amount = harvested
	print("Worker harvested %d %s. Remaining node amount: %d." % [
		harvested,
		_get_resource_display_name(carried_resource_id),
		harvestable.get_remaining_amount(),
	])
	state = GatherState.CARRYING
	gather_changed.emit()

func _process_carrying() -> void:
	_drop_off = _find_nearest_drop_off()
	if _drop_off == null:
		print("Worker carrying %d %s; no valid drop-off found." % [
			carried_amount,
			_get_resource_display_name(carried_resource_id),
		])
		state = GatherState.IDLE
		gather_changed.emit()
		return
	state = GatherState.RETURNING
	_move_to_drop_off()
	gather_changed.emit()

func _process_returning() -> void:
	if carried_amount <= 0:
		state = GatherState.IDLE
		gather_changed.emit()
		return
	if _drop_off == null or not is_instance_valid(_drop_off):
		_drop_off = _find_nearest_drop_off()
		if _drop_off == null:
			state = GatherState.CARRYING
			gather_changed.emit()
			return
	var drop_entity := _drop_off.get_entity_parent()
	if drop_entity == null or not is_instance_valid(drop_entity):
		_drop_off = null
		state = GatherState.CARRYING
		return
	if _is_in_range(drop_entity, _drop_off.deposit_range):
		_deposit_cargo()
		return
	var movement := _get_movement()
	if movement != null and not movement.has_move_target():
		_move_to_drop_off()

func _move_to_resource() -> void:
	if not _is_valid_target(current_target):
		cancel_gather()
		return
	var movement := _get_movement()
	if movement == null or not movement.request_move_to(current_target.global_position):
		print("Gather failed: could not move to resource.")
		cancel_gather()
		return
	state = GatherState.MOVING_TO_RESOURCE
	print("Worker moving to harvest %s." % _get_entity_display_name(current_target))
	gather_changed.emit()

func _start_harvesting() -> void:
	var harvestable := _get_harvestable(current_target)
	if harvestable == null or not harvestable.can_harvest():
		cancel_gather()
		return
	_harvest_timer = maxf(harvest_time, harvestable.harvest_time)
	state = GatherState.HARVESTING
	gather_changed.emit()

func _move_to_drop_off() -> void:
	if _drop_off == null or not is_instance_valid(_drop_off):
		return
	var drop_entity := _drop_off.get_entity_parent()
	var movement := _get_movement()
	if drop_entity == null or movement == null:
		return
	if not movement.request_move_to(drop_entity.global_position):
		print("Gather failed: could not move to drop-off.")
		state = GatherState.CARRYING

func _deposit_cargo() -> void:
	var wallet := get_node_or_null("/root/ResourceManager")
	if wallet != null and wallet.has_method("add_resource"):
		wallet.add_resource(carried_resource_id, carried_amount)
	print("Worker deposited %d %s." % [carried_amount, _get_resource_display_name(carried_resource_id)])
	carried_resource_id = &""
	carried_amount = 0
	_drop_off = null
	if _is_valid_target(current_target):
		_move_to_resource()
	else:
		state = GatherState.IDLE
		gather_changed.emit()

func _find_nearest_drop_off() -> DropOffComponent:
	var worker := get_entity_parent()
	if worker == null or carried_resource_id == &"":
		return null
	var best: DropOffComponent = null
	var best_distance := INF
	for node in get_tree().get_nodes_in_group("resource_dropoffs"):
		var drop_off := node as DropOffComponent
		if drop_off == null or not drop_off.accepts_resource(carried_resource_id):
			continue
		var entity := drop_off.get_entity_parent()
		if entity == null or not is_instance_valid(entity) or not entity.is_same_team(worker):
			continue
		var distance := worker.global_position.distance_to(entity.global_position)
		if distance < best_distance:
			best_distance = distance
			best = drop_off
	return best

func _get_invalid_gather_reason(target: EntityBase) -> String:
	if target == null or not is_instance_valid(target) or target.is_queued_for_deletion():
		return "target is no longer valid."
	var harvestable := _get_harvestable(target)
	if harvestable == null:
		return "target has no harvestable component."
	if harvestable.requires_extractor:
		return "target requires extractor."
	if not accepted_resource_ids.has(harvestable.get_resource_id()):
		return "%s is not accepted by this worker." % _get_resource_display_name(harvestable.get_resource_id())
	if not harvestable.has_resources():
		return "target has no remaining resources."
	if not harvestable.can_harvest():
		return "target cannot be harvested directly."
	return ""

func _is_valid_target(target: EntityBase) -> bool:
	return _get_invalid_gather_reason(target) == ""

func _get_harvestable(target: EntityBase) -> Node:
	if target == null or not is_instance_valid(target):
		return null
	return target.get_component(&"HarvestableComponent")

func _get_movement() -> MovementComponent:
	var entity := get_entity_parent()
	if entity == null:
		return null
	return entity.get_component(&"MovementComponent") as MovementComponent

func _is_in_range(target: EntityBase, range: float) -> bool:
	var worker := get_entity_parent()
	if worker == null or target == null or not is_instance_valid(target):
		return false
	var flat_worker := Vector2(worker.global_position.x, worker.global_position.z)
	var flat_target := Vector2(target.global_position.x, target.global_position.z)
	return flat_worker.distance_to(flat_target) <= range

func _get_entity_display_name(entity: EntityBase) -> String:
	if entity != null and entity.display_name.strip_edges() != "":
		return entity.display_name
	return entity.name if entity != null else "Unknown"

func _get_resource_display_name(resource_id: StringName) -> String:
	match resource_id:
		&"crystals":
			return "Crystals"
		&"he3":
			return "He3"
		_:
			return String(resource_id).capitalize()
