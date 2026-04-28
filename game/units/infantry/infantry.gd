extends UnitBase
class_name Infantry

@onready var _movement: MovementComponent = $Components/MovementComponent
@onready var _selection_ring: MeshInstance3D = $SelectionRing

func _ready() -> void:
	$ClickArea.add_to_group("unit_clickable")

func set_terrain(terrain: Terrain) -> void:
	_movement.set_terrain(terrain)

func set_selected(value: bool) -> void:
	_selection_ring.visible = value

func move_to(target: Vector3) -> void:
	_movement.set_path([target])
