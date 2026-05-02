extends EntityBase
class_name ResourceNode

@onready var _selection_ring: MeshInstance3D = $SelectionRing
@onready var _visual_root: Node3D = $VisualRoot

func _ready() -> void:
	attackable = false
	add_to_group("selectable_entities")
	$ClickArea.add_to_group("entity_clickable")
	var harvestable := get_component(&"HarvestableComponent")
	if harvestable != null and harvestable.has_signal("depleted"):
		add_to_group("harvestable_resources")
		harvestable.depleted.connect(_on_harvestable_depleted)

func set_selected(value: bool) -> void:
	_selection_ring.visible = value

func _on_harvestable_depleted(_harvestable: Node) -> void:
	_visual_root.visible = false
	set_selected(false)
