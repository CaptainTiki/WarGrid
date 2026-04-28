extends PanelContainer
class_name CommandPanel

signal command_targeting_requested(source_entities: Array[EntityBase], command_id: StringName, target_mode: int)

const BUTTON_SIZE := Vector2(32.0, 32.0)

@onready var _selected_label: Label = $MarginContainer/VBoxContainer/SelectedEntityLabel
@onready var _command_list: VBoxContainer = $MarginContainer/VBoxContainer/CommandList

var _selected_entity: EntityBase = null
var _selected_entities: Array[EntityBase] = []
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
		if selected_entity != null:
			_selected_entities.append(selected_entity)
	_selected_entity = null
	if not _selected_entities.is_empty():
		_selected_entity = _selected_entities[0]
	_rebuild()

func _rebuild() -> void:
	for child in _command_list.get_children():
		child.free()

	if _selected_entities.is_empty():
		_selected_label.text = "No selection"
		return
	if _selected_entities.size() > 1:
		_selected_label.text = "%d selected" % _selected_entities.size()
	else:
		_selected_label.text = _get_entity_display_name(_selected_entity)

	var common_commands := _get_common_commands(_selected_entities)
	if common_commands.is_empty() and _selected_entities.size() > 1:
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
	var source_entities := _get_entities_with_command(command.command_id)
	if source_entities.is_empty():
		return
	if command.target_mode == CommandBase.TargetMode.NONE:
		_execute_command_on_entities(source_entities, command.command_id, {})
		return
	command_targeting_requested.emit(source_entities, command.command_id, command.target_mode)

func _get_entities_with_command(command_id: StringName) -> Array[EntityBase]:
	var entities: Array[EntityBase] = []
	for entity in _selected_entities:
		if entity != null and entity.has_command(command_id):
			entities.append(entity)
	return entities

func _execute_command_on_entities(entities: Array[EntityBase], command_id: StringName, context: Dictionary) -> int:
	var success_count := 0
	for entity in entities:
		if entity == null or not entity.has_command(command_id):
			continue
		if entity.execute_command(command_id, context):
			success_count += 1
	print("Command %s executed on %d entities." % [command_id, success_count])
	return success_count

func _get_entity_display_name(entity: EntityBase) -> String:
	if entity.display_name.strip_edges() != "":
		return entity.display_name
	return entity.name

func _get_command_display_name(command: CommandBase) -> String:
	if command.display_name.strip_edges() != "":
		return command.display_name
	return String(command.command_id)

func _make_button_texture(color: Color) -> Texture2D:
	var image := Image.create(32, 32, false, Image.FORMAT_RGBA8)
	image.fill(color)
	return ImageTexture.create_from_image(image)
