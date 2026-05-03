extends Node
class_name EntityFootprintComponent

enum Shape { CIRCLE, RECTANGLE }

@export_node_path("Node3D") var entity_parent: NodePath
@export var shape: Shape = Shape.CIRCLE
@export var radius: float = 0.5
@export var half_extents: Vector2 = Vector2(1.0, 1.0)
@export var blocks_units: bool = true
@export var blocks_pathfinding: bool = false
@export var participates_in_separation: bool = true
@export var is_static: bool = false

var _warned_missing_entity_parent := false

func _ready() -> void:
	add_to_group("entity_footprints")

func get_entity_parent() -> EntityBase:
	var entity := get_node_or_null(entity_parent) as EntityBase
	if entity != null:
		return entity
	if not _warned_missing_entity_parent:
		push_warning("%s has no entity_parent assigned." % name)
		_warned_missing_entity_parent = true
	return null

func get_separation_radius() -> float:
	if shape == Shape.CIRCLE:
		return radius
	return half_extents.length()

func is_hard_blocker() -> bool:
	return blocks_units and (is_static or blocks_pathfinding)

func is_soft_unit_blocker() -> bool:
	return blocks_units and participates_in_separation and not is_static and not blocks_pathfinding
