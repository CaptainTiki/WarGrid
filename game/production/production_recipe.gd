extends Resource
class_name ProductionRecipe

@export var id: StringName
@export var display_name: String = ""
@export var produced_entity_id: StringName
@export var build_time: float = 5.0
@export var costs: Dictionary = {
	&"ore": 50,
}
@export var icon: Texture2D
@export_multiline var description: String = ""
@export var category: StringName = &"unit"

