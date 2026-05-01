extends Control
class_name HudRoot

signal command_targeting_requested(source_entities: Array[EntityBase], command_id: StringName, target_mode: int)

@onready var _top_bar: Node = $TopBar
@onready var _bottom_bar: Node = $BottomBar

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_PASS
	_bottom_bar.command_targeting_requested.connect(_on_command_targeting_requested)
	_bottom_bar.command_executed.connect(_on_command_executed)

func set_selected_entity(entity: EntityBase) -> void:
	if entity == null:
		set_selected_entities([])
	else:
		set_selected_entities([entity])

func set_selected_entities(entities: Array) -> void:
	_bottom_bar.set_selected_entities(entities)

func refresh() -> void:
	_top_bar.refresh_resources()
	_bottom_bar.refresh_selected_entity_info()

func _on_command_targeting_requested(source_entities: Array[EntityBase], command_id: StringName, target_mode: int) -> void:
	command_targeting_requested.emit(source_entities, command_id, target_mode)

func _on_command_executed() -> void:
	refresh()
