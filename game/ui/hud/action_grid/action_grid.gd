extends PanelContainer
class_name ActionGrid

signal command_targeting_requested(source_entities: Array[EntityBase], command_id: StringName, target_mode: int)
signal command_executed

const PLAYER_TEAM_ID := 1
const SLOT_COUNT := 9

@onready var _grid: GridContainer = $MarginContainer/GridContainer

var _selected_entities: Array[EntityBase] = []
var _slot_buttons: Array[Button] = []
var _slot_commands: Array[CommandBase] = []

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	_create_slots()
	set_selected_entities([])

func set_selected_entity(entity: EntityBase) -> void:
	if entity == null:
		set_selected_entities([])
	else:
		set_selected_entities([entity])

func set_selected_entities(entities: Array) -> void:
	_selected_entities.clear()
	for entity in entities:
		var selected_entity := entity as EntityBase
		if selected_entity != null and is_instance_valid(selected_entity):
			_selected_entities.append(selected_entity)
	_rebuild_slots()

func _create_slots() -> void:
	for child in _grid.get_children():
		child.queue_free()
	_slot_buttons.clear()
	_slot_commands.clear()
	for i in range(SLOT_COUNT):
		var button := Button.new()
		button.custom_minimum_size = Vector2(52.0, 16.0)
		button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		button.clip_text = true
		button.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		button.disabled = true
		button.text = ""
		button.pressed.connect(_on_slot_pressed.bind(i))
		_grid.add_child(button)
		_slot_buttons.append(button)
		_slot_commands.append(null)

func _rebuild_slots() -> void:
	_prune_invalid_selected_entities()
	var commandable_entities := _get_commandable_selection()
	var common_commands := _get_common_commands(commandable_entities)
	if common_commands.size() > SLOT_COUNT:
		push_warning("ActionGrid received %d commands; showing first %d." % [common_commands.size(), SLOT_COUNT])
	for i in range(SLOT_COUNT):
		var command: CommandBase = common_commands[i] if i < common_commands.size() else null
		_slot_commands[i] = command
		_update_button(i, command)

func _update_button(index: int, command: CommandBase) -> void:
	var button := _slot_buttons[index]
	if command == null:
		button.text = ""
		button.tooltip_text = ""
		button.disabled = true
		return
	button.text = _get_command_display_name(command)
	button.tooltip_text = command.tooltip
	button.disabled = false

func _on_slot_pressed(index: int) -> void:
	if index < 0 or index >= _slot_commands.size():
		return
	var command := _slot_commands[index]
	if command == null:
		return
	_prune_invalid_selected_entities()
	var source_entities := _get_entities_with_command(command.command_id)
	if source_entities.is_empty():
		print("No commandable selected entities; command ignored.")
		return
	if command.target_mode == CommandBase.TargetMode.NONE:
		_execute_command_on_entities(source_entities, command.command_id, {})
		command_executed.emit()
		return
	command_targeting_requested.emit(source_entities, command.command_id, command.target_mode)

func _get_common_commands(entities: Array[EntityBase]) -> Array[CommandBase]:
	var common_commands: Array[CommandBase] = []
	if entities.is_empty():
		return common_commands
	if entities.size() == 1:
		return entities[0].get_available_commands()

	var seen_ids: Dictionary = {}
	for command in entities[0].get_available_commands():
		if command == null or seen_ids.has(command.command_id):
			continue
		seen_ids[command.command_id] = true

		var found_on_all := true
		for i in range(1, entities.size()):
			if not entities[i].has_command(command.command_id):
				found_on_all = false
				break
		if found_on_all:
			common_commands.append(command)

	return common_commands

func _get_entities_with_command(command_id: StringName) -> Array[EntityBase]:
	var entities: Array[EntityBase] = []
	for entity in _selected_entities:
		if _is_commandable_by_player(entity) and entity.has_command(command_id):
			entities.append(entity)
	return entities

func _execute_command_on_entities(entities: Array[EntityBase], command_id: StringName, context: Dictionary) -> int:
	var success_count := 0
	var attempted_count := 0
	for entity in entities:
		if entity == null or not is_instance_valid(entity) or not entity.has_command(command_id):
			continue
		attempted_count += 1
		if entity.execute_command(command_id, context):
			success_count += 1
	print("Command %s succeeded on %d/%d commandable entities." % [command_id, success_count, attempted_count])
	_rebuild_slots()
	return success_count

func _prune_invalid_selected_entities() -> void:
	for i in range(_selected_entities.size() - 1, -1, -1):
		if _selected_entities[i] == null or not is_instance_valid(_selected_entities[i]):
			_selected_entities.remove_at(i)

func _get_commandable_selection() -> Array[EntityBase]:
	var entities: Array[EntityBase] = []
	for entity in _selected_entities:
		if _is_commandable_by_player(entity):
			entities.append(entity)
	return entities

func _is_commandable_by_player(entity: EntityBase) -> bool:
	if entity == null or not is_instance_valid(entity):
		return false
	if entity.has_method("is_alive") and not entity.is_alive():
		return false
	return entity.has_method("get_team_id") and entity.get_team_id() == PLAYER_TEAM_ID and not entity.get_available_commands().is_empty()

func _get_command_display_name(command: CommandBase) -> String:
	if command.display_name.strip_edges() != "":
		return command.display_name
	return String(command.command_id)
