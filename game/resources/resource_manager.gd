extends Node
class_name ResourceWallet

signal resource_changed(resource_id: StringName, amount: int)
signal resources_changed

@export var starting_resources: Dictionary = {
	&"ore": 500,
}

var _resources: Dictionary = {}

func _ready() -> void:
	reset_to_starting_resources()

func reset_to_starting_resources() -> void:
	_resources.clear()
	for resource_id in starting_resources.keys():
		_resources[resource_id] = int(starting_resources[resource_id])
	resources_changed.emit()

func get_amount(resource_id: StringName) -> int:
	return int(_resources.get(resource_id, 0))

func can_afford(costs: Dictionary) -> bool:
	for resource_id in costs.keys():
		if get_amount(resource_id) < int(costs[resource_id]):
			return false
	return true

func spend(costs: Dictionary) -> bool:
	if not can_afford(costs):
		return false
	for resource_id in costs.keys():
		var amount := int(costs[resource_id])
		_resources[resource_id] = get_amount(resource_id) - amount
		resource_changed.emit(resource_id, get_amount(resource_id))
	resources_changed.emit()
	return true

func add_resource(resource_id: StringName, amount: int) -> void:
	_resources[resource_id] = get_amount(resource_id) + amount
	resource_changed.emit(resource_id, get_amount(resource_id))
	resources_changed.emit()

