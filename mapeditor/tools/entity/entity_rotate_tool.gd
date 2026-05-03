extends "res://mapeditor/tools/entity/entity_editor_tool.gd"
class_name EntityRotateTool

func _init() -> void:
	tool_id = &"entities.rotate"
	display_name = "Rotate"

func handle_input(editor, event: InputEvent) -> bool:
	if _is_left_click(event):
		editor.entity_rotate_selected_placement(PI * 0.5)
		return true
	if _is_pressed_key(event, KEY_Q):
		editor.entity_rotate_selected_placement(-PI * 0.5)
		return true
	if _is_pressed_key(event, KEY_E):
		editor.entity_rotate_selected_placement(PI * 0.5)
		return true
	return false
