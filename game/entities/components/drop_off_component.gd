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

func get_entity_parent() -> EntityBase:
	var entity := get_node_or_null(entity_parent) as EntityBase
	if entity != null:
		return entity
	if not _warned_missing_entity_parent:
		push_warning("%s has no entity_parent assigned." % name)
		_warned_missing_entity_parent = true
	return null
