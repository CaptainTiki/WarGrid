extends PanelContainer
class_name ResourcePlacementDock

signal tool_mode_changed(mode: int)
signal placement_settings_changed(settings: Dictionary)
signal delete_selected_requested
signal delete_last_requested

const EntityPlacementDockScript := preload("res://mapeditor/docks/entity_placement_dock.gd")
const EntityCatalogScript := preload("res://game/entities/catalog/entity_catalog.gd")
const EntityPlacementDataScript := preload("res://game/entities/placement/entity_placement_data.gd")

@onready var select_tool_button: Button = %SelectToolButton
@onready var place_tool_button: Button = %PlaceToolButton
@onready var move_tool_button: Button = %MoveToolButton
@onready var rotate_tool_button: Button = %RotateToolButton
@onready var delete_tool_button: Button = %DeleteToolButton
@onready var resource_option: OptionButton = %ResourceOption
@onready var definition_label: Label = %DefinitionLabel
@onready var team_option: OptionButton = %TeamOption
@onready var rotation_spin_box: SpinBox = %RotationSpinBox
@onready var delete_selected_button: Button = %DeleteSelectedButton
@onready var delete_last_button: Button = %DeleteLastButton
@onready var placement_count_label: Label = %PlacementCountLabel
@onready var validation_label: Label = %ValidationLabel

var _catalog := EntityCatalogScript.new()
var _syncing := false
var _active_tool_mode := EntityPlacementDockScript.EntityToolMode.SELECT

func _ready() -> void:
	_configure_team_options()
	set_available_resources(_catalog.get_resource_entity_entries())
	select_tool_button.pressed.connect(_select_tool_mode.bind(EntityPlacementDockScript.EntityToolMode.SELECT))
	place_tool_button.pressed.connect(_select_tool_mode.bind(EntityPlacementDockScript.EntityToolMode.PLACE))
	move_tool_button.pressed.connect(_select_tool_mode.bind(EntityPlacementDockScript.EntityToolMode.MOVE))
	rotate_tool_button.pressed.connect(_select_tool_mode.bind(EntityPlacementDockScript.EntityToolMode.ROTATE))
	delete_tool_button.pressed.connect(_select_tool_mode.bind(EntityPlacementDockScript.EntityToolMode.DELETE))
	resource_option.item_selected.connect(_on_resource_selected)
	team_option.item_selected.connect(_on_settings_changed)
	rotation_spin_box.value_changed.connect(_on_spin_setting_changed)
	delete_selected_button.pressed.connect(delete_selected_requested.emit)
	delete_last_button.pressed.connect(delete_last_requested.emit)
	set_tool_mode(_active_tool_mode)
	set_placement_count(0)
	set_validation_feedback(true, "Valid")

func set_available_resources(resource_entries: Array) -> void:
	if resource_option == null:
		return
	_syncing = true
	resource_option.clear()
	for entry in resource_entries:
		var data := entry as Dictionary
		var entity_id := StringName(str(data.get("entity_id", &"")))
		if entity_id == &"":
			continue
		var display_name := str(data.get("display_name", entity_id))
		resource_option.add_item(display_name)
		resource_option.set_item_metadata(resource_option.item_count - 1, str(entity_id))
	if resource_option.item_count > 0:
		resource_option.select(0)
	_syncing = false
	_update_definition_label()

func get_settings() -> Dictionary:
	return {
		"entity_id": get_selected_entity_id(),
		"team_id": team_option.get_item_id(team_option.selected),
		"rotation_y": deg_to_rad(float(rotation_spin_box.value)),
		"health_spawn_mode": EntityPlacementDataScript.HealthSpawnMode.FULL,
		"health_value": 1.0,
		"tool_mode": _active_tool_mode,
	}

func get_selected_entity_id() -> StringName:
	if resource_option.item_count <= 0:
		return &""
	var metadata: Variant = resource_option.get_item_metadata(resource_option.selected)
	if metadata == null:
		return &""
	return StringName(str(metadata))

func get_tool_mode() -> int:
	return _active_tool_mode

func set_tool_mode(mode: int) -> void:
	_syncing = true
	_active_tool_mode = clampi(mode, EntityPlacementDockScript.EntityToolMode.SELECT, EntityPlacementDockScript.EntityToolMode.DELETE)
	select_tool_button.button_pressed = _active_tool_mode == EntityPlacementDockScript.EntityToolMode.SELECT
	place_tool_button.button_pressed = _active_tool_mode == EntityPlacementDockScript.EntityToolMode.PLACE
	move_tool_button.button_pressed = _active_tool_mode == EntityPlacementDockScript.EntityToolMode.MOVE
	rotate_tool_button.button_pressed = _active_tool_mode == EntityPlacementDockScript.EntityToolMode.ROTATE
	delete_tool_button.button_pressed = _active_tool_mode == EntityPlacementDockScript.EntityToolMode.DELETE
	_syncing = false

func set_from_placement(placement: EntityPlacementData) -> void:
	if placement == null:
		return
	_syncing = true
	_select_entity_id(placement.entity_id)
	_select_item_id(team_option, placement.team_id)
	rotation_spin_box.value = rad_to_deg(placement.rotation_y)
	_syncing = false
	_update_definition_label()

func set_placement_count(count: int) -> void:
	placement_count_label.text = "Resources: %d" % count

func set_validation_feedback(is_valid: bool, reason: String) -> void:
	if validation_label == null:
		return
	var display_reason := reason if reason.strip_edges() != "" else "Valid"
	validation_label.text = "Placement: %s" % display_reason
	validation_label.add_theme_color_override(
		"font_color",
		Color(0.55, 1.0, 0.6) if is_valid else Color(1.0, 0.45, 0.28)
	)

func _configure_team_options() -> void:
	team_option.clear()
	team_option.add_item("Neutral / 0", 0)
	team_option.add_item("Player / 1", 1)
	team_option.add_item("Enemy / 2", 2)
	team_option.select(0)

func _select_entity_id(entity_id: StringName) -> void:
	for i in range(resource_option.item_count):
		if StringName(str(resource_option.get_item_metadata(i))) == entity_id:
			resource_option.select(i)
			return

func _select_item_id(option: OptionButton, id: int) -> void:
	for i in range(option.item_count):
		if option.get_item_id(i) == id:
			option.select(i)
			return

func _emit_settings_changed() -> void:
	if not _syncing:
		placement_settings_changed.emit(get_settings())

func _select_tool_mode(mode: int) -> void:
	if _syncing:
		return
	set_tool_mode(mode)
	tool_mode_changed.emit(_active_tool_mode)
	_emit_settings_changed()

func _on_resource_selected(_index: int) -> void:
	_update_definition_label()
	_emit_settings_changed()

func _on_settings_changed(_index: int) -> void:
	_emit_settings_changed()

func _on_spin_setting_changed(_value: float) -> void:
	_emit_settings_changed()

func _update_definition_label() -> void:
	if definition_label == null:
		return
	var entity_id := get_selected_entity_id()
	var definition: EntityDefinition = _catalog.get_definition(entity_id)
	if definition == null:
		definition_label.text = "No resource definitions"
		return
	definition_label.text = "%s / %s" % [definition.display_name, definition.category]
