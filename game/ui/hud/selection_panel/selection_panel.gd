extends Control
class_name SelectionPanel

const TILE_SIZE := Vector2(52.0, 46.0)
const QUEUE_CHIP_SIZE := Vector2(34.0, 22.0)

@onready var _empty_selection_label: Label = $MarginContainer/EmptySelectionLabel
@onready var _single_selection: HBoxContainer = $MarginContainer/SingleSelection
@onready var _portrait_button: Button = $MarginContainer/SingleSelection/PortraitButton
@onready var _selected_label: Label = $MarginContainer/SingleSelection/Details/SelectedEntityLabel
@onready var _status_label: Label = $MarginContainer/SingleSelection/Details/StatusLabel
@onready var _health_row: HBoxContainer = $MarginContainer/SingleSelection/Details/HealthRow
@onready var _health_label: Label = $MarginContainer/SingleSelection/Details/HealthRow/HealthLabel
@onready var _health_bar: ProgressBar = $MarginContainer/SingleSelection/Details/HealthRow/HealthBar
@onready var _active_production_label: Label = $MarginContainer/SingleSelection/Details/ActiveProductionLabel
@onready var _production_progress: ProgressBar = $MarginContainer/SingleSelection/Details/ProductionProgress
@onready var _building_selection: HBoxContainer = $MarginContainer/BuildingSelection
@onready var _building_identity_block: Button = $MarginContainer/BuildingSelection/IdentityBlock
@onready var _building_name_label: Label = $MarginContainer/BuildingSelection/BuildingInfoBlock/BuildingNameLabel
@onready var _building_status_label: Label = $MarginContainer/BuildingSelection/BuildingInfoBlock/BuildingStatusLabel
@onready var _building_health_label: Label = $MarginContainer/BuildingSelection/BuildingInfoBlock/BuildingHealthLabel
@onready var _building_production_label: Label = $MarginContainer/BuildingSelection/ProductionInfoBlock/BuildingProductionLabel
@onready var _building_production_progress: ProgressBar = $MarginContainer/BuildingSelection/ProductionInfoBlock/BuildingProductionProgress
@onready var _building_queue_row: HBoxContainer = $MarginContainer/BuildingSelection/ProductionInfoBlock/QueueRow
@onready var _building_queue_chips: HBoxContainer = $MarginContainer/BuildingSelection/ProductionInfoBlock/QueueRow/QueueChips
@onready var _multi_selection: VBoxContainer = $MarginContainer/MultiSelection
@onready var _multi_header_label: Label = $MarginContainer/MultiSelection/MultiHeaderLabel
@onready var _tile_row: HBoxContainer = $MarginContainer/MultiSelection/TileScroll/TileRow

var _selected_entity: EntityBase = null
var _selected_entities: Array[EntityBase] = []
var _selected_health_component: Node = null
var _selected_worker_gather_component: Node = null
var _selected_production_component: Node = null

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	clip_contents = true
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
	_selected_entity = null
	if not _selected_entities.is_empty():
		_selected_entity = _selected_entities[0]
	_rebuild()

func refresh_selected_entity_info() -> void:
	_rebuild()

func _rebuild() -> void:
	_prune_invalid_selected_entities()
	_disconnect_single_entity_signals()

	_empty_selection_label.visible = _selected_entities.is_empty()
	_single_selection.visible = _selected_entities.size() == 1 and not _is_building(_selected_entity)
	_building_selection.visible = _selected_entities.size() == 1 and _is_building(_selected_entity)
	_multi_selection.visible = _selected_entities.size() > 1

	if _selected_entities.is_empty():
		_clear_multi_tiles()
		_clear_queue_chips()
		return
	if _selected_entities.size() > 1:
		_clear_queue_chips()
		_show_multi_selection()
		return
	if _is_building(_selected_entity):
		_clear_multi_tiles()
		_show_building_selection(_selected_entity)
		return
	_show_single_selection(_selected_entity)

