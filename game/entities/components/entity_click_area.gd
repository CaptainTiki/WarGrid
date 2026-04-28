extends Area3D
class_name EntityClickArea

@export_node_path("Node3D") var entity_parent: NodePath

func get_entity_parent() -> EntityBase:
	var entity := get_node_or_null(entity_parent) as EntityBase
	if entity == null:
		push_warning("%s has no entity_parent assigned." % name)
	return entity
