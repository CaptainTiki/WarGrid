extends "res://mapeditor/tools/entity/entity_editor_tool.gd"
class_name EntityMoveTool

func _init() -> void:
	tool_id = &"entities.move"
	display_name = "Move"

func handle_input(editor, event: InputEvent) -> bool:
	if not _is_left_click(event):
		return false
	var local_position = _pick_playable_position(editor)
	if local_position == null:
		return true
	editor.entity_move_selected_placement(local_position)
	return true