func _show_single_selection(entity: EntityBase) -> void:
	_clear_multi_tiles()
	_selected_label.text = _get_entity_display_name(entity)
	_status_label.text = _get_entity_status(entity)
	_portrait_button.text = _get_tile_text(entity)
	_portrait_button.tooltip_text = _get_entity_display_name(entity)
	_update_health_info(entity)
	_update_production_info(entity)

func _show_building_selection(entity: EntityBase) -> void:
	_building_identity_block.text = _get_tile_text(entity)
	_building_identity_block.tooltip_text = _get_entity_display_name(entity)
	_building_name_label.text = _get_entity_display_name(entity)
	_building_status_label.text = _get_entity_status(entity)
	_update_building_health_info(entity)
	_update_building_production_info(entity)

func _show_multi_selection() -> void:
	_clear_multi_tiles()
	var status_summary := _get_multi_status_summary()
	_multi_header_label.text = "%d units | %s" % [_selected_entities.size(), status_summary]
	for entity in _selected_entities:
		_tile_row.add_child(_create_entity_tile(entity))

func _create_entity_tile(entity: EntityBase) -> Button:
	var tile := Button.new()
	tile.custom_minimum_size = TILE_SIZE
	tile.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	tile.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	tile.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tile.focus_mode = Control.FOCUS_NONE
	tile.clip_text = true
	tile.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	tile.text = _get_tile_text(entity)
	tile.tooltip_text = "%s\n%s" % [_get_entity_display_name(entity), _get_entity_status(entity)]
	return tile

func _clear_multi_tiles() -> void:
	for child in _tile_row.get_children():
		child.queue_free()

func _clear_queue_chips() -> void:
	for child in _building_queue_chips.get_children():
		child.queue_free()

func _update_health_info(entity: EntityBase) -> void:
	var health := entity.get_health_component() if entity != null else null
	if health == null:
		_health_row.visible = false
		return
	_selected_health_component = health
	if health.has_signal("health_changed"):
		health.health_changed.connect(_on_selected_health_changed)
	_health_row.visible = true
	_health_label.visible = true
	_health_bar.visible = true
	_set_health_values(entity, health)
	_connect_worker_gather_label(entity)

func _set_health_values(entity: EntityBase, health: Node) -> void:
	if health == null:
		return
	_health_label.text = "%.0f / %.0f" % [health.current_health, health.max_health]
	_health_bar.max_value = maxf(health.max_health, 1.0)
	_health_bar.value = clampf(health.current_health, 0.0, _health_bar.max_value)
	var gather := entity.get_component(&"WorkerGatherComponent") if entity != null else null
	if gather != null and gather.has_method("get_cargo_text"):
		var cargo_text: String = gather.get_cargo_text()
		if cargo_text.strip_edges() != "" and cargo_text != "Cargo: Empty":
			_status_label.text = "%s | %s" % [_get_entity_status(entity), cargo_text]

func _on_selected_health_changed(_current_health: float, _max_health: float) -> void:
	if _selected_entity == null or not is_instance_valid(_selected_entity):
		return
	if _is_building(_selected_entity):
		_set_building_health_values(_selected_health_component)
	else:
		_set_health_values(_selected_entity, _selected_health_component)

func _connect_worker_gather_label(entity: EntityBase) -> void:
	var gather := entity.get_component(&"WorkerGatherComponent") if entity != null else null
	_selected_worker_gather_component = gather
	if gather != null and gather.has_signal("gather_changed"):
		gather.gather_changed.connect(_on_selected_worker_gather_changed)

func _on_selected_worker_gather_changed() -> void:
	if _selected_entity == null or not is_instance_valid(_selected_entity):
		return
	_status_label.text = _get_entity_status(_selected_entity)
	if _selected_health_component != null:
		_set_health_values(_selected_entity, _selected_health_component)

func _update_production_info(entity: EntityBase) -> void:
	var production := entity.get_component(&"ProductionComponent") if entity != null else null
	if production == null:
		_selected_production_component = null
		_active_production_label.visible = false
		_production_progress.visible = false
		return
	_selected_production_component = production
	if production.has_signal("production_changed"):
		production.production_changed.connect(_on_selected_production_changed)
	_active_production_label.visible = true
	_production_progress.visible = true
	_set_production_values(production)

