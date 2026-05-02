extends Node
class_name WorkerGatherComponent

signal gather_changed

enum GatherState {
	IDLE,
	MOVING_TO_GATHER_LOCATION,
	SEARCHING_FOR_CRYSTAL,
	MOVING_TO_CRYSTAL,
	HARVESTING,
	RETURNING_TO_DROPOFF,
	DEPOSITING,
	RETURNING_TO_GATHER_LOCATION,
}

const CRYSTAL_RESOURCE_ID := &"crystals"
const CARGO_PER_TRIP := 1

@export_node_path("Node3D") var entity_parent: NodePath
@export var search_radius: float = 7.0
@export var gather_location_arrival_range: float = 1.2
@export var gather_range: float = 1.6
@export var harvest_time: float = 0.75
@export var carry_capacity: int = 1
@export var accepted_resource_ids: Array[StringName] = [&"crystals"]

var current_target: EntityBase = null
var dropoff_target: EntityBase = null
var gather_location := Vector3.ZERO
var has_gather_location := false
var carried_resource_id: StringName = &""
var carried_amount: int = 0
var state := GatherState.IDLE

var _harvest_timer := 0.0
var _drop_off: DropOffComponent = null
var _terrain: Terrain = null
var _warned_missing_entity_parent := false

func _process(delta: float) -> void:
	match state:
		GatherState.MOVING_TO_GATHER_LOCATION:
			_process_moving_to_gather_location()
		GatherState.SEARCHING_FOR_CRYSTAL:
			_search_and_move_to_crystal()
		GatherState.MOVING_TO_CRYSTAL:
			_process_moving_to_crystal()
		GatherState.HARVESTING:
			_process_harvesting(delta)
		GatherState.RETURNING_TO_DROPOFF:
			_process_returning_to_dropoff()
		GatherState.DEPOSITING:
			_deposit_cargo()
		GatherState.RETURNING_TO_GATHER_LOCATION:
			_process_returning_to_gather_location()

func get_entity_parent() -> EntityBase:
	var entity := get_node_or_null(entity_parent) as EntityBase
	if entity != null:
		return entity
	if not _warned_missing_entity_parent:
		push_warning("%s has no entity_parent assigned." % name)
		_warned_missing_entity_parent = true
	return null

func has_cargo() -> bool:
	return carried_amount > 0 and carried_resource_id != &""

func can_pickup_crystal() -> bool:
	return not has_cargo()

func pickup_crystal() -> bool:
	if not can_pickup_crystal():
		return false
	carried_resource_id = CRYSTAL_RESOURCE_ID
	carried_amount = CARGO_PER_TRIP
	gather_changed.emit()
	return true

func clear_cargo() -> void:
	carried_resource_id = &""
	carried_amount = 0
	gather_changed.emit()

func can_gather_at_location(_location: Vector3) -> bool:
	return accepted_resource_ids.has(CRYSTAL_RESOURCE_ID)

func can_gather_target(target: EntityBase) -> bool:
	return _get_invalid_crystal_reason(target) == ""

func get_invalid_gather_reason(target: EntityBase) -> String:
	return _get_invalid_crystal_reason(target)

func start_gather_location(location: Vector3, terrain: Terrain = null) -> bool:
	if not can_gather_at_location(location):
		print("Gather failed: worker cannot gather crystals.")
		return false
	_terrain = terrain
	var movement := _get_movement()
	if movement != null and terrain != null:
		movement.set_terrain(terrain)
	gather_location = location
	has_gather_location = true
	current_target = null
	_harvest_timer = 0.0
	_drop_off = null
	dropoff_target = null
	if has_cargo():
		print("Worker will deposit current cargo before gathering new location.")
		_start_return_to_dropoff()
	else:
		_move_to_gather_location()
	print("Worker accepted gather location %s." % gather_location)
	gather_changed.emit()
	return true

func start_gather(target: EntityBase) -> bool:
	var invalid_reason := _get_invalid_crystal_reason(target)
	if invalid_reason != "":
		print("Gather failed: %s" % invalid_reason)
		return false
	return start_gather_location(target.global_position, _terrain)

func cancel_gather(keep_cargo: bool = true) -> void:
	if state == GatherState.IDLE and current_target == null and not has_gather_location:
		return
	current_target = null
	_drop_off = null
	dropoff_target = null
	_harvest_timer = 0.0
	has_gather_location = false
	state = GatherState.IDLE
	if not keep_cargo:
		clear_cargo()
	print("Gather canceled.")
	gather_changed.emit()

func get_cargo_text() -> String:
	if not has_cargo():
		return "Cargo: Empty"
	return "Carrying: %d %s" % [carried_amount, _get_resource_display_name(carried_resource_id)]

