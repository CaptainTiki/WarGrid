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
@onready var _resource_label: Label = $MarginContainer/VBoxContainer/ResourceLabel
@onready var _production_commands_label: Label = $MarginContainer/VBoxContainer/ProductionCommandsLabel
@onready var _active_production_label: Label = $MarginContainer/VBoxContainer/ActiveProductionLabel
@onready var _production_progress: ProgressBar = $MarginContainer/VBoxContainer/ProductionProgress
@onready var _production_queue_label: Label = $MarginContainer/VBoxContainer/ProductionQueueLabel
@onready var _production_queue_list_label: Label = $MarginContainer/VBoxContainer/ProductionQueueListLabel
@onready var _rally_point_label: Label = $MarginContainer/VBoxContainer/RallyPointLabel
@onready var _command_list: VBoxContainer = $MarginContainer/VBoxContainer/CommandScroll/CommandList

var _selected_entity: EntityBase = null
var _selected_entities: Array[EntityBase] = []
var _selected_health_component: Node = null
var _selected_harvestable_component: Node = null
var _selected_worker_gather_component: Node = null
var _selected_production_component: Node = null
var _button_texture: Texture2D
var _button_hover_texture: Texture2D
var _button_pressed_texture: Texture2D

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	_button_texture = _make_button_texture(Color(0.18, 0.22, 0.26, 1.0))
	_button_hover_texture = _make_button_texture(Color(0.25, 0.31, 0.37, 1.0))
	_button_pressed_texture = _make_button_texture(Color(0.11, 0.15, 0.19, 1.0))
	_connect_resource_wallet()
	_update_resource_label()
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
		_hide_harvestable_label()
		_hide_health_label()
		_hide_production_info()
		return
	var commandable_entities := _get_commandable_selection()
	if _selected_entities.size() > 1:
		_selected_label.text = "%d selected" % _selected_entities.size()
		_show_multi_selection_info(commandable_entities)
		_hide_harvestable_label()
		_hide_health_label()
		_hide_production_info()
	else:
		_selected_label.text = _get_entity_display_name(_selected_entity)
		_show_single_selection_info(_selected_entity)
		if _get_harvestable_component(_selected_entity) != null:
			_hide_health_label()
			_update_harvestable_label(_selected_entity)
		else:
			_hide_harvestable_label()
			_update_health_label(_selected_entity)
		_update_production_info(_selected_entity)

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
	_connect_worker_gather_label(entity)
	_health_label.visible = true
	_health_label.text = _format_health_and_cargo_info(entity, health)

func _hide_health_label() -> void:
	_disconnect_health_label()
	_disconnect_worker_gather_label()
	_health_label.visible = false

func _disconnect_health_label() -> void:
	if _selected_health_component != null and is_instance_valid(_selected_health_component):
		if _selected_health_component.health_changed.is_connected(_on_selected_health_changed):
			_selected_health_component.health_changed.disconnect(_on_selected_health_changed)
	_selected_health_component = null

func _on_selected_health_changed(current_health: float, max_health: float) -> void:
	if _selected_entity != null and is_instance_valid(_selected_entity):
		_health_label.text = _format_health_and_cargo_info(_selected_entity, _selected_health_component)
	else:
		_health_label.text = "HP: %.0f / %.0f" % [current_health, max_health]

func _connect_worker_gather_label(entity: EntityBase) -> void:
	var gather := entity.get_component(&"WorkerGatherComponent") if entity != null else null
	if _selected_worker_gather_component == gather:
		return
	_disconnect_worker_gather_label()
	_selected_worker_gather_component = gather
	if gather != null and gather.has_signal("gather_changed"):
		gather.gather_changed.connect(_on_selected_worker_gather_changed)

func _disconnect_worker_gather_label() -> void:
	if _selected_worker_gather_component != null and is_instance_valid(_selected_worker_gather_component):
		if _selected_worker_gather_component.has_signal("gather_changed") and _selected_worker_gather_component.gather_changed.is_connected(_on_selected_worker_gather_changed):
			_selected_worker_gather_component.gather_changed.disconnect(_on_selected_worker_gather_changed)
	_selected_worker_gather_component = null