func _set_production_values(production: Node) -> void:
	if production == null:
		return
	var active_order = production.get_active_order() if production.has_method("get_active_order") else null
	if active_order != null and active_order.recipe != null:
		_active_production_label.text = "Active: %s" % _get_recipe_display_name(active_order.recipe)
	else:
		_active_production_label.text = "Active: Idle"
	var progress: float = production.get_progress_ratio() if production.has_method("get_progress_ratio") else 0.0
	_production_progress.value = roundf(progress * 100.0)

func _update_building_health_info(entity: EntityBase) -> void:
	var health := entity.get_health_component() if entity != null else null
	if health == null:
		_building_health_label.text = "HP: --"
		return
	_selected_health_component = health
	if health.has_signal("health_changed"):
		health.health_changed.connect(_on_selected_health_changed)
	_set_building_health_values(health)

func _set_building_health_values(health: Node) -> void:
	if health == null:
		return
	_building_health_label.text = "HP: %.0f / %.0f" % [health.current_health, health.max_health]

func _update_building_production_info(entity: EntityBase) -> void:
	var production := entity.get_component(&"ProductionComponent") if entity != null else null
	if production == null:
		_selected_production_component = null
		_building_production_label.text = "No production"
		_building_production_progress.visible = false
		_building_queue_row.visible = false
		_clear_queue_chips()
		return
	_selected_production_component = production
	if production.has_signal("production_changed"):
		production.production_changed.connect(_on_selected_production_changed)
	_building_production_progress.visible = true
	_set_building_production_values(production)

func _set_building_production_values(production: Node) -> void:
	if production == null:
		return
	var active_order = production.get_active_order() if production.has_method("get_active_order") else null
	if active_order != null and active_order.recipe != null:
		_building_production_label.text = "Producing: %s" % _get_recipe_display_name(active_order.recipe)
		_building_production_progress.visible = true
	else:
		_building_production_label.text = "No active production"
		_building_production_progress.visible = false
	var progress: float = production.get_progress_ratio() if production.has_method("get_progress_ratio") else 0.0
	_building_production_progress.value = roundf(progress * 100.0)
	_update_building_queue_chips(production)

func _update_building_queue_chips(production: Node) -> void:
	_clear_queue_chips()
	var queued_orders: Array = production.get_queued_orders() if production != null and production.has_method("get_queued_orders") else []
	_building_queue_row.visible = not queued_orders.is_empty()
	for order in queued_orders:
		if order == null or order.recipe == null:
			continue
		var chip := Button.new()
		chip.custom_minimum_size = QUEUE_CHIP_SIZE
		chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
		chip.focus_mode = Control.FOCUS_NONE
		chip.clip_text = true
		chip.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		chip.text = _get_recipe_chip_text(order.recipe)
		chip.tooltip_text = _get_recipe_display_name(order.recipe)
		_building_queue_chips.add_child(chip)

func _on_selected_production_changed() -> void:
	if _selected_production_component == null or not is_instance_valid(_selected_production_component):
		_active_production_label.visible = false
		_production_progress.visible = false
		_building_production_progress.visible = false
		_building_queue_row.visible = false
		return
	if _selected_entity != null and is_instance_valid(_selected_entity):
		if _is_building(_selected_entity):
			_building_status_label.text = _get_entity_status(_selected_entity)
			_set_building_production_values(_selected_production_component)
		else:
			_set_production_values(_selected_production_component)
			_status_label.text = _get_entity_status(_selected_entity)

