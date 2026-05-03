extends "res://mapeditor/tools/editor_tool.gd"
class_name EntityEditorTool

func _pick_playable_position(editor) -> Variant:
	var terrain = editor.terrain
	var camera = editor.camera
	if terrain == null or camera == null:
		return null

	var pick_point = terrain.get_pick_point(camera, editor.get_viewport().get_mouse_position())
	if pick_point == null:
		return null

	var local_position: Vector3 = pick_point
	if terrain.map_data == null:
		return null

	if not terrain.map_data.is_local_position_in_playable_area(local_position):
		return null

	return local_position

func _is_left_click(event: InputEvent) -> bool:
	return (
		event is InputEventMouseButton
		and event.pressed
		and event.button_index == MOUSE_BUTTON_LEFT
	)

func _is_pressed_key(event: InputEvent, keycode: Key) -> bool:
	return (
		event is InputEventKey
		and event.pressed
		and not event.echo
		and event.keycode == keycode
	)
