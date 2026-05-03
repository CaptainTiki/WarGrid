extends Node
class_name HarvestableComponent

signal depleted(harvestable: Node)
signal amount_changed(remaining_amount: int, max_amount: int)

@export var resource_id: StringName = &"crystals"
@export var display_name: String = "Tritanium Crystal"
@export var remaining_amount: int = 150
@export var max_amount: int = 150
@export var harvest_amount_per_load: int = 10
@export var harvest_time: float = 1.0
@export var allow_multiple_workers: bool = true
@export var requires_extractor: bool = false
@export var worker_slot_limit: int = 0

var depleted_state := false
var _claimants: Array[Node] = []

func _ready() -> void:
	remaining_amount = clampi(remaining_amount, 0, max_amount)
	depleted_state = remaining_amount <= 0

func has_resources() -> bool:
	return remaining_amount > 0

func can_harvest() -> bool:
	return has_resources() and not requires_extractor and not depleted_state

func can_claim(worker: Node) -> bool:
	if worker == null or not is_instance_valid(worker):
		return false
	if not can_harvest():
		return false
	_cleanup_claimants()
	if _claimants.has(worker):
		return true
	if not allow_multiple_workers:
		return _claimants.is_empty()
	if worker_slot_limit > 0:
		return _claimants.size() < worker_slot_limit
	return true

func claim(worker: Node) -> bool:
	if not can_claim(worker):
		return false
	if not _claimants.has(worker):
		_claimants.append(worker)
	return true

func release_claim(worker: Node) -> void:
	if worker == null:
		return
	_claimants.erase(worker)

func is_claimed_by_other(worker: Node) -> bool:
	_cleanup_claimants()
	if _claimants.is_empty():
		return false
	return not (_claimants.size() == 1 and _claimants.has(worker))

func get_claim_count() -> int:
	_cleanup_claimants()
	return _claimants.size()

func harvest_amount(requested_amount: int) -> int:
	if requested_amount <= 0 or not can_harvest():
		return 0
	var harvested := mini(requested_amount, remaining_amount)
	remaining_amount -= harvested
	amount_changed.emit(remaining_amount, max_amount)
	if remaining_amount <= 0:
		_mark_depleted()
	return harvested

func has_available_resource() -> bool:
	return can_harvest()

func harvest_one() -> bool:
	return harvest_amount(1) == 1

func get_remaining_amount() -> int:
	return remaining_amount

func get_resource_id() -> StringName:
	return resource_id

func is_depleted() -> bool:
	return depleted_state

func _mark_depleted() -> void:
	if depleted_state:
		return
	depleted_state = true
	_claimants.clear()
	depleted.emit(self)

func _cleanup_claimants() -> void:
	for i in range(_claimants.size() - 1, -1, -1):
		var claimant := _claimants[i]
		if claimant == null or not is_instance_valid(claimant) or claimant.is_queued_for_deletion():
			_claimants.remove_at(i)
