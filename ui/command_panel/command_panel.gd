extends PanelContainer
class_name CommandPanel

signal command_targeting_requested(source_entities: Array[EntityBase], command_id: StringName, target_mode: int)

const BUTTON_SIZE := Vector2(32.0, 32.0)
const PLAYER_TEAM_ID := 1

@onready var _selected_label: Label = $MarginContainer/VBoxContainer/SelectedEntityLabel
@onready var _selection_count_label: Label = $MarginContainer/VBoxContainer/SelectionCountLabel
@onready var _team_label: Label = $MarginContainer/VBoxContainer/TeamLabel
@onready var _status_label: Label = $MarginContainer/VBoxContainer/StatusLabel
@onready var _health_label: Label = $MarginContainer/VBoxContainer/HealthLabel
@onready var _command_list: VBoxContainer = $MarginContainer/VBoxContainer/CommandScroll/CommandList

var _selected_entity: EntityBase = null
var _selected_entities: Array[EntityBase] = []
var _selected_health_component: Node = null
var _button_texture: Texture2D
var _button_hover_texture: Texture2D
var _button_pressed_texture: Texture2D

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	_button_texture = _make_button_texture(Color(0.18, 0.22, 0.26, 1.0))
	_button_hover_texture = _make_button_texture(Color(0.25, 0.31, 0.37, 1.0))
	_button_pressed_texture = _make_button_texture(Color(0.11, 0.15, 0.19, 1.0))
	set_selected_entities([])

func set_selected_entity(entity: EntityBase) -> void:
	if entity == null:
		set_selected_entities([])
	else:
		set_selected_entities([entity])

func set_selected_entities(entities: Array[EntityBase]) -> void:
	_selected_entities.clear()
	for entity in entities:
		var selected_entity := entity as EntityBase
		if is_instance_valid(selected_entity) and selected_entity != null:
			_selected_entities.append(selected_entity)
	_selected_entity = null
	if not _selected_entities.is_empty():
		_selected_entity = _selected_entities[0]
	_rebuild()

func _rebuild() -> void:
	_prune_invalid_selected_entities()
	for child in _command_list.get_children():
		child.free()

	if _selected_entities.is_empty():
		_selected_label.text = "No selection"
		_hide_scan_labels()
		_hide_health_label()
		return
	var commandable_entities := _get_commandable_selection()
	if _selected_entities.size() > 1:
		_selected_label.text = "%d selected" % _selected_entities.size()
		_show_multi_selection_info(commandable_entities)
		_hide_health_label()
	else:
		_selected_label.text = _get_entity_display_name(_selected_entity)
		_show_single_selection_info(_selected_entity)
		_update_health_label(_selected_entity)

	var common_commands := _get_common_commands(commandable_entities)
	if common_commands.is_empty() and not commandable_entities.is_empty() and commandable_entities.size() > 1:
		var label := Label.new()
		label.text = "No common commands"
		_command_list.add_child(label)
		return

	for command in common_commands:
		_command_list.add_child(_create_command_row(command))

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

func _create_command_row(command: CommandBase) -> Control:
	var row := HBoxContainer.new()
	row.custom_minimum_size = Vector2(220.0, 34.0)

	var button := TextureButton.new()
	button.custom_minimum_size = BUTTON_SIZE
	button.mouse_filter = Control.MOUSE_FILTER_STOP
	button.texture_normal = _button_texture
	button.texture_hover = _button_hover_texture
	button.texture_pressed = _button_pressed_texture
	button.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
	button.tooltip_text = command.tooltip
	button.pressed.connect(_on_command_pressed.bind(command))
	row.add_child(button)

	var label := Label.new()
	label.text = _get_command_display_name(command)
	label.tooltip_text = command.tooltip
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(label)

	return row

