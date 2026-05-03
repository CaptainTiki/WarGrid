extends "res://mapeditor/tools/entity/entity_editor_tool.gd"
class_name EntityDeleteTool

func _init() -> void:
	tool_id = &"entities.delete"
	display_name = "Delete"

func handle_input(editor, event: InputEvent) -> bool:
	if _is_left_click(event):
		var local_position = _pick_playable_position(editor)
		if local_position == null:
			return true
		editor.entity_delete_nearest_placement(local_position)
		return true
	if _is_pressed_key(event, KEY_DELETE):
		editor.entity_delete_selected_or_last_placement()
		return true
	return false