func _on_selected_worker_gather_changed() -> void:
	if _selected_entity == null or not is_instance_valid(_selected_entity) or _selected_health_component == null:
		return
	_health_label.text = _format_health_and_cargo_info(_selected_entity, _selected_health_component)

func _format_health_and_cargo_info(entity: EntityBase, health: Node) -> String:
	if health == null:
		return ""
	var lines: Array[String] = ["HP: %.0f / %.0f" % [health.current_health, health.max_health]]
	var gather := entity.get_component(&"WorkerGatherComponent") if entity != null else null
	if gather != null and gather.has_method("get_cargo_text"):
		lines.append(gather.get_cargo_text())
	return "\n".join(lines)

func _update_harvestable_label(entity: EntityBase) -> void:
	var harvestable := _get_harvestable_component(entity)
	if harvestable == null:
		_hide_harvestable_label()
		return
	if _selected_harvestable_component != harvestable:
		_disconnect_harvestable_label()
		_selected_harvestable_component = harvestable
		if harvestable.has_signal("amount_changed"):
			harvestable.amount_changed.connect(_on_selected_harvestable_amount_changed)
	_health_label.visible = true
	_health_label.text = _format_harvestable_info(harvestable)

func _hide_harvestable_label() -> void:
	_disconnect_harvestable_label()

func _disconnect_harvestable_label() -> void:
	if _selected_harvestable_component != null and is_instance_valid(_selected_harvestable_component):
		if _selected_harvestable_component.has_signal("amount_changed") and _selected_harvestable_component.amount_changed.is_connected(_on_selected_harvestable_amount_changed):
			_selected_harvestable_component.amount_changed.disconnect(_on_selected_harvestable_amount_changed)
	_selected_harvestable_component = null

func _on_selected_harvestable_amount_changed(_remaining_amount: int, _max_amount: int) -> void:
	if _selected_harvestable_component == null or not is_instance_valid(_selected_harvestable_component):
		_hide_harvestable_label()
		return
	_health_label.text = _format_harvestable_info(_selected_harvestable_component)

func _format_harvestable_info(harvestable: Node) -> String:
	var lines: Array[String] = [
		"Resource: %s" % _get_resource_display_name(harvestable.get_resource_id()),
		"Remaining: %d / %d" % [
			harvestable.get_remaining_amount(),
			harvestable.max_amount if "max_amount" in harvestable else harvestable.get_remaining_amount(),
		],
	]
	if "requires_extractor" in harvestable and harvestable.requires_extractor:
		lines.append("Requires Extractor: Yes")
	return "\n".join(lines)

func _update_production_info(entity: EntityBase) -> void:
	var production := entity.get_component(&"ProductionComponent") if entity != null else null
	if production == null:
		_hide_production_info()
		return
	if _selected_production_component != production:
		_disconnect_production_info()
		_selected_production_component = production
		if production.has_signal("production_changed"):
			production.production_changed.connect(_on_selected_production_changed)
	_show_production_info(production)

func _show_production_info(production: Node) -> void:
	_production_commands_label.visible = true
	_active_production_label.visible = true
	_production_progress.visible = true
	_production_queue_label.visible = true
	_production_queue_list_label.visible = true
	_rally_point_label.visible = true

	_production_commands_label.text = "Production: %s" % _format_available_recipes(production)
	var active_order = production.get_active_order() if production.has_method("get_active_order") else null
	if active_order != null and active_order.recipe != null:
		_active_production_label.text = "Active: %s" % _get_recipe_display_name(active_order.recipe)
	else:
		_active_production_label.text = "Active: Idle"
	var progress: float = production.get_progress_ratio() if production.has_method("get_progress_ratio") else 0.0
	_production_progress.value = roundf(progress * 100.0)
	_production_queue_label.text = "Queue: %d / %d" % [
		production.get_queue_count() if production.has_method("get_queue_count") else 0,
		production.queue_limit if "queue_limit" in production else 0,
	]
	_production_queue_list_label.text = "Queued: %s" % _format_queued_orders(production)
	if "has_rally_point" in production and production.has_rally_point:
		_rally_point_label.text = "Rally: %.1f, %.1f" % [production.rally_point.x, production.rally_point.z]
	else:
		_rally_point_label.text = "Rally: None"