func _on_command_pressed(command: CommandBase) -> void:
	if command == null:
		return
	_prune_invalid_selected_entities()
	var source_entities := _get_entities_with_command(command.command_id)
	if source_entities.is_empty():
		print("No commandable selected entities; command ignored.")
		return
	if command.target_mode == CommandBase.TargetMode.NONE:
		_execute_command_on_entities(source_entities, command.command_id, {})
		return
	command_targeting_requested.emit(source_entities, command.command_id, command.target_mode)

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
		if not is_instance_valid(entity) or entity == null or not entity.has_command(command_id):
			continue
		attempted_count += 1
		if entity.execute_command(command_id, context):
			success_count += 1
	print("Command %s succeeded on %d/%d commandable entities." % [command_id, success_count, attempted_count])
	_rebuild()
	return success_count

func _prune_invalid_selected_entities() -> void:
	for i in range(_selected_entities.size() - 1, -1, -1):
		if not is_instance_valid(_selected_entities[i]) or _selected_entities[i] == null:
			_selected_entities.remove_at(i)
	_selected_entity = null
	if not _selected_entities.is_empty():
		_selected_entity = _selected_entities[0]

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

func _show_single_selection_info(entity: EntityBase) -> void:
	_selection_count_label.visible = false
	_team_label.visible = true
	_status_label.visible = true
	_team_label.text = "Team: %s" % _get_team_display_name(entity)
	_status_label.text = "Status: %s" % _get_selection_status(entity)

func _show_multi_selection_info(commandable_entities: Array[EntityBase]) -> void:
	_selection_count_label.visible = true
	_team_label.visible = false
	_status_label.visible = false
	var non_commandable_count := _selected_entities.size() - commandable_entities.size()
	_selection_count_label.text = "Selected: %d | Commandable: %d | Non-commandable: %d" % [
		_selected_entities.size(),
		commandable_entities.size(),
		non_commandable_count,
	]

func _hide_scan_labels() -> void:
	_selection_count_label.visible = false
	_team_label.visible = false
	_status_label.visible = false

func _update_health_label(entity: EntityBase) -> void:
	var health := entity.get_health_component()
	if health == null:
		_hide_health_label()
		return
	if _selected_health_component != health:
		_disconnect_health_label()
		_selected_health_component = health
		health.health_changed.connect(_on_selected_health_changed)
	_health_label.visible = true
	_health_label.text = "HP: %.0f / %.0f" % [health.current_health, health.max_health]

func _hide_health_label() -> void:
	_disconnect_health_label()
	_health_label.visible = false

func _disconnect_health_label() -> void:
	if _selected_health_component != null and is_instance_valid(_selected_health_component):
		if _selected_health_component.health_changed.is_connected(_on_selected_health_changed):
			_selected_health_component.health_changed.disconnect(_on_selected_health_changed)
	_selected_health_component = null

func _on_selected_health_changed(current_health: float, max_health: float) -> void:
	_health_label.text = "HP: %.0f / %.0f" % [current_health, max_health]

func _get_entity_display_name(entity: EntityBase) -> String:
	if entity.display_name.strip_edges() != "":
		return entity.display_name
	return entity.name

func _get_command_display_name(command: CommandBase) -> String:
	if command.display_name.strip_edges() != "":
		return command.display_name
	return String(command.command_id)

func _get_team_display_name(entity: EntityBase) -> String:
	if entity == null or not is_instance_valid(entity):
		return "Unknown"
	match entity.get_team_id():
		0:
			return "Neutral"
		1:
			return "Player"
		2:
			return "Enemy"
		_:
			return "Team %d" % entity.get_team_id()

func _get_selection_status(entity: EntityBase) -> String:
	if entity == null or not is_instance_valid(entity) or not entity.has_method("get_team_id"):
		return "Unknown"
	var team_id: int = entity.get_team_id()
	if team_id == PLAYER_TEAM_ID:
		return "Owned"
	if team_id == 0:
		return "Neutral"
	return "Hostile" if team_id != PLAYER_TEAM_ID else "Unknown"

func _make_button_texture(color: Color) -> Texture2D:
	var image := Image.create(32, 32, false, Image.FORMAT_RGBA8)
	image.fill(color)
	return ImageTexture.create_from_image(image)
