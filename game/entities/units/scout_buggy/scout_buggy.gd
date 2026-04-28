extends "res://game/entities/units/unit_base.gd"
class_name ScoutBuggy

@onready var _movement: MovementComponent = $Components/MovementComponent
@onready var _selection_ring: MeshInstance3D = $SelectionRing

func _ready() -> void:
	display_name = "Scout Buggy"
	$ClickArea.add_to_group("entity_clickable")

func set_terrain(terrain: Terrain) -> void:
	_movement.set_terrain(terrain)

func set_selected(value: bool) -> void:
	_selection_ring.visible = value
