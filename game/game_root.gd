extends Node3D
class_name GameRoot

const SAVED_MAP_PATH := "res://levels/test_map/map_data.res"
const LevelScene := preload("res://level/level.tscn")

var level: Node

func _ready() -> void:
	level = LevelScene.instantiate()
	add_child(level)
	level.load_map(SAVED_MAP_PATH)
