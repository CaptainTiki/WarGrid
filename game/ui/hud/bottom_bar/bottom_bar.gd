extends PanelContainer
class_name BottomBar

signal command_targeting_requested(source_entities: Array[EntityBase], command_id: StringName, target_mode: int)
signal command_executed

@onready var _selection_panel: Node = $MarginContainer/HBoxContainer/SelectionPanel
@onready var _action_grid: Node = $MarginContainer/HBoxContainer/ActionGrid

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	_action_grid.command_targeting_requested.connect(_on_command_targeting_requested)
	_action_grid.command_executed.connect(_on_command_executed)

func set_selected_entity(entity: EntityBase) -> void:
	if entity == null:
		set_selected_entities([])
	else:
		set_selected_entities([entity])

func set_selected_entities(entities: Array) -> void:
	_selection_panel.set_selected_entities(entities)
	_action_grid.set_selected_entities(entities)

func refresh_selected_entity_info() -> void:
	_selection_panel.refresh_selected_entity_info()

func _on_command_targeting_requested(source_entities: Array[EntityBase], command_id: StringName, target_mode: int) -> void:
	command_targeting_requested.emit(source_entities, command_id, target_mode)

func _on_command_executed() -> void:
	refresh_selected_entity_info()
	command_executed.emit()
