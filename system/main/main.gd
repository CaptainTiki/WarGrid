extends Node3D
class_name Main

const MainMenuScene := preload("res://system/main_menu/main_menu.tscn")
const GameRootScene := preload("res://game/game_root.tscn")
const MapEditorScene := preload("res://mapeditor/map_editor.tscn")

var _current_scene: Node

func _ready() -> void:
	_show_main_menu()

func _show_main_menu() -> void:
	var main_menu := MainMenuScene.instantiate()
	_set_current_scene(main_menu)
	main_menu.game_requested.connect(_show_game)
	main_menu.editor_requested.connect(_show_editor)

func _show_game() -> void:
	_set_current_scene(GameRootScene.instantiate())

func _show_editor() -> void:
	_set_current_scene(MapEditorScene.instantiate())

func _set_current_scene(scene: Node) -> void:
	if _current_scene != null:
		_current_scene.queue_free()
	_current_scene = scene
	add_child(_current_scene)