func _hide_production_info() -> void:
	_disconnect_production_info()
	_production_commands_label.visible = false
	_active_production_label.visible = false
	_production_progress.visible = false
	_production_queue_label.visible = false
	_production_queue_list_label.visible = false
	_rally_point_label.visible = false

func _disconnect_production_info() -> void:
	if _selected_production_component != null and is_instance_valid(_selected_production_component):
		if _selected_production_component.has_signal("production_changed") and _selected_production_component.production_changed.is_connected(_on_selected_production_changed):
			_selected_production_component.production_changed.disconnect(_on_selected_production_changed)
	_selected_production_component = null

func _on_selected_production_changed() -> void:
	if _selected_production_component == null or not is_instance_valid(_selected_production_component):
		_hide_production_info()
		return
	_show_production_info(_selected_production_component)

func _connect_resource_wallet() -> void:
	var wallet := get_node_or_null("/root/ResourceManager")
	if wallet == null:
		return
	if wallet.has_signal("resources_changed") and not wallet.resources_changed.is_connected(_update_resource_label):
		wallet.resources_changed.connect(_update_resource_label)

func _update_resource_label() -> void:
	var wallet := get_node_or_null("/root/ResourceManager")
	if wallet == null or not wallet.has_method("get_amount"):
		_resource_label.visible = false
		return
	_resource_label.visible = true
	_resource_label.text = "Crystals: %d\nHe3: %d" % [
		wallet.get_amount(&"crystals"),
		wallet.get_amount(&"he3"),
	]

func _get_entity_display_name(entity: EntityBase) -> String:
	if entity.display_name.strip_edges() != "":
		return entity.display_name
	return entity.name

func _get_command_display_name(command: CommandBase) -> String:
	if command.display_name.strip_edges() != "":
		return command.display_name
	return String(command.command_id)

func _format_available_recipes(production: Node) -> String:
	if production == null or not production.has_method("get_available_recipes"):
		return "None"
	var names: Array[String] = []
	for recipe in production.get_available_recipes():
		if recipe != null:
			names.append(_get_recipe_display_name(recipe))
	return ", ".join(names) if not names.is_empty() else "None"

func _format_queued_orders(production: Node) -> String:
	if production == null or not production.has_method("get_queued_orders"):
		return "Empty"
	var names: Array[String] = []
	for order in production.get_queued_orders():
		if order != null and order.recipe != null:
			names.append(_get_recipe_display_name(order.recipe))
	return ", ".join(names) if not names.is_empty() else "Empty"

func _get_recipe_display_name(recipe: Resource) -> String:
	if recipe == null:
		return "Unknown"
	if "display_name" in recipe and recipe.display_name.strip_edges() != "":
		return recipe.display_name
	if "id" in recipe:
		return String(recipe.id)
	return "Unknown"

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
	if _get_harvestable_component(entity) != null:
		return "Neutral / Resource"
	var team_id: int = entity.get_team_id()
	if team_id == PLAYER_TEAM_ID:
		return "Owned"
	if team_id == 0:
		return "Neutral"
	return "Hostile" if team_id != PLAYER_TEAM_ID else "Unknown"

func _get_harvestable_component(entity: EntityBase) -> Node:
	if entity == null or not is_instance_valid(entity):
		return null
	return entity.get_component(&"HarvestableComponent")

func _get_resource_display_name(resource_id: StringName) -> String:
	match resource_id:
		&"crystals":
			return "Crystals"
		&"he3":
			return "He3"
		_:
			return String(resource_id).capitalize()

func _make_button_texture(color: Color) -> Texture2D:
	var image := Image.create(32, 32, false, Image.FORMAT_RGBA8)
	image.fill(color)
	return ImageTexture.create_from_image(image)
