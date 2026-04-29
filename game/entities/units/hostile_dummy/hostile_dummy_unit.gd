extends UnitBase
class_name HostileDummyUnit

@onready var _selection_ring: MeshInstance3D = $SelectionRing

func _ready() -> void:
	if display_name.strip_edges() == "":
		display_name = "Enemy Dummy Unit"
	add_to_group("selectable_entities")
	add_to_group("selectable_units")
	$ClickArea.add_to_group("entity_clickable")

func set_selected(value: bool) -> void:
	_selection_ring.visible = value