func _process_moving_to_gather_location() -> void:
	if not has_gather_location:
		state = GatherState.IDLE
		gather_changed.emit()
		return
	if _is_worker_near(gather_location, gather_location_arrival_range):
		state = GatherState.SEARCHING_FOR_CRYSTAL
		gather_changed.emit()
		return
	var movement := _get_movement()
	if movement != null and not movement.has_move_target():
		_move_to_gather_location()

func _search_and_move_to_crystal() -> void:
	current_target = _find_nearest_crystal_near_gather_location()
	if current_target == null:
		print("No crystals found near gather location.")
		state = GatherState.IDLE
		gather_changed.emit()
		return
	_move_to_crystal()

func _process_moving_to_crystal() -> void:
	if not _is_valid_crystal(current_target):
		state = GatherState.SEARCHING_FOR_CRYSTAL
		gather_changed.emit()
		return
	if _is_in_range(current_target, gather_range):
		_start_harvesting()
		return
	var movement := _get_movement()
	if movement != null and not movement.has_move_target():
		_move_to_crystal()

func _process_harvesting(delta: float) -> void:
	if not _is_valid_crystal(current_target):
		state = GatherState.SEARCHING_FOR_CRYSTAL
		gather_changed.emit()
		return
	if not _is_in_range(current_target, gather_range):
		_move_to_crystal()
		return
	_harvest_timer -= delta
	if _harvest_timer > 0.0:
		return
	var harvestable := _get_harvestable(current_target)
	if harvestable == null or not harvestable.harvest_one():
		state = GatherState.SEARCHING_FOR_CRYSTAL
		gather_changed.emit()
		return
	if not pickup_crystal():
		print("Gather failed: worker already has cargo.")
		state = GatherState.IDLE
		gather_changed.emit()
		return
	print("Worker harvested 1 Crystal. Remaining node amount: %d." % harvestable.get_remaining_amount())
	_start_return_to_dropoff()

func _process_returning_to_dropoff() -> void:
	if not has_cargo():
		_return_to_gather_location()
		return
	if _drop_off == null or not is_instance_valid(_drop_off):
		_drop_off = _find_nearest_drop_off()
		dropoff_target = _drop_off.get_entity_parent() if _drop_off != null else null
		if _drop_off == null:
			print("Worker carrying 1 Crystal; no valid drop-off found.")
			state = GatherState.IDLE
			gather_changed.emit()
			return
	var drop_entity := _drop_off.get_entity_parent()
	if drop_entity == null or not is_instance_valid(drop_entity):
		_drop_off = null
		dropoff_target = null
		return
	if _is_in_range(drop_entity, _drop_off.deposit_range):
		state = GatherState.DEPOSITING
		_deposit_cargo()
		return
	var movement := _get_movement()
	if movement != null and not movement.has_move_target():
		_move_to_drop_off()

func _process_returning_to_gather_location() -> void:
	if not has_gather_location:
		state = GatherState.IDLE
		gather_changed.emit()
		return
	if _is_worker_near(gather_location, gather_location_arrival_range):
		state = GatherState.SEARCHING_FOR_CRYSTAL
		gather_changed.emit()
		return
	var movement := _get_movement()
	if movement != null and not movement.has_move_target():
		_move_to_gather_location()

func _move_to_gather_location() -> void:
	var movement := _get_movement()
	if movement == null:
		state = GatherState.IDLE
		return
	if _terrain != null:
		movement.set_terrain(_terrain)
	if not movement.request_move_to(gather_location):
		print("Gather warning: could not stand on gather location; searching nearby crystals.")
		state = GatherState.SEARCHING_FOR_CRYSTAL
		gather_changed.emit()
		return
	state = GatherState.MOVING_TO_GATHER_LOCATION
	gather_changed.emit()

func _move_to_crystal() -> void:
	if not _is_valid_crystal(current_target):
		state = GatherState.SEARCHING_FOR_CRYSTAL
		gather_changed.emit()
		return
	var movement := _get_movement()
	if movement == null or not movement.request_move_to(current_target.global_position):
		if _is_in_range(current_target, gather_range):
			_start_harvesting()
		else:
			print("Gather failed: could not move near crystal.")
			state = GatherState.SEARCHING_FOR_CRYSTAL
			gather_changed.emit()
		return
	state = GatherState.MOVING_TO_CRYSTAL
	print("Worker moving to harvest %s." % _get_entity_display_name(current_target))
	gather_changed.emit()

func _start_harvesting() -> void:
	var harvestable := _get_harvestable(current_target)
	if harvestable == null or not harvestable.has_available_resource():
		state = GatherState.SEARCHING_FOR_CRYSTAL
		gather_changed.emit()
		return
	_harvest_timer = maxf(harvest_time, harvestable.harvest_time)
	state = GatherState.HARVESTING
	gather_changed.emit()

