extends Node
class_name EditorTool

var tool_id: StringName = &""
var display_name: String = ""
var active := false

func activate(editor) -> void:
	active = true

func deactivate(editor) -> void:
	active = false

func update_preview(editor, delta: float) -> void:
	pass

func handle_input(editor, event: InputEvent) -> bool:
	return false

func cancel(editor) -> void:
	pass