func _disconnect_single_entity_signals() -> void:
	if _selected_health_component != null and is_instance_valid(_selected_health_component):
		if _selected_health_component.has_signal("health_changed") and _selected_health_component.health_changed.is_connected(_on_selected_health_changed):
			_selected_health_component.health_changed.disconnect(_on_selected_health_changed)
	_selected_health_component = null

	if _selected_worker_gather_component != null and is_instance_valid(_selected_worker_gather_component):
		if _selected_worker_gather_component.has_signal("gather_changed") and _selected_worker_gather_component.gather_changed.is_connected(_on_selected_worker_gather_changed):
			_selected_worker_gather_component.gather_changed.disconnect(_on_selected_worker_gather_changed)
	_selected_worker_gather_component = null

	if _selected_production_component != null and is_instance_valid(_selected_production_component):
		if _selected_production_component.has_signal("production_changed") and _selected_production_component.production_changed.is_connected(_on_selected_production_changed):
			_selected_production_component.production_changed.disconnect(_on_selected_production_changed)
	_selected_production_component = null

func _prune_invalid_selected_entities() -> void:
	for i in range(_selected_entities.size() - 1, -1, -1):
		if _selected_entities[i] == null or not is_instance_valid(_selected_entities[i]):
			_selected_entities.remove_at(i)
	_selected_entity = null
	if not _selected_entities.is_empty():
		_selected_entity = _selected_entities[0]

func _get_multi_status_summary() -> String:
	var counts: Dictionary = {}
	for entity in _selected_entities:
		var status := _get_entity_status(entity)
		counts[status] = int(counts.get(status, 0)) + 1
	if counts.size() == 1:
		return String(counts.keys()[0])
	var top_status := "Mixed"
	var top_count := 0
	for status in counts:
		var count := int(counts[status])
		if count > top_count:
			top_count = count
			top_status = status
	return "%s / Mixed" % top_status

func _get_entity_status(entity: EntityBase) -> String:
	if entity == null or not is_instance_valid(entity):
		return "Unknown"
	if entity.has_method("is_alive") and not entity.is_alive():
		return "Destroyed"

	var gather := entity.get_component(&"WorkerGatherComponent")
	if gather != null and "state" in gather:
		match int(gather.state):
			1:
				return "Moving"
			2:
				return "Searching"
			3:
				return "Moving"
			4:
				return "Harvesting"
			5:
				return "Returning Cargo"
			6:
				return "Depositing"
			7:
				return "Returning"

	var combat := entity.get_component(&"CombatComponent")
	if combat != null and combat.has_method("has_valid_attack_target") and combat.has_valid_attack_target():
		return "Attacking"

	var movement := entity.get_component(&"MovementComponent")
	if movement != null and movement.has_method("has_path") and movement.has_path():
		return "Moving"

	var production := entity.get_component(&"ProductionComponent")
	if production != null and production.has_method("get_active_order") and production.get_active_order() != null:
		return "Producing"

	if _get_harvestable_component(entity) != null:
		return "Resource"
	return "Idle"

func _is_building(entity: EntityBase) -> bool:
	if entity == null or not is_instance_valid(entity):
		return false
	return entity is BuildingBase or entity.is_in_group("selectable_buildings")

func _get_tile_text(entity: EntityBase) -> String:
	var display_name := _get_entity_display_name(entity)
	var words := display_name.split(" ", false)
	if words.size() >= 2:
		return "%s%s" % [words[0].left(1), words[1].left(1)]
	return display_name.left(3)

func _get_entity_display_name(entity: EntityBase) -> String:
	if entity == null:
		return "Unknown"
	if entity.display_name.strip_edges() != "":
		return entity.display_name
	return entity.name

func _get_recipe_display_name(recipe: Resource) -> String:
	if recipe == null:
		return "Unknown"
	if "display_name" in recipe and recipe.display_name.strip_edges() != "":
		return recipe.display_name
	if "id" in recipe:
		return String(recipe.id)
	return "Unknown"

func _get_recipe_chip_text(recipe: Resource) -> String:
	var display_name := _get_recipe_display_name(recipe)
	var words := display_name.split(" ", false)
	if words.size() >= 2:
		return "%s%s" % [words[0].left(1), words[1].left(1)]
	return display_name.left(3)

func _get_harvestable_component(entity: EntityBase) -> Node:
	if entity == null or not is_instance_valid(entity):
		return null
	return entity.get_component(&"HarvestableComponent")
