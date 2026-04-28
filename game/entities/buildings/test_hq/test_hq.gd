extends BuildingBase
class_name TestHQ

@onready var _selection_ring: MeshInstance3D = $SelectionRing

func _ready() -> void:
	display_name = "Test HQ"
	add_to_group("selectable_entities")
	add_to_group("selectable_buildings")
	$ClickArea.add_to_group("entity_clickable")

func set_selected(value: bool) -> void:
	_selection_ring.visible = value
