extends Node
class_name DropOffComponent

@export_node_path("Node3D") var entity_parent: NodePath
@export var accepts_resource_ids: Array[StringName] = [&"crystals"]
@export var deposit_range: float = 2.5

var _warned_missing_entity_parent := false

func _ready() -> void:
	add_to_group("resource_dropoffs")

func accepts_resource(resource_id: StringName) -> bool:
	return accepts_resource_ids.has(resource_id)

func deposit_resource(team_id: int, resource_id: StringName, amount: int) -> bool:
	if amount <= 0 or not accepts_resource(resource_id):
		return false
	var entity := get_entity_parent()
	if entity == null or not is_instance_valid(entity) or entity.get_team_id() != team_id:
		return false
	var wallet := get_node_or_null("/root/ResourceManager")
	if wallet != null and wallet.has_method("add_resource"):
		wallet.add_resource(resource_id, amount)
	return true

func get_entity_parent() -> EntityBase:
	var entity := get_node_or_null(entity_parent) as EntityBase
	if entity != null:
		return entity
	if not _warned_missing_entity_parent:
		push_warning("%s has no entity_parent assigned." % name)
		_warned_missing_entity_parent = true
	return null
