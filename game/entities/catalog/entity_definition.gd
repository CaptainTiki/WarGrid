extends Resource
class_name EntityDefinition

enum EditorPlacementSnapMode {
	FREE,
	GRID_CENTER,
}

@export var id: StringName
@export var display_name: String = ""
@export var scene: PackedScene
@export var category: StringName = &"unit"
@export var default_team_id: int = 1
@export var editor_snap_mode: EditorPlacementSnapMode = EditorPlacementSnapMode.GRID_CENTER
@export_multiline var description: String = ""
