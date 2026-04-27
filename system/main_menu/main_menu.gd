extends Control
class_name MainMenu

signal game_requested
signal editor_requested

@onready var game_button: Button = %GameButton
@onready var editor_button: Button = %EditorButton

func _ready() -> void:
	game_button.pressed.connect(_on_game_pressed)
	editor_button.pressed.connect(_on_editor_pressed)

func _on_game_pressed() -> void:
	game_requested.emit()

func _on_editor_pressed() -> void:
	editor_requested.emit()