func _start_return_to_dropoff() -> void:
	_drop_off = _find_nearest_drop_off()
	dropoff_target = _drop_off.get_entity_parent() if _drop_off != null else null
	if _drop_off == null:
		print("Worker carrying 1 Crystal; no valid drop-off found.")
		state = GatherState.IDLE
		gather_changed.emit()
		return
	_move_to_drop_off()

func _move_to_drop_off() -> void:
	if _drop_off == null or not is_instance_valid(_drop_off):
		return
	var drop_entity := _drop_off.get_entity_parent()
	var movement := _get_movement()
	if drop_entity == null or movement == null:
		return
	if not movement.request_move_to(drop_entity.global_position):
		print("Gather failed: could not move to drop-off.")
		state = GatherState.IDLE
		gather_changed.emit()
		return
	state = GatherState.RETURNING_TO_DROPOFF
	gather_changed.emit()

func _deposit_cargo() -> void:
	if _drop_off == null or not is_instance_valid(_drop_off):
		state = GatherState.RETURNING_TO_DROPOFF
		gather_changed.emit()
		return
	var worker := get_entity_parent()
	if worker == null or not has_cargo():
		state = GatherState.IDLE
		gather_changed.emit()
		return
	if not _drop_off.deposit_resource(worker.get_team_id(), carried_resource_id, carried_amount):
		print("Worker failed to deposit %d %s." % [carried_amount, _get_resource_display_name(carried_resource_id)])
		state = GatherState.IDLE
		gather_changed.emit()
		return
	print("Worker deposited %d %s." % [carried_amount, _get_resource_display_name(carried_resource_id)])
	clear_cargo()
	_drop_off = null
	dropoff_target = null
	_return_to_gather_location()

func _return_to_gather_location() -> void:
	if not has_gather_location:
		state = GatherState.IDLE
		gather_changed.emit()
		return
	state = GatherState.RETURNING_TO_GATHER_LOCATION
	_move_to_gather_location()

func _find_nearest_crystal_near_gather_location() -> EntityBase:
	var worker := get_entity_parent()
	if worker == null:
		return null
	var best: EntityBase = null
	var best_distance := INF
	for node in get_tree().get_nodes_in_group("harvestable_resources"):
		var entity := node as EntityBase
		if not _is_valid_crystal(entity):
			continue
		if _flat_distance(entity.global_position, gather_location) > search_radius:
			continue
		var distance := _flat_distance(worker.global_position, entity.global_position)
		if distance < best_distance:
			best_distance = distance
			best = entity
	return best

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
		var distance := _flat_distance(worker.global_position, entity.global_position)
		if distance < best_distance:
			best_distance = distance
			best = drop_off
	return best

func _get_invalid_crystal_reason(target: EntityBase) -> String:
	if target == null or not is_instance_valid(target) or target.is_queued_for_deletion():
		return "target is no longer valid."
	var harvestable := _get_harvestable(target)
	if harvestable == null:
		return "target has no harvestable component."
	if harvestable.get_resource_id() != CRYSTAL_RESOURCE_ID:
		return "%s is not supported by first-pass worker gathering." % _get_resource_display_name(harvestable.get_resource_id())
	if not accepted_resource_ids.has(harvestable.get_resource_id()):
		return "%s is not accepted by this worker." % _get_resource_display_name(harvestable.get_resource_id())
	if harvestable.requires_extractor:
		return "target requires extractor."
	if not harvestable.has_available_resource():
		return "target has no remaining resources."
	return ""

func _is_valid_crystal(target: EntityBase) -> bool:
	return _get_invalid_crystal_reason(target) == ""

func _get_harvestable(target: EntityBase) -> HarvestableComponent:
	if target == null or not is_instance_valid(target):
		return null
	return target.get_component(&"HarvestableComponent") as HarvestableComponent

func _get_movement() -> MovementComponent:
	var entity := get_entity_parent()
	if entity == null:
		return null
	return entity.get_component(&"MovementComponent") as MovementComponent

func _is_in_range(target: EntityBase, range: float) -> bool:
	var worker := get_entity_parent()
	if worker == null or target == null or not is_instance_valid(target):
		return false
	return _flat_distance(worker.global_position, target.global_position) <= range

func _is_worker_near(position: Vector3, range: float) -> bool:
	var worker := get_entity_parent()
	if worker == null:
		return false
	return _flat_distance(worker.global_position, position) <= range

func _flat_distance(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x, a.z).distance_to(Vector2(b.x, b.z))

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
