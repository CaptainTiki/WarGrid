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

func _ready() -> void:
	remaining_amount = clampi(remaining_amount, 0, max_amount)
	depleted_state = remaining_amount <= 0

func has_resources() -> bool:
	return remaining_amount > 0

func can_harvest() -> bool:
	return has_resources() and not requires_extractor and not depleted_state

func harvest_amount(requested_amount: int) -> int:
	if requested_amount <= 0 or not can_harvest():
		return 0
	var harvested := mini(requested_amount, remaining_amount)
	remaining_amount -= harvested
	amount_changed.emit(remaining_amount, max_amount)
	if remaining_amount <= 0:
		_mark_depleted()
	return harvested

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
	depleted.emit(self)
