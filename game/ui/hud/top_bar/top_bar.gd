extends PanelContainer
class_name TopBar

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	$MarginContainer/HBoxContainer/QuitButton.pressed.connect(_on_quit_pressed)

func refresh_resources() -> void:
	var resource_display := $MarginContainer/HBoxContainer/ResourceDisplay
	if resource_display != null and resource_display.has_method("refresh"):
		resource_display.refresh()

func _on_quit_pressed() -> void:
	get_tree().quit()
