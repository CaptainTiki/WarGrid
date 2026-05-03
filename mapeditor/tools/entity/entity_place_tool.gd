extends "res://mapeditor/tools/entity/entity_editor_tool.gd"
class_name EntityPlaceTool

func _init() -> void:
	tool_id = &"entities.place"
	display_name = "Place"

func activate(editor) -> void:
	super.activate(editor)
	editor.entity_clear_ghost()

func deactivate(editor) -> void:
	editor.entity_hide_ghost()
	super.deactivate(editor)

func update_preview(editor, delta: float) -> void:
	editor.entity_update_ghost()

func handle_input(editor, event: InputEvent) -> bool:
	if not _is_left_click(event):
		return false
	var local_position = _pick_playable_position(editor)
	if local_position == null:
		return true
	editor.entity_create_placement(local_position)
	return true
