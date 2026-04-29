extends PanelContainer
class_name EntityPlacementDock

signal placement_mode_changed(enabled: bool)
signal tool_mode_changed(mode: int)
signal placement_settings_changed(settings: Dictionary)
signal delete_selected_requested
signal delete_last_requested

const EntityCatalogScript := preload("res://game/entities/catalog/entity_catalog.gd")
const EntityPlacementDataScript := preload("res://game/entities/placement/entity_placement_data.gd")

enum EntityToolMode {
	SELECT,
	PLACE,
	MOVE,
	ROTATE,
	DELETE,
}

@onready var select_tool_button: Button = %SelectToolButton
@onready var place_tool_button: Button = %PlaceToolButton
@onready var move_tool_button: Button = %MoveToolButton
@onready var rotate_tool_button: Button = %RotateToolButton
@onready var delete_tool_button: Button = %DeleteToolButton
@onready var entity_option: OptionButton = %EntityOption
@onready var definition_label: Label = %DefinitionLabel
@onready var team_option: OptionButton = %TeamOption
@onready var rotation_spin_box: SpinBox = %RotationSpinBox
@onready var health_mode_option: OptionButton = %HealthModeOption
@onready var health_value_spin_box: SpinBox = %HealthValueSpinBox
@onready var delete_selected_button: Button = %DeleteSelectedButton
@onready var delete_last_button: Button = %DeleteLastButton
@onready var placement_count_label: Label = %PlacementCountLabel

var _catalog := EntityCatalogScript.new()
var _syncing := false
var _active_tool_mode := EntityToolMode.SELECT

func _ready() -> void:
	_configure_entities()
	_configure_team_options()
	_configure_health_modes()
	select_tool_button.pressed.connect(_select_tool_mode.bind(EntityToolMode.SELECT))
	place_tool_button.pressed.connect(_select_tool_mode.bind(EntityToolMode.PLACE))
	move_tool_button.pressed.connect(_select_tool_mode.bind(EntityToolMode.MOVE))
	rotate_tool_button.pressed.connect(_select_tool_mode.bind(EntityToolMode.ROTATE))
	delete_tool_button.pressed.connect(_select_tool_mode.bind(EntityToolMode.DELETE))
	entity_option.item_selected.connect(_on_entity_selected)
	team_option.item_selected.connect(_on_settings_changed)
	rotation_spin_box.value_changed.connect(_on_spin_setting_changed)
	health_mode_option.item_selected.connect(_on_settings_changed)
	health_value_spin_box.value_changed.connect(_on_spin_setting_changed)
	delete_selected_button.pressed.connect(delete_selected_requested.emit)
	delete_last_button.pressed.connect(delete_last_requested.emit)
	set_tool_mode(_active_tool_mode)
	_update_definition_label()
	set_placement_count(0)

func get_settings() -> Dictionary:
	return {
		"entity_id": get_selected_entity_id(),
		"team_id": team_option.get_item_id(team_option.selected),
		"rotation_y": deg_to_rad(float(rotation_spin_box.value)),
		"health_spawn_mode": health_mode_option.get_item_id(health_mode_option.selected),
		"health_value": float(health_value_spin_box.value),
		"tool_mode": _active_tool_mode,
	}

func get_selected_entity_id() -> StringName:
	var metadata: Variant = entity_option.get_item_metadata(entity_option.selected)
	if metadata == null:
		return &""
	return StringName(str(metadata))

func set_placement_count(count: int) -> void:
	placement_count_label.text = "Placements: %d" % count

func set_tool_mode(mode: int) -> void:
	_syncing = true
	_active_tool_mode = clampi(mode, EntityToolMode.SELECT, EntityToolMode.DELETE)
	select_tool_button.button_pressed = _active_tool_mode == EntityToolMode.SELECT
	place_tool_button.button_pressed = _active_tool_mode == EntityToolMode.PLACE
	move_tool_button.button_pressed = _active_tool_mode == EntityToolMode.MOVE
	rotate_tool_button.button_pressed = _active_tool_mode == EntityToolMode.ROTATE
	delete_tool_button.button_pressed = _active_tool_mode == EntityToolMode.DELETE
	_syncing = false

func set_from_placement(placement: EntityPlacementData) -> void:
	if placement == null:
		return
	_syncing = true
	_select_entity_id(placement.entity_id)
	_select_item_id(team_option, placement.team_id)
	rotation_spin_box.value = rad_to_deg(placement.rotation_y)
	_select_item_id(health_mode_option, placement.health_spawn_mode)
	health_value_spin_box.value = placement.health_value
	_syncing = false
	_update_definition_label()

func _configure_entities() -> void:
	entity_option.clear()
	var ids: Array[StringName] = _catalog.get_entity_ids()
	for entity_id in ids:
		var definition: EntityDefinition = _catalog.get_definition(entity_id)
		var label: String = str(entity_id)
		if definition != null and definition.display_name.strip_edges() != "":
			label = "%s (%s)" % [definition.display_name, entity_id]
		entity_option.add_item(label)
		entity_option.set_item_metadata(entity_option.item_count - 1, str(entity_id))
	if entity_option.item_count > 0:
		entity_option.select(0)

func _configure_team_options() -> void:
	team_option.clear()
	team_option.add_item("Neutral / 0", 0)
	team_option.add_item("Player / 1", 1)
	team_option.add_item("Enemy / 2", 2)
	team_option.select(1)

func _configure_health_modes() -> void:
	health_mode_option.clear()
	health_mode_option.add_item("Full", EntityPlacementDataScript.HealthSpawnMode.FULL)
	health_mode_option.add_item("Percent", EntityPlacementDataScript.HealthSpawnMode.PERCENT)
	health_mode_option.add_item("Current Value", EntityPlacementDataScript.HealthSpawnMode.CURRENT_VALUE)
	health_mode_option.select(0)

func _select_entity_id(entity_id: StringName) -> void:
	for i in range(entity_option.item_count):
		if StringName(str(entity_option.get_item_metadata(i))) == entity_id:
			entity_option.select(i)
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
	placement_mode_changed.emit(_active_tool_mode == EntityToolMode.PLACE)
	_emit_settings_changed()

func _on_entity_selected(_index: int) -> void:
	_update_definition_label()
	_emit_settings_changed()

func _on_settings_changed(_index: int) -> void:
	_emit_settings_changed()

func _on_spin_setting_changed(_value: float) -> void:
	_emit_settings_changed()

func _update_definition_label() -> void:
	var entity_id := get_selected_entity_id()
	var definition: EntityDefinition = _catalog.get_definition(entity_id)
	if definition == null:
		definition_label.text = "Unknown entity"
		return
	definition_label.text = "%s / %s" % [definition.display_name, definition.category]
